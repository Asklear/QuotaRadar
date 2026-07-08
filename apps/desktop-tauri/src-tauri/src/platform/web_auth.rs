use std::{
    collections::{BTreeMap, BTreeSet},
    sync::{
        atomic::{AtomicBool, AtomicU64, Ordering},
        mpsc, Arc,
    },
    thread,
    time::Duration,
};

use chrono::Utc;
use serde::{Deserialize, Serialize};
use serde_json::{json, Map, Value};
use tauri::{
    webview::{Cookie, PageLoadEvent},
    AppHandle, Emitter, Manager, Runtime, Url, WebviewUrl, WebviewWindow, WebviewWindowBuilder,
};

use crate::{
    commands::auth::{
        save_web_authorization_with_stores, CapturedWebAuthorization, WebAuthorizationSession,
    },
    storage::{metadata_store::TauriMetadataStore, secret_store::TauriSecretVault},
};

use super::window::reopen_main_window;

const WEB_AUTH_SAVED_EVENT: &str = "web_authorization_saved";
const WEB_AUTH_FAILED_EVENT: &str = "web_authorization_failed";
const WEB_AUTH_WINDOW_PREFIX: &str = "web-auth";
const WEB_AUTH_CONTROL_SAVE_SIGNAL: &str = "__QUOTARADAR_WEB_AUTH_SAVE__:";
const WEB_AUTH_CONTROL_CANCEL_SIGNAL: &str = "__QUOTARADAR_WEB_AUTH_CANCEL__:";
static WEB_AUTH_WINDOW_SEQUENCE: AtomicU64 = AtomicU64::new(1);
const WEB_STORAGE_CAPTURE_SCRIPT: &str = r#"
(() => {
  const keys = [
    'kimi-auth', 'accessToken', 'access_token', 'authorization', 'bearerToken', 'bearer_token', 'token',
    'volcano-token-info',
    'deviceID', 'deviceId', 'x-msh-device-id',
    'sessionID', 'sessionId', 'x-msh-session-id',
    'trafficID', 'trafficId', 'x-traffic-id'
  ];
  const output = {};
  for (const storageName of ['localStorage', 'sessionStorage']) {
    try {
      const storage = window[storageName];
      if (!storage) continue;
      for (const key of keys) {
        const value = storage.getItem(key);
        if (value && !output[key]) output[key] = value;
      }
    } catch (_) {}
  }
  return output;
})()
"#;
const DOCUMENT_COOKIE_CAPTURE_SCRIPT: &str = r#"
(() => ({
  href: window.location.href,
  cookie: document.cookie || ''
}))()
"#;

#[derive(Debug, Clone)]
pub struct WebAuthorizationWindowRequest {
    pub provider_id: String,
    pub target_credential_id: Option<String>,
    pub target_name: Option<String>,
    pub login_url: String,
    pub locale: String,
}

#[derive(Debug, Clone)]
struct CaptureSession {
    provider_id: String,
    target_credential_id: Option<String>,
    target_name: Option<String>,
    default_name: &'static str,
    cookie_domains: &'static [&'static str],
    required_names: &'static [&'static str],
    capture_started: Arc<AtomicBool>,
    failure_emitted: Arc<AtomicBool>,
    saved: Arc<AtomicBool>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum WebAuthControlAction {
    Save,
    Cancel,
}

#[derive(Debug, Clone, PartialEq)]
pub struct DashboardReauthProviderConfig {
    pub provider_id: &'static str,
    pub cookie_domains: &'static [&'static str],
    pub required_names: &'static [&'static str],
    pub default_name: &'static str,
}

#[derive(Debug, Clone, PartialEq)]
pub struct CapturedCredentialMaterial {
    pub cookie_header: String,
    pub fields: BTreeMap<String, String>,
}

#[derive(Debug, PartialEq)]
enum CaptureRetryOutcome {
    Ready,
    Retry { next_completed_retry_count: usize },
    Failed,
}

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct WebAuthorizationFailedPayload {
    provider_id: String,
    target_credential_id: Option<String>,
    message: String,
}

#[derive(Debug, Deserialize)]
struct DocumentCookieCapture {
    href: String,
    cookie: String,
}

#[derive(Clone, Debug)]
struct WebAuthWindowLoadPlan {
    initial_route: String,
    navigation_url: Url,
}

pub fn open_web_authorization_window<R: Runtime>(
    app: &AppHandle<R>,
    request: WebAuthorizationWindowRequest,
) -> Result<(), String> {
    let provider_config =
        dashboard_reauth_provider_config(&request.provider_id).ok_or_else(|| {
            format!(
                "{} does not support automatic web authorization capture",
                request.provider_id
            )
        })?;
    let login_url = Url::parse(&request.login_url).map_err(|error| error.to_string())?;
    if !matches!(login_url.scheme(), "http" | "https") {
        return Err("Web authorization URL must be http or https".to_string());
    }

    close_existing_web_auth_windows(app);

    let label = web_auth_window_label(&request.provider_id);
    let load_plan = web_auth_window_load_plan(login_url);
    let capture_session = Arc::new(CaptureSession {
        provider_id: request.provider_id.clone(),
        target_credential_id: request.target_credential_id.clone(),
        target_name: request.target_name.clone(),
        default_name: provider_config.default_name,
        cookie_domains: provider_config.cookie_domains,
        required_names: provider_config.required_names,
        capture_started: Arc::new(AtomicBool::new(false)),
        failure_emitted: Arc::new(AtomicBool::new(false)),
        saved: Arc::new(AtomicBool::new(false)),
    });
    let app_for_page_load = app.clone();
    let capture_session_for_page_load = capture_session.clone();
    let app_for_title = app.clone();
    let capture_session_for_title = capture_session.clone();

    let initialization_script = web_auth_control_initialization_script(&request.locale);
    let window =
        WebviewWindowBuilder::new(app, &label, WebviewUrl::App(load_plan.initial_route.into()))
            .title(format!("Quota Radar - {}", request.provider_id))
            .inner_size(720.0, 820.0)
            .min_inner_size(520.0, 600.0)
            .center()
            .focused(true)
            .initialization_script(&initialization_script)
            .on_document_title_changed(move |window, title| match web_auth_control_signal(&title) {
                Some(WebAuthControlAction::Save) => {
                    schedule_manual_capture_attempt(
                        app_for_title.clone(),
                        window,
                        capture_session_for_title.clone(),
                    );
                }
                Some(WebAuthControlAction::Cancel) => {
                    capture_session_for_title
                        .saved
                        .store(true, Ordering::SeqCst);
                    let _ = window.close();
                    let _ = reopen_main_window(&app_for_title);
                }
                None => {}
            })
            .on_page_load(move |window, payload| {
                if !should_start_capture_after_page_load(
                    payload.event(),
                    payload.url(),
                    capture_session_for_page_load.cookie_domains,
                ) {
                    return;
                }
                if !try_begin_initial_capture(
                    capture_session_for_page_load.capture_started.as_ref(),
                ) {
                    return;
                }

                schedule_capture_attempt(
                    app_for_page_load.clone(),
                    window,
                    capture_session_for_page_load.clone(),
                    0,
                );
            })
            .build()
            .map_err(|error| error.to_string())?;

    if let Err(error) = window.navigate(load_plan.navigation_url) {
        let _ = window.close();
        return Err(error.to_string());
    }

    Ok(())
}

