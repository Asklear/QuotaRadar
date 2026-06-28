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
use serde::Serialize;
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
static WEB_AUTH_WINDOW_SEQUENCE: AtomicU64 = AtomicU64::new(1);
const WEB_STORAGE_CAPTURE_SCRIPT: &str = r#"
(() => {
  const keys = [
    'kimi-auth', 'accessToken', 'access_token', 'authorization', 'bearerToken', 'bearer_token', 'token',
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

#[derive(Debug, Clone)]
pub struct WebAuthorizationWindowRequest {
    pub provider_id: String,
    pub target_credential_id: Option<String>,
    pub target_name: Option<String>,
    pub login_url: String,
}

#[derive(Debug, Clone)]
struct CaptureSession {
    provider_id: String,
    target_credential_id: Option<String>,
    target_name: Option<String>,
    default_name: &'static str,
    cookie_domains: &'static [&'static str],
    required_names: &'static [&'static str],
    saved: Arc<AtomicBool>,
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
        saved: Arc::new(AtomicBool::new(false)),
    });
    let app_for_page_load = app.clone();
    let capture_session_for_page_load = capture_session.clone();

    let window =
        WebviewWindowBuilder::new(app, &label, WebviewUrl::App(load_plan.initial_route.into()))
            .title(format!("Quota Radar - {}", request.provider_id))
            .inner_size(720.0, 820.0)
            .min_inner_size(520.0, 600.0)
            .center()
            .focused(true)
            .on_page_load(move |window, payload| {
                if !should_start_capture_after_page_load(
                    payload.event(),
                    payload.url(),
                    capture_session_for_page_load.cookie_domains,
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

pub fn spawn_web_authorization_window<R: Runtime>(
    app: &AppHandle<R>,
    request: WebAuthorizationWindowRequest,
) -> Result<(), String> {
    validate_web_authorization_window_request(&request)?;

    let app_for_window = app.clone();
    app.run_on_main_thread(move || {
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
    })
    .map_err(|error| error.to_string())
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
            cookie_domains: &["claude.ai"],
            required_names: &["sessionKey|sessionKeyLC"],
            default_name: "CLAUDE_SUBSCRIPTION_SESSION",
        },
        "anthropic_credits" => DashboardReauthProviderConfig {
            provider_id: "anthropic_credits",
            cookie_domains: &["claude.ai"],
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
            required_names: &["kimi-auth|accessToken|access_token"],
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
            required_names: &["login_aliyunid_ticket", "aliyun_lang", "cna"],
            default_name: "ALIYUN_CODING_PLAN_COOKIE",
        },
        "tencent_cloud_coding_plan" => DashboardReauthProviderConfig {
            provider_id: "tencent_cloud_coding_plan",
            cookie_domains: &["cloud.tencent.com", "console.cloud.tencent.com"],
            required_names: &["uin", "skey"],
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
    if let Some(device_id) = first_non_empty_value(
        &web_storage_fields,
        &["deviceID", "deviceId", "x-msh-device-id"],
    ) {
        fields.insert("deviceID".to_string(), device_id);
    }
    if let Some(session_id) = first_non_empty_value(
        &web_storage_fields,
        &["sessionID", "sessionId", "x-msh-session-id"],
    ) {
        fields.insert("sessionID".to_string(), session_id);
    }
    if let Some(traffic_id) = first_non_empty_value(
        &web_storage_fields,
        &["trafficID", "trafficId", "x-traffic-id"],
    ) {
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
    event == PageLoadEvent::Finished && host_matches_allowed_domains(url, domains)
}

fn fail_web_authorization<R: Runtime>(
    app: &AppHandle<R>,
    window: &WebviewWindow<R>,
    capture_session: &CaptureSession,
    message: String,
) {
    if capture_session
        .saved
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
    let _ = window.close();
    let _ = reopen_main_window(app);
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
    let cookie_header = cookie_header_from_cookies(&cookies, capture_session.cookie_domains);
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
            || normalized_host.ends_with(&format!(".{allowed_domain}"))
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
            &["uin", "skey"]
        );
        assert!(dashboard_reauth_provider_config("deepseek").is_none());
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
    fn capture_starts_only_after_allowed_finished_page_load() {
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
        assert!(!should_start_capture_after_page_load(
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
    fn web_auth_window_load_plan_uses_app_placeholder_before_external_navigation() {
        let login_url =
            Url::parse("https://maas.xfyun.cn/packageSubscription").expect("url should parse");

        let load_plan = web_auth_window_load_plan(login_url.clone());

        assert_eq!(load_plan.initial_route, "/?view=auth");
        assert_eq!(load_plan.navigation_url, login_url);
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

        assert_eq!(
            material.fields.get("accessToken").map(String::as_str),
            Some("kimi-token")
        );
        assert!(captured_material_is_ready(
            &material,
            &["kimi-auth|accessToken|access_token"]
        ));
    }
}