fn web_auth_control_initialization_script(locale: &str) -> String {
    let labels = web_auth_control_labels(locale);
    r#"
(() => {
  const saveSignal = '__QUOTARADAR_WEB_AUTH_SAVE__:';
  const cancelSignal = '__QUOTARADAR_WEB_AUTH_CANCEL__:';
  const installControls = () => {
    if (document.getElementById('quotaradar-web-auth-controls')) return;
    const host = document.createElement('div');
    host.id = 'quotaradar-web-auth-controls';
    host.style.position = 'fixed';
    host.style.right = '16px';
    host.style.bottom = '16px';
    host.style.zIndex = '2147483647';
    host.style.pointerEvents = 'auto';
    const root = host.attachShadow ? host.attachShadow({ mode: 'closed' }) : host;
    const style = document.createElement('style');
    style.textContent = `
      .qr-auth-controls {
        display: inline-flex;
        gap: 8px;
        align-items: center;
        padding: 8px;
        border: 1px solid rgba(60, 60, 67, 0.20);
        border-radius: 10px;
        background: rgba(250, 250, 252, 0.96);
        color: #1d1d1f;
        box-shadow: 0 12px 32px rgba(0, 0, 0, 0.20);
        font: 13px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      }
      button {
        height: 30px;
        padding: 0 12px;
        border: 1px solid rgba(60, 60, 67, 0.22);
        border-radius: 7px;
        background: white;
        color: #1d1d1f;
        font: inherit;
        cursor: pointer;
      }
      button[data-primary="true"] {
        border-color: #1d1d1f;
        background: #1d1d1f;
        color: white;
      }
    `;
    const controls = document.createElement('div');
    controls.className = 'qr-auth-controls';
    const cancel = document.createElement('button');
    cancel.type = 'button';
    cancel.textContent = '__QUOTARADAR_CANCEL_LABEL__';
    cancel.addEventListener('click', (event) => {
      event.preventDefault();
      event.stopPropagation();
      document.title = `${cancelSignal}${Date.now()}`;
    });
    const save = document.createElement('button');
    save.type = 'button';
    save.dataset.primary = 'true';
    save.textContent = '__QUOTARADAR_SAVE_LABEL__';
    save.addEventListener('click', (event) => {
      event.preventDefault();
      event.stopPropagation();
      document.title = `${saveSignal}${Date.now()}`;
    });
    controls.append(cancel, save);
    root.append(style, controls);
    (document.body || document.documentElement).appendChild(host);
  };
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', installControls, { once: true });
  } else {
    installControls();
  }
  setTimeout(installControls, 500);
})();
"#
    .replace("__QUOTARADAR_CANCEL_LABEL__", labels.cancel)
    .replace("__QUOTARADAR_SAVE_LABEL__", labels.save)
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
struct WebAuthControlLabels {
    save: &'static str,
    cancel: &'static str,
}

fn web_auth_control_labels(locale: &str) -> WebAuthControlLabels {
    match locale {
        "zh-Hans" => WebAuthControlLabels {
            save: "保存",
            cancel: "取消",
        },
        "zh-Hant" => WebAuthControlLabels {
            save: "儲存",
            cancel: "取消",
        },
        "ja" => WebAuthControlLabels {
            save: "保存",
            cancel: "キャンセル",
        },
        "ko" => WebAuthControlLabels {
            save: "저장",
            cancel: "취소",
        },
        _ => WebAuthControlLabels {
            save: "Save",
            cancel: "Cancel",
        },
    }
}

fn web_auth_control_signal(title: &str) -> Option<WebAuthControlAction> {
    if title.starts_with(WEB_AUTH_CONTROL_SAVE_SIGNAL) {
        return Some(WebAuthControlAction::Save);
    }
    if title.starts_with(WEB_AUTH_CONTROL_CANCEL_SIGNAL) {
        return Some(WebAuthControlAction::Cancel);
    }
    None
}

pub fn schedule_web_authorization_window<R: Runtime + 'static>(
    app: &AppHandle<R>,
    request: WebAuthorizationWindowRequest,
) -> Result<(), String> {
    validate_web_authorization_window_request(&request)?;

    let app_for_window = app.clone();
    thread::spawn(move || {
        thread::sleep(Duration::from_millis(50));
        let failure_request = request.clone();
        if let Err(error) = open_web_authorization_window(&app_for_window, request) {
            emit_web_authorization_failure(
                &app_for_window,
                &failure_request.provider_id,
                failure_request.target_credential_id.clone(),
                format!("Could not open the web login window: {error}"),
            );
            let _ = reopen_main_window(&app_for_window);
        }
    });
    Ok(())
}

fn validate_web_authorization_window_request(
    request: &WebAuthorizationWindowRequest,
) -> Result<(), String> {
    dashboard_reauth_provider_config(&request.provider_id).ok_or_else(|| {
        format!(
            "{} does not support automatic web authorization capture",
            request.provider_id
        )
    })?;
    let login_url = Url::parse(&request.login_url).map_err(|error| error.to_string())?;
    if !matches!(login_url.scheme(), "http" | "https") {
        return Err("Web authorization URL must be http or https".to_string());
    }
    Ok(())
}

pub fn web_authorization_started_message(session: &WebAuthorizationSession) -> String {
    if session.target_credential_id.is_some() {
        format!("{}; waiting for dashboard login", session.message)
    } else {
        "Waiting for dashboard login; Quota Radar will save the authorization after login"
            .to_string()
    }
}

pub fn dashboard_reauth_provider_config(
    provider_id: &str,
) -> Option<DashboardReauthProviderConfig> {
    Some(match provider_id {
        "querit" => DashboardReauthProviderConfig {
            provider_id: "querit",
            cookie_domains: &["querit.ai"],
            required_names: &["osduss", "passOsRefreshTk", "osfuid"],
            default_name: "QUERIT_COOKIE",
        },
        "claude" => DashboardReauthProviderConfig {
            provider_id: "claude",
            cookie_domains: &["claude.ai", "claude.com"],
            required_names: &["sessionKey|sessionKeyLC"],
            default_name: "CLAUDE_SUBSCRIPTION_SESSION",
        },
        "anthropic_credits" => DashboardReauthProviderConfig {
            provider_id: "anthropic_credits",
            cookie_domains: &["claude.ai", "claude.com"],
            required_names: &["sessionKey|sessionKeyLC"],
            default_name: "ANTHROPIC_CREDITS_SESSION",
        },
        "codex" => DashboardReauthProviderConfig {
            provider_id: "codex",
            cookie_domains: &["chatgpt.com"],
            required_names: &[
                "__Secure-next-auth.session-token|__Secure-next-auth.session-token.*|__search-next-auth",
            ],
            default_name: "CODEX_SUBSCRIPTION_SESSION",
        },
        "kimi" => DashboardReauthProviderConfig {
            provider_id: "kimi",
            cookie_domains: &["kimi.com", "www.kimi.com"],
            required_names: &[
                "kimi-auth|accessToken|access_token",
                "deviceID|sessionID|trafficID",
            ],
            default_name: "KIMI_SUBSCRIPTION_SESSION",
        },
        "opencode_go" => DashboardReauthProviderConfig {
            provider_id: "opencode_go",
            cookie_domains: &["opencode.ai"],
            required_names: &["auth"],
            default_name: "OPENCODE_GO_COOKIE",
        },
        "xfyun_coding_plan" => DashboardReauthProviderConfig {
            provider_id: "xfyun_coding_plan",
            cookie_domains: &["xfyun.cn", "maas.xfyun.cn"],
            required_names: &["ssoSessionId", "tenantToken"],
            default_name: "XFYUN_CODING_PLAN_COOKIE",
        },
        "volcengine_coding_plan" => DashboardReauthProviderConfig {
            provider_id: "volcengine_coding_plan",
            cookie_domains: &["volcengine.com", "console.volcengine.com"],
            required_names: &["digest", "AccountID", "csrfToken"],
            default_name: "VOLCENGINE_CODING_PLAN_COOKIE",
        },
        "aliyun_coding_plan" => DashboardReauthProviderConfig {
            provider_id: "aliyun_coding_plan",
            cookie_domains: &["aliyun.com", "bailian.console.aliyun.com"],
            required_names: &["login_aliyunid_ticket", "cna"],
            default_name: "ALIYUN_CODING_PLAN_COOKIE",
        },
        "tencent_cloud_coding_plan" => DashboardReauthProviderConfig {
            provider_id: "tencent_cloud_coding_plan",
            cookie_domains: &["cloud.tencent.com", "console.cloud.tencent.com"],
            required_names: &["uin", "skey|p_skey"],
            default_name: "TENCENT_CLOUD_CODING_PLAN_COOKIE",
        },
        _ => return None,
    })
}

pub fn captured_material_is_ready(
    material: &CapturedCredentialMaterial,
    required_names: &[&str],
) -> bool {
    (!material.cookie_header.trim().is_empty() || !material.fields.is_empty())
        && missing_required_credential_names(
            &material.cookie_header,
            &material.fields,
            required_names,
        )
        .is_empty()
}

pub fn cookie_header_from_cookies(cookies: &[Cookie<'static>], domains: &[&str]) -> String {
    let normalized_domains = domains
        .iter()
        .map(|domain| normalize_domain(domain))
        .collect::<Vec<_>>();
    let mut pairs = cookies
        .iter()
        .filter_map(|cookie| {
            let cookie_domain = normalize_domain(cookie.domain().unwrap_or_default());
            let matches_domain = normalized_domains.iter().any(|allowed_domain| {
                cookie_domain == *allowed_domain
                    || cookie_domain.ends_with(&format!(".{allowed_domain}"))
            });
            matches_domain.then(|| {
                (
                    cookie.name().to_string(),
                    cookie.domain().unwrap_or_default().to_string(),
                    format!("{}={}", cookie.name(), cookie.value()),
                )
            })
        })
        .collect::<Vec<_>>();
    pairs.sort_by(|left, right| left.0.cmp(&right.0).then_with(|| left.1.cmp(&right.1)));
    pairs
        .into_iter()
        .map(|(_, _, pair)| pair)
        .collect::<Vec<_>>()
        .join("; ")
}

pub fn normalized_web_storage_fields(
    provider_id: &str,
    cookie_header: &str,
    web_storage_fields: BTreeMap<String, String>,
) -> BTreeMap<String, String> {
    if provider_id != "kimi" {
        return BTreeMap::new();
    }

    let mut fields = BTreeMap::new();
    if let Some(token) = first_non_empty_value(
        &web_storage_fields,
        &[
            "accessToken",
            "access_token",
            "authorization",
            "bearerToken",
            "bearer_token",
            "token",
            "kimi-auth",
        ],
    )
    .or_else(|| cookie_value(cookie_header, "kimi-auth"))
    {
        fields.insert("accessToken".to_string(), strip_bearer_prefix(&token));
    }
    let volcano_token_info = web_storage_fields
        .get("volcano-token-info")
        .and_then(|raw| serde_json::from_str::<Value>(raw).ok());
    if let Some(device_id) = first_non_empty_value(
        &web_storage_fields,
        &["deviceID", "deviceId", "x-msh-device-id"],
    )
    .or_else(|| first_json_string(volcano_token_info.as_ref(), &["webId"]))
    {
        fields.insert("deviceID".to_string(), device_id);
    }
    if let Some(session_id) = first_non_empty_value(
        &web_storage_fields,
        &["sessionID", "sessionId", "x-msh-session-id"],
    )
    .or_else(|| first_json_string(volcano_token_info.as_ref(), &["ssid"]))
    {
        fields.insert("sessionID".to_string(), session_id);
    }
    if let Some(traffic_id) = first_non_empty_value(
        &web_storage_fields,
        &["trafficID", "trafficId", "x-traffic-id"],
    )
    .or_else(|| first_json_string(volcano_token_info.as_ref(), &["tobid"]))
    {
        fields.insert("trafficID".to_string(), traffic_id);
    }

    fields
}

fn schedule_capture_attempt<R: Runtime>(
    app: AppHandle<R>,
    window: WebviewWindow<R>,
    capture_session: Arc<CaptureSession>,
    completed_retry_count: usize,
) {
    if capture_session.saved.load(Ordering::SeqCst) {
        return;
    }

    thread::spawn(move || {
        let delay = automatic_retry_delays(&capture_session.provider_id)
            .get(completed_retry_count)
            .copied()
            .unwrap_or(Duration::from_millis(350));
        thread::sleep(delay);
        capture_and_save(app, window, capture_session, completed_retry_count);
    });
}

fn schedule_manual_capture_attempt<R: Runtime>(
    app: AppHandle<R>,
    window: WebviewWindow<R>,
    capture_session: Arc<CaptureSession>,
) {
    if capture_session.saved.load(Ordering::SeqCst) {
        return;
    }

    thread::spawn(move || {
        capture_and_save(app, window, capture_session, 0);
    });
}

fn capture_and_save<R: Runtime>(
    app: AppHandle<R>,
    window: WebviewWindow<R>,
    capture_session: Arc<CaptureSession>,
    completed_retry_count: usize,
) {
    if capture_session.saved.load(Ordering::SeqCst) {
        return;
    }

    let material = match capture_material(&window, &capture_session) {
        Ok(material) => material,
        Err(error) => {
            eprintln!("Quota Radar web authorization capture skipped: {error}");
            match capture_unready_retry_outcome(&capture_session.provider_id, completed_retry_count)
            {
                CaptureRetryOutcome::Retry {
                    next_completed_retry_count,
                } => {
                    schedule_capture_attempt(
                        app,
                        window,
                        capture_session,
                        next_completed_retry_count,
                    );
                }
                CaptureRetryOutcome::Failed => {
                    fail_web_authorization(
                        &app,
                        &window,
                        &capture_session,
                        web_authorization_capture_error_message(&error),
                    );
                }
                CaptureRetryOutcome::Ready => {}
            }
            return;
        }
    };

    match capture_retry_outcome(
        captured_material_is_ready(&material, capture_session.required_names),
        &capture_session.provider_id,
        completed_retry_count,
    ) {
        CaptureRetryOutcome::Ready => {}
        CaptureRetryOutcome::Retry {
            next_completed_retry_count,
        } => {
            schedule_capture_attempt(app, window, capture_session, next_completed_retry_count);
            return;
        }
        CaptureRetryOutcome::Failed => {
            fail_web_authorization(
                &app,
                &window,
                &capture_session,
                web_authorization_missing_material_message(&capture_session, &material),
            );
            return;
        }
    }

    if capture_session
        .saved
        .compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
        .is_err()
    {
        return;
    }

    if let Err(error) = save_captured_material(&app, &capture_session, material) {
        capture_session.saved.store(false, Ordering::SeqCst);
        eprintln!("Quota Radar failed to save web authorization: {error}");
        fail_web_authorization(
            &app,
            &window,
            &capture_session,
            format!("Could not save web login authorization: {error}"),
        );
        return;
    }

    let _ = window.close();
    let _ = reopen_main_window(&app);
}

fn capture_retry_outcome(
    material_ready: bool,
    provider_id: &str,
    completed_retry_count: usize,
) -> CaptureRetryOutcome {
    if material_ready {
        return CaptureRetryOutcome::Ready;
    }

    if completed_retry_count + 1 < automatic_retry_delays(provider_id).len() {
        return CaptureRetryOutcome::Retry {
            next_completed_retry_count: completed_retry_count + 1,
        };
    }

    CaptureRetryOutcome::Failed
}

fn capture_unready_retry_outcome(
    provider_id: &str,
    completed_retry_count: usize,
) -> CaptureRetryOutcome {
    capture_retry_outcome(false, provider_id, completed_retry_count)
}

fn should_start_capture_after_page_load(event: PageLoadEvent, url: &Url, domains: &[&str]) -> bool {
    matches!(event, PageLoadEvent::Started | PageLoadEvent::Finished)
        && host_matches_allowed_domains(url, domains)
}

fn try_begin_initial_capture(capture_started: &AtomicBool) -> bool {
    capture_started
        .compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
        .is_ok()
}

fn fail_web_authorization<R: Runtime>(
    app: &AppHandle<R>,
    _window: &WebviewWindow<R>,
    capture_session: &CaptureSession,
    message: String,
) {
    if capture_session
        .failure_emitted
        .compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
        .is_err()
    {
        return;
    }

    emit_web_authorization_failure(
        app,
        &capture_session.provider_id,
        capture_session.target_credential_id.clone(),
        message,
    );
}

fn emit_web_authorization_failure<R: Runtime>(
    app: &AppHandle<R>,
    provider_id: &str,
    target_credential_id: Option<String>,
    message: String,
) {
    let payload = WebAuthorizationFailedPayload {
        provider_id: provider_id.to_string(),
        target_credential_id,
        message,
    };
    if let Err(error) = app.emit(WEB_AUTH_FAILED_EVENT, payload) {
        eprintln!("Quota Radar failed to emit web authorization failure: {error}");
    }
}

fn web_authorization_missing_material_message(
    capture_session: &CaptureSession,
    material: &CapturedCredentialMaterial,
) -> String {
    let missing = missing_required_credential_names(
        &material.cookie_header,
        &material.fields,
        capture_session.required_names,
    );
    if missing.is_empty() {
        return "Could not capture a usable web login authorization before the auth window timed out. Please finish login and try again.".to_string();
    }

    format!(
        "Could not capture required login data ({}) before the auth window timed out. Please finish login and try again.",
        missing.join(", ")
    )
}

fn web_authorization_capture_error_message(error: &str) -> String {
    format!(
        "Could not inspect the auth window before the web login timed out ({error}). Please finish login and try again."
    )
}

fn capture_material<R: Runtime>(
    window: &WebviewWindow<R>,
    capture_session: &CaptureSession,
) -> Result<CapturedCredentialMaterial, String> {
    let cookies = window.cookies().map_err(|error| error.to_string())?;
    let cookie_header = merge_cookie_headers(
        &cookie_header_from_cookies(&cookies, capture_session.cookie_domains),
        &capture_document_cookie_header(window, capture_session.cookie_domains).unwrap_or_default(),
    );
    let web_storage_fields = capture_web_storage_fields(window).unwrap_or_default();
    let fields = normalized_web_storage_fields(
        &capture_session.provider_id,
        &cookie_header,
        web_storage_fields,
    );

    Ok(CapturedCredentialMaterial {
        cookie_header,
        fields,
    })
}

fn capture_web_storage_fields<R: Runtime>(
    window: &WebviewWindow<R>,
) -> Result<BTreeMap<String, String>, String> {
    let (sender, receiver) = mpsc::channel();
    window
        .eval_with_callback(WEB_STORAGE_CAPTURE_SCRIPT, move |result| {
            let _ = sender.send(result);
        })
        .map_err(|error| error.to_string())?;

    let raw_result = receiver
        .recv_timeout(Duration::from_secs(2))
        .map_err(|error| error.to_string())?;
    let parsed = serde_json::from_str::<BTreeMap<String, Value>>(&raw_result).unwrap_or_default();
    Ok(parsed
        .into_iter()
        .filter_map(|(key, value)| {
            value
                .as_str()
                .map(str::trim)
                .filter(|value| !value.is_empty())
                .map(|value| (key, value.to_string()))
        })
        .collect())
}

fn capture_document_cookie_header<R: Runtime>(
    window: &WebviewWindow<R>,
    domains: &[&str],
) -> Result<String, String> {
    let (sender, receiver) = mpsc::channel();
    window
        .eval_with_callback(DOCUMENT_COOKIE_CAPTURE_SCRIPT, move |result| {
            let _ = sender.send(result);
        })
        .map_err(|error| error.to_string())?;

    let raw_result = receiver
        .recv_timeout(Duration::from_secs(2))
        .map_err(|error| error.to_string())?;
    let parsed = serde_json::from_str::<DocumentCookieCapture>(&raw_result)
        .map_err(|error| error.to_string())?;
    let current_url = Url::parse(&parsed.href).map_err(|error| error.to_string())?;

    Ok(cookie_header_from_document_cookie(
        &parsed.cookie,
        &current_url,
        domains,
    ))
}

fn cookie_header_from_document_cookie(
    document_cookie: &str,
    current_url: &Url,
    domains: &[&str],
) -> String {
    if !host_matches_allowed_domains(current_url, domains) {
        return String::new();
    }

    normalized_cookie_pairs(document_cookie)
        .into_iter()
        .map(|(_, pair)| pair)
        .collect::<Vec<_>>()
        .join("; ")
}

fn merge_cookie_headers(primary: &str, fallback: &str) -> String {
    let mut seen_names = BTreeSet::new();
    let mut pairs = Vec::new();

    for (name, pair) in normalized_cookie_pairs(primary) {
        if seen_names.insert(name.clone()) {
            pairs.push((name, pair));
        }
    }
    for (name, pair) in normalized_cookie_pairs(fallback) {
        if seen_names.insert(name.clone()) {
            pairs.push((name, pair));
        }
    }

    pairs.sort_by(|left, right| left.0.cmp(&right.0).then_with(|| left.1.cmp(&right.1)));
    pairs
        .into_iter()
        .map(|(_, pair)| pair)
        .collect::<Vec<_>>()
        .join("; ")
}

fn normalized_cookie_pairs(cookie_header: &str) -> Vec<(String, String)> {
    let mut pairs = cookie_header
        .split(';')
        .filter_map(|part| {
            let (name, value) = part.split_once('=')?;
            let name = name.trim();
            let value = value.trim();
            if name.is_empty() || value.is_empty() {
                return None;
            }
            Some((name.to_string(), format!("{name}={value}")))
        })
        .collect::<Vec<_>>();
    pairs.sort_by(|left, right| left.0.cmp(&right.0).then_with(|| left.1.cmp(&right.1)));
    pairs
}

fn save_captured_material<R: Runtime>(
    app: &AppHandle<R>,
    capture_session: &CaptureSession,
    material: CapturedCredentialMaterial,
) -> Result<(), String> {
    let metadata_store = TauriMetadataStore::open(app)?;
    let secret_vault = TauriSecretVault::open(app)?;
    let input = CapturedWebAuthorization {
        provider_id: capture_session.provider_id.clone(),
        target_credential_id: capture_session.target_credential_id.clone(),
        name: capture_session
            .target_name
            .clone()
            .or_else(|| Some(capture_session.default_name.to_string())),
        captured_fields: captured_fields_value(material),
    };
    let credential = save_web_authorization_with_stores(&metadata_store, &secret_vault, input)?;
    app.emit(WEB_AUTH_SAVED_EVENT, &credential)
        .map_err(|error| error.to_string())?;
    Ok(())
}

fn captured_fields_value(material: CapturedCredentialMaterial) -> Value {
    let mut object = Map::new();
    if !material.cookie_header.trim().is_empty() {
        object.insert("cookie".to_string(), json!(material.cookie_header));
    }
    for (key, value) in material.fields {
        object.insert(key, json!(value));
    }
    object.insert("capturedAt".to_string(), json!(Utc::now().to_rfc3339()));
    Value::Object(object)
}

fn automatic_retry_delays(provider_id: &str) -> Vec<Duration> {
    match provider_id {
        "volcengine_coding_plan" => vec![
            Duration::from_millis(350),
            Duration::from_secs(1),
            Duration::from_secs(2),
            Duration::from_secs(4),
            Duration::from_secs(7),
            Duration::from_secs(10),
            Duration::from_secs(15),
            Duration::from_secs(20),
            Duration::from_secs(30),
            Duration::from_secs(30),
        ],
        _ => vec![
            Duration::from_millis(350),
            Duration::from_secs(1),
            Duration::from_secs(2),
            Duration::from_secs(4),
            Duration::from_secs(7),
            Duration::from_secs(10),
            Duration::from_secs(15),
            Duration::from_secs(20),
            Duration::from_secs(30),
        ],
    }
}

fn missing_required_credential_names(
    cookie_header: &str,
    fields: &BTreeMap<String, String>,
    required_names: &[&str],
) -> Vec<String> {
    if required_names.is_empty() {
        return Vec::new();
    }
    let credential_names = credential_names(cookie_header, fields);
    required_names
        .iter()
        .filter(|requirement| !matches_requirement(requirement, &credential_names))
        .map(|requirement| display_name_for_requirement(requirement))
        .collect()
}

fn credential_names(cookie_header: &str, fields: &BTreeMap<String, String>) -> BTreeSet<String> {
    let mut names = cookie_header
        .split(';')
        .filter_map(|part| {
            let (name, _) = part.split_once('=')?;
            let name = name.trim();
            (!name.is_empty()).then(|| name.to_string())
        })
        .collect::<BTreeSet<_>>();

    for key in fields.keys() {
        names.insert(key.clone());
    }
    if fields.contains_key("accessToken") {
        names.insert("access_token".to_string());
        names.insert("authorization".to_string());
    }
    if fields.contains_key("access_token") {
        names.insert("accessToken".to_string());
        names.insert("authorization".to_string());
    }

    names
}

fn matches_requirement(requirement: &str, credential_names: &BTreeSet<String>) -> bool {
    requirement
        .split('|')
        .map(str::trim)
        .filter(|candidate| !candidate.is_empty())
        .any(|candidate| {
            if let Some(prefix) = candidate.strip_suffix('*') {
                return credential_names.iter().any(|name| name.starts_with(prefix));
            }
            credential_names.contains(candidate)
        })
}

fn display_name_for_requirement(requirement: &str) -> String {
    requirement
        .split('|')
        .map(str::trim)
        .filter(|candidate| !candidate.is_empty())
        .map(|candidate| candidate.strip_suffix(".*").unwrap_or(candidate))
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect::<Vec<_>>()
        .join(" / ")
}

fn host_matches_allowed_domains(url: &Url, domains: &[&str]) -> bool {
    let Some(host) = url.host_str() else {
        return false;
    };
    let normalized_host = normalize_domain(host);
    domains.iter().any(|domain| {
        let allowed_domain = normalize_domain(domain);
        normalized_host == allowed_domain
    })
}

fn first_non_empty_value(fields: &BTreeMap<String, String>, keys: &[&str]) -> Option<String> {
    keys.iter().find_map(|key| {
        fields
            .get(*key)
            .map(|value| value.trim())
            .filter(|value| !value.is_empty())
            .map(ToString::to_string)
    })
}

fn first_json_string(value: Option<&Value>, keys: &[&str]) -> Option<String> {
    let object = value?.as_object()?;
    keys.iter().find_map(|key| {
        object
            .get(*key)
            .and_then(Value::as_str)
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(ToString::to_string)
    })
}

fn cookie_value(cookie_header: &str, name: &str) -> Option<String> {
    cookie_header.split(';').find_map(|part| {
        let (cookie_name, value) = part.split_once('=')?;
        (cookie_name.trim() == name).then(|| value.trim().to_string())
    })
}

fn strip_bearer_prefix(value: &str) -> String {
    let trimmed = value.trim();
    trimmed
        .strip_prefix("Bearer ")
        .or_else(|| trimmed.strip_prefix("bearer "))
        .unwrap_or(trimmed)
        .trim()
        .to_string()
}

fn normalize_domain(domain: &str) -> String {
    domain.trim().trim_start_matches('.').to_ascii_lowercase()
}

fn close_existing_web_auth_windows<R: Runtime>(app: &AppHandle<R>) {
    for (label, window) in app.webview_windows() {
        if is_web_auth_window_label(&label) {
            let _ = window.close();
        }
    }
}

fn is_web_auth_window_label(label: &str) -> bool {
    label
        .strip_prefix(WEB_AUTH_WINDOW_PREFIX)
        .map(|suffix| suffix.starts_with('-'))
        .unwrap_or(false)
}

fn web_auth_window_label(provider_id: &str) -> String {
    let sanitized = provider_id
        .chars()
        .map(|character| {
            if character.is_ascii_alphanumeric() || character == '-' || character == '_' {
                character
            } else {
                '-'
            }
        })
        .collect::<String>();
    let sequence = WEB_AUTH_WINDOW_SEQUENCE.fetch_add(1, Ordering::Relaxed);
    format!("{WEB_AUTH_WINDOW_PREFIX}-{sanitized}-{sequence}")
}

fn web_auth_window_load_plan(navigation_url: Url) -> WebAuthWindowLoadPlan {
    WebAuthWindowLoadPlan {
        initial_route: "/?view=auth".to_string(),
        navigation_url,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn test_cookie(name: &str, value: &str, domain: &str) -> Cookie<'static> {
        Cookie::build((name.to_string(), value.to_string()))
            .domain(domain.to_string())
            .build()
    }

    #[test]
    fn dashboard_reauth_config_matches_visible_cookie_provider_contract() {
        assert_eq!(
            dashboard_reauth_provider_config("codex")
                .expect("codex should support web auth")
                .cookie_domains,
            &["chatgpt.com"]
        );
        assert_eq!(
            dashboard_reauth_provider_config("tencent_cloud_coding_plan")
                .expect("tencent should support web auth")
                .required_names,
            &["uin", "skey|p_skey"]
        );
        assert!(dashboard_reauth_provider_config("deepseek").is_none());
    }

    #[test]
    fn aliyun_reauth_required_names_match_provider_cookie_contract() {
        let config = dashboard_reauth_provider_config("aliyun_coding_plan")
            .expect("aliyun should support web auth capture");
        let material = CapturedCredentialMaterial {
            cookie_header: "cna=device-id; login_aliyunid_ticket=session".to_string(),
            fields: BTreeMap::new(),
        };

        assert_eq!(config.required_names, &["login_aliyunid_ticket", "cna"]);
        assert!(captured_material_is_ready(&material, config.required_names));
    }

    #[test]
    fn tencent_reauth_accepts_p_skey_when_skey_is_not_exposed() {
        let config = dashboard_reauth_provider_config("tencent_cloud_coding_plan")
            .expect("tencent should support web auth capture");
        let material = CapturedCredentialMaterial {
            cookie_header: "uin=o123456; p_skey=session".to_string(),
            fields: BTreeMap::new(),
        };

        assert!(captured_material_is_ready(&material, config.required_names));
    }

    #[test]
    fn xfyun_reauth_required_names_match_provider_cookie_contract() {
        let config = dashboard_reauth_provider_config("xfyun_coding_plan")
            .expect("xfyun should support web auth capture");
        let material = CapturedCredentialMaterial {
            cookie_header: "ssoSessionId=session; tenantToken=tenant".to_string(),
            fields: BTreeMap::new(),
        };

        assert_eq!(config.required_names, &["ssoSessionId", "tenantToken"]);
        assert!(captured_material_is_ready(&material, config.required_names));
    }

    #[test]
    fn web_auth_retry_delays_allow_human_login_time() {
        let total_retry_window = automatic_retry_delays("xfyun_coding_plan")
            .into_iter()
            .fold(Duration::ZERO, |total, delay| total + delay);

        assert!(total_retry_window >= Duration::from_secs(60));
    }

    #[test]
    fn capture_retry_outcome_fails_after_last_incomplete_attempt() {
        let retry_count = automatic_retry_delays("xfyun_coding_plan").len();

        assert_eq!(
            capture_retry_outcome(false, "xfyun_coding_plan", retry_count - 2),
            CaptureRetryOutcome::Retry {
                next_completed_retry_count: retry_count - 1
            }
        );
        assert_eq!(
            capture_retry_outcome(false, "xfyun_coding_plan", retry_count - 1),
            CaptureRetryOutcome::Failed
        );
    }

    #[test]
    fn web_auth_controls_follow_requested_locale_labels() {
        let script = web_auth_control_initialization_script("zh-Hans");

        assert!(script.contains("cancel.textContent = '取消';"));
        assert!(script.contains("save.textContent = '保存';"));
        assert!(!script.contains("Cancel / 取消"));
        assert!(!script.contains("Save / 保存"));
    }

    #[test]
    fn capture_errors_use_the_same_exhausting_retry_policy() {
        let retry_count = automatic_retry_delays("xfyun_coding_plan").len();

        assert_eq!(
            capture_unready_retry_outcome("xfyun_coding_plan", 0),
            CaptureRetryOutcome::Retry {
                next_completed_retry_count: 1
            }
        );
        assert_eq!(
            capture_unready_retry_outcome("xfyun_coding_plan", retry_count - 1),
            CaptureRetryOutcome::Failed
        );
    }

    #[test]
    fn web_auth_window_labels_are_detected_as_auth_windows() {
        let label = web_auth_window_label("xfyun/coding plan");

        assert!(is_web_auth_window_label(&label));
        assert!(is_web_auth_window_label("web-auth-claude"));
        assert!(!is_web_auth_window_label("web-authentic"));
        assert!(!is_web_auth_window_label("main"));
    }

    #[test]
    fn default_capability_covers_dynamic_web_auth_windows() {
        let capability = include_str!("../../capabilities/default.json");
        let value: Value = serde_json::from_str(capability).expect("capability should be JSON");
        let windows = value["windows"]
            .as_array()
            .expect("capability should list windows")
            .iter()
            .filter_map(Value::as_str)
            .collect::<Vec<_>>();

        assert!(
            windows.contains(&"web-auth-*"),
            "default capability windows must include web-auth-* for dynamic auth windows"
        );
    }

    #[test]
    fn capture_starts_after_allowed_started_or_finished_page_load() {
        let config = dashboard_reauth_provider_config("xfyun_coding_plan")
            .expect("xfyun should support web auth capture");
        let allowed_url =
            Url::parse("https://maas.xfyun.cn/packageSubscription").expect("url should parse");
        let unrelated_url = Url::parse("https://example.com/").expect("url should parse");

        assert!(should_start_capture_after_page_load(
            PageLoadEvent::Finished,
            &allowed_url,
            config.cookie_domains
        ));
        assert!(should_start_capture_after_page_load(
            PageLoadEvent::Started,
            &allowed_url,
            config.cookie_domains
        ));
        assert!(!should_start_capture_after_page_load(
            PageLoadEvent::Finished,
            &unrelated_url,
            config.cookie_domains
        ));
    }

    #[test]
    fn initial_capture_scheduling_runs_only_once_per_auth_window() {
        let capture_started = AtomicBool::new(false);

        assert!(try_begin_initial_capture(&capture_started));
        assert!(!try_begin_initial_capture(&capture_started));
    }

    #[test]
    fn claude_web_auth_accepts_claude_com_redirects() {
        let config = dashboard_reauth_provider_config("claude")
            .expect("claude should support web auth capture");
        let redirected_url =
            Url::parse("https://claude.com/app-unavailable-in-region").expect("url should parse");

        assert!(should_start_capture_after_page_load(
            PageLoadEvent::Started,
            &redirected_url,
            config.cookie_domains
        ));
    }

    #[test]
    fn opencode_web_auth_does_not_capture_auth_subdomain_intermediate_cookie() {
        let config = dashboard_reauth_provider_config("opencode_go")
            .expect("opencode should support web auth capture");
        let auth_url = Url::parse("https://auth.opencode.ai/authorize?client_id=app")
            .expect("url should parse");
        let workspace_url =
            Url::parse("https://opencode.ai/workspace/wrk_01/go").expect("url should parse");

        assert!(!should_start_capture_after_page_load(
            PageLoadEvent::Started,
            &auth_url,
            config.cookie_domains
        ));
        assert!(should_start_capture_after_page_load(
            PageLoadEvent::Started,
            &workspace_url,
            config.cookie_domains
        ));
    }

    #[test]
    fn web_auth_window_load_plan_uses_app_placeholder_before_external_navigation() {
        let login_url =
            Url::parse("https://maas.xfyun.cn/packageSubscription").expect("url should parse");

        let load_plan = web_auth_window_load_plan(login_url.clone());

        assert_eq!(load_plan.initial_route, "/?view=auth");
        assert_eq!(load_plan.navigation_url, login_url);
    }

    #[test]
    fn web_auth_control_script_exposes_manual_save_and_cancel_controls() {
        let script = web_auth_control_initialization_script("en");

        assert!(script.contains(WEB_AUTH_CONTROL_SAVE_SIGNAL));
        assert!(script.contains(WEB_AUTH_CONTROL_CANCEL_SIGNAL));
        assert!(script.contains("save.textContent = 'Save';"));
        assert!(script.contains("cancel.textContent = 'Cancel';"));
    }

    #[test]
    fn web_auth_control_signal_parses_unique_save_and_cancel_titles() {
        assert_eq!(
            web_auth_control_signal("__QUOTARADAR_WEB_AUTH_SAVE__:123"),
            Some(WebAuthControlAction::Save)
        );
        assert_eq!(
            web_auth_control_signal("__QUOTARADAR_WEB_AUTH_CANCEL__:456"),
            Some(WebAuthControlAction::Cancel)
        );
        assert_eq!(web_auth_control_signal("Claude"), None);
    }

    #[test]
    fn cookie_header_filters_and_sorts_allowed_domains() {
        let cookies = vec![
            test_cookie("z", "1", ".example.com"),
            test_cookie("a", "2", "auth.example.com"),
            test_cookie("ignored", "3", "other.com"),
        ];

        assert_eq!(
            cookie_header_from_cookies(&cookies, &["example.com"]),
            "a=2; z=1"
        );
    }

    #[test]
    fn document_cookie_header_accepts_allowed_claude_com_redirect_domain() {
        let redirected_url =
            Url::parse("https://claude.com/app-unavailable-in-region").expect("url should parse");

        assert_eq!(
            cookie_header_from_document_cookie(
                "theme=dark; sessionKeyLC=claude-session; empty=",
                &redirected_url,
                &["claude.ai", "claude.com"],
            ),
            "sessionKeyLC=claude-session; theme=dark"
        );
    }

    #[test]
    fn merged_cookie_header_preserves_window_cookie_values() {
        assert_eq!(
            merge_cookie_headers(
                "sessionKey=from-window; __cf_bm=from-window",
                "sessionKey=from-document; sessionKeyLC=from-document",
            ),
            "__cf_bm=from-window; sessionKey=from-window; sessionKeyLC=from-document"
        );
    }

    #[test]
    fn captured_material_accepts_alternative_and_prefix_cookie_requirements() {
        let material = CapturedCredentialMaterial {
            cookie_header: "__Secure-next-auth.session-token.0=abc".to_string(),
            fields: BTreeMap::new(),
        };

        assert!(captured_material_is_ready(
            &material,
            &["__Secure-next-auth.session-token|__Secure-next-auth.session-token.*|__search-next-auth"],
        ));
    }

    #[test]
    fn kimi_storage_token_counts_as_ready_without_auth_cookie() {
        let fields = BTreeMap::from([
            ("access_token".to_string(), "Bearer kimi-token".to_string()),
            ("deviceID".to_string(), "device-1".to_string()),
        ]);
        let material = CapturedCredentialMaterial {
            cookie_header: "locale=zh".to_string(),
            fields: normalized_web_storage_fields("kimi", "locale=zh", fields),
        };
        let config =
            dashboard_reauth_provider_config("kimi").expect("kimi should support web auth capture");

        assert_eq!(
            material.fields.get("accessToken").map(String::as_str),
            Some("kimi-token")
        );
        assert!(captured_material_is_ready(&material, config.required_names));
    }

    #[test]
    fn kimi_volcano_token_info_counts_as_session_metadata() {
        let fields = BTreeMap::from([
            ("access_token".to_string(), "Bearer kimi-token".to_string()),
            (
                "volcano-token-info".to_string(),
                r#"{"webId":"web-1","ssid":"session-1","tobid":"traffic-1"}"#.to_string(),
            ),
        ]);
        let material = CapturedCredentialMaterial {
            cookie_header: "locale=zh".to_string(),
            fields: normalized_web_storage_fields("kimi", "locale=zh", fields),
        };
        let config =
            dashboard_reauth_provider_config("kimi").expect("kimi should support web auth capture");

        assert_eq!(
            material.fields.get("accessToken").map(String::as_str),
            Some("kimi-token")
        );
        assert_eq!(
            material.fields.get("deviceID").map(String::as_str),
            Some("web-1")
        );
        assert_eq!(
            material.fields.get("sessionID").map(String::as_str),
            Some("session-1")
        );
        assert_eq!(
            material.fields.get("trafficID").map(String::as_str),
            Some("traffic-1")
        );
        assert!(captured_material_is_ready(&material, config.required_names));
    }

    #[test]
    fn kimi_storage_token_without_session_metadata_is_not_ready() {
        let fields = BTreeMap::from([(
            "access_token".to_string(),
            "Bearer anonymous-token".to_string(),
        )]);
        let material = CapturedCredentialMaterial {
            cookie_header: "locale=zh".to_string(),
            fields: normalized_web_storage_fields("kimi", "locale=zh", fields),
        };
        let config =
            dashboard_reauth_provider_config("kimi").expect("kimi should support web auth capture");

        assert!(!captured_material_is_ready(
            &material,
            config.required_names
        ));
    }

    #[test]
    fn kimi_auth_cookie_without_session_metadata_is_not_ready() {
        let material = CapturedCredentialMaterial {
            cookie_header: format!("{}={}", "kimi-auth", "cookie-token"),
            fields: BTreeMap::from([("accessToken".to_string(), "cookie-token".to_string())]),
        };
        let config =
            dashboard_reauth_provider_config("kimi").expect("kimi should support web auth capture");

        assert!(!captured_material_is_ready(
            &material,
            config.required_names
        ));
    }
}
