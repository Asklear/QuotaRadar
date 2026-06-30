use std::collections::{HashMap, HashSet};

use chrono::{DateTime, SecondsFormat, Utc};
use serde::Deserialize;
use serde_json::Value;

use crate::domain::{CredentialKind, CredentialStatus, CredentialView, QuotaWindow};
use crate::domain::{ProxyMode, RefreshInterval};

use super::{
    metadata_store::{
        default_settings, load_credentials, load_settings, save_credentials, save_settings,
        MetadataStore,
    },
    secret_store::SecretVault,
};

#[derive(Debug, Clone, Default)]
pub struct SwiftMigrationInput<'a> {
    pub quota_radar_defaults_json: Option<&'a str>,
    pub quota_bar_defaults_json: Option<&'a str>,
    pub quota_radar_metadata_json: Option<&'a str>,
    pub quota_bar_metadata_json: Option<&'a str>,
    pub quota_radar_secrets_json: Option<&'a str>,
    pub quota_bar_secrets_json: Option<&'a str>,
    pub metadata_cleared_by_user: bool,
    pub legacy_migration_already_completed: bool,
}

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct MigrationSummary {
    pub added: usize,
    pub skipped: usize,
    pub secrets_saved: usize,
}

pub fn migrate_swift_configuration(
    metadata_store: &impl MetadataStore,
    secret_vault: &impl SecretVault,
    input: SwiftMigrationInput<'_>,
) -> Result<MigrationSummary, String> {
    migrate_swift_settings(metadata_store, &input)?;

    if input.metadata_cleared_by_user {
        return Ok(MigrationSummary::default());
    }

    let Some(swift_metadata) = selected_metadata(&input)? else {
        return Ok(MigrationSummary::default());
    };
    let secrets = merged_secrets(&input)?;
    let mut credentials = load_credentials(metadata_store)?;
    let mut existing_ids = credentials
        .iter()
        .map(|credential| credential.id.clone())
        .collect::<HashSet<_>>();
    let mut summary = MigrationSummary::default();

    for item in swift_metadata {
        if existing_ids.contains(&item.id) {
            summary.skipped += 1;
            continue;
        }

        let Some(provider_id) = map_swift_provider(&item.provider) else {
            summary.skipped += 1;
            continue;
        };
        let secret = secrets.get(&item.id).map(String::as_str);
        let credential = swift_item_to_credential(&item, provider_id, secret);

        if let Some(secret) = secret {
            secret_vault.save(&item.id, secret)?;
            summary.secrets_saved += 1;
        }
        existing_ids.insert(item.id.clone());
        credentials.push(credential);
        summary.added += 1;
    }

    if summary.added > 0 {
        save_credentials(metadata_store, &credentials)?;
    }

    Ok(summary)
}

fn migrate_swift_settings(
    metadata_store: &impl MetadataStore,
    input: &SwiftMigrationInput<'_>,
) -> Result<(), String> {
    let Some(defaults) = selected_defaults(input)? else {
        return Ok(());
    };

    let mut settings = load_settings(metadata_store)?;
    if let Some(language) = defaults
        .app_language
        .filter(|language| is_supported_language(language))
    {
        settings.language = language;
    }
    if let Some(transparency) = defaults.status_bar_transparency {
        settings.tray_transparency = (transparency.clamp(0.0, 1.0) * 100.0).round() as u8;
    }
    if let Some(interval) = defaults
        .auto_refresh_interval
        .as_deref()
        .and_then(map_auto_refresh_interval)
    {
        settings.auto_refresh_interval = interval;
    }
    if let Some(interval) = defaults
        .quota_consuming_auto_refresh_interval
        .as_deref()
        .and_then(map_costly_refresh_interval)
    {
        settings.costly_refresh_interval = interval;
    }
    if let Some(mode) = defaults
        .network_proxy_mode
        .as_deref()
        .and_then(map_proxy_mode)
    {
        settings.proxy.mode = mode;
    }
    if let Some(custom_url) = defaults.custom_proxy_url {
        settings.proxy.custom_url = if custom_url.trim().is_empty() {
            None
        } else {
            Some(custom_url)
        };
    }
    if let Some(update_check) = defaults.automatically_check_for_updates {
        settings.update_check = update_check;
    }
    if defaults.custom_provider_order_enabled == Some(true) {
        if let Some(provider_order) = defaults.provider_order {
            settings.provider_order = migrated_provider_order(&provider_order);
        }
    }

    save_settings(metadata_store, &settings)
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct SwiftDefaults {
    app_language: Option<String>,
    status_bar_transparency: Option<f64>,
    auto_refresh_interval: Option<String>,
    quota_consuming_auto_refresh_interval: Option<String>,
    network_proxy_mode: Option<String>,
    #[serde(rename = "customProxyURL", alias = "customProxyUrl")]
    custom_proxy_url: Option<String>,
    automatically_check_for_updates: Option<bool>,
    custom_provider_order_enabled: Option<bool>,
    provider_order: Option<Vec<String>>,
}

impl SwiftDefaults {
    fn overlay(&mut self, other: SwiftDefaults) {
        self.app_language = other.app_language.or(self.app_language.take());
        self.status_bar_transparency = other
            .status_bar_transparency
            .or(self.status_bar_transparency);
        self.auto_refresh_interval = other
            .auto_refresh_interval
            .or(self.auto_refresh_interval.take());
        self.quota_consuming_auto_refresh_interval = other
            .quota_consuming_auto_refresh_interval
            .or(self.quota_consuming_auto_refresh_interval.take());
        self.network_proxy_mode = other.network_proxy_mode.or(self.network_proxy_mode.take());
        self.custom_proxy_url = other.custom_proxy_url.or(self.custom_proxy_url.take());
        self.automatically_check_for_updates = other
            .automatically_check_for_updates
            .or(self.automatically_check_for_updates);
        self.custom_provider_order_enabled = other
            .custom_provider_order_enabled
            .or(self.custom_provider_order_enabled);
        self.provider_order = other.provider_order.or(self.provider_order.take());
    }

    fn is_empty(&self) -> bool {
        self.app_language.is_none()
            && self.status_bar_transparency.is_none()
            && self.auto_refresh_interval.is_none()
            && self.quota_consuming_auto_refresh_interval.is_none()
            && self.network_proxy_mode.is_none()
            && self.custom_proxy_url.is_none()
            && self.automatically_check_for_updates.is_none()
            && self.custom_provider_order_enabled.is_none()
            && self.provider_order.is_none()
    }
}

fn selected_defaults(input: &SwiftMigrationInput<'_>) -> Result<Option<SwiftDefaults>, String> {
    let mut defaults = if input.legacy_migration_already_completed {
        SwiftDefaults::default()
    } else {
        parse_defaults(input.quota_bar_defaults_json)?.unwrap_or_default()
    };
    if let Some(current) = parse_defaults(input.quota_radar_defaults_json)? {
        defaults.overlay(current);
    }

    if defaults.is_empty() {
        Ok(None)
    } else {
        Ok(Some(defaults))
    }
}

fn parse_defaults(value: Option<&str>) -> Result<Option<SwiftDefaults>, String> {
    let Some(value) = value.filter(|value| !value.trim().is_empty()) else {
        return Ok(None);
    };

    serde_json::from_str(value)
        .map(Some)
        .map_err(|error| format!("Could not parse Swift defaults: {error}"))
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
struct SwiftStoredApiKey {
    id: String,
    name: String,
    provider: String,
    is_active: bool,
    note: Option<String>,
    #[serde(rename = "linkedAuthorizationID", alias = "linkedAuthorizationId")]
    linked_authorization_id: Option<String>,
    remaining: Option<f64>,
    limit: Option<f64>,
    reset_at: Option<Value>,
    plan_ends_at: Option<Value>,
    codex_reset_credits_remaining: Option<u32>,
    codex_reset_credits_earliest_expires_at: Option<String>,
    last_updated: Option<Value>,
    #[serde(rename = "lastHTTPStatus", alias = "lastHttpStatus")]
    last_http_status: Option<u16>,
    last_diagnostic_message: Option<String>,
    quota_label: Option<String>,
}

fn selected_metadata(
    input: &SwiftMigrationInput<'_>,
) -> Result<Option<Vec<SwiftStoredApiKey>>, String> {
    let current = parse_metadata(input.quota_radar_metadata_json)?;
    if current.as_ref().is_some_and(|items| !items.is_empty()) {
        return Ok(current);
    }

    let legacy = if input.legacy_migration_already_completed {
        None
    } else {
        parse_metadata(input.quota_bar_metadata_json)?
    };
    if legacy.as_ref().is_some_and(|items| !items.is_empty()) {
        return Ok(legacy);
    }

    Ok(None)
}

fn parse_metadata(value: Option<&str>) -> Result<Option<Vec<SwiftStoredApiKey>>, String> {
    let Some(value) = value.filter(|value| !value.trim().is_empty()) else {
        return Ok(None);
    };

    serde_json::from_str(value)
        .map(Some)
        .map_err(|error| format!("Could not parse Swift credential metadata: {error}"))
}

fn merged_secrets(input: &SwiftMigrationInput<'_>) -> Result<HashMap<String, String>, String> {
    let mut secrets = if input.legacy_migration_already_completed {
        HashMap::new()
    } else {
        parse_secrets(input.quota_bar_secrets_json)?
    };
    for (id, secret) in parse_secrets(input.quota_radar_secrets_json)? {
        secrets.insert(id, secret);
    }
    Ok(secrets)
}

fn parse_secrets(value: Option<&str>) -> Result<HashMap<String, String>, String> {
    let Some(value) = value.filter(|value| !value.trim().is_empty()) else {
        return Ok(HashMap::new());
    };

    serde_json::from_str(value)
        .map_err(|error| format!("Could not parse Swift credential secrets: {error}"))
}

fn swift_item_to_credential(
    item: &SwiftStoredApiKey,
    provider_id: &str,
    secret: Option<&str>,
) -> CredentialView {
    let kind = credential_kind(
        provider_id,
        &item.name,
        item.linked_authorization_id.as_deref(),
    );
    let remaining_badge_text = remaining_badge_text(item.remaining, item.limit)
        .unwrap_or_else(|| default_badge_text(&kind).to_string());
    let reset_at = swift_date_to_rfc3339(item.reset_at.as_ref());
    let plan_ends_at = swift_date_to_rfc3339(item.plan_ends_at.as_ref());
    let last_updated = swift_date_to_rfc3339(item.last_updated.as_ref());
    let status = credential_status(item, item.remaining.is_some() || item.limit.is_some());
    let quota_windows = quota_windows(item.remaining, item.limit, reset_at.as_deref());

    CredentialView {
        id: item.id.clone(),
        provider_id: provider_id.to_string(),
        name: item.name.clone(),
        kind: kind.clone(),
        masked_value: masked_value(&kind, secret),
        copyable: !matches!(kind, CredentialKind::DashboardCookie),
        active: item.is_active,
        status,
        remaining: item.remaining,
        limit: item.limit,
        remaining_badge_text,
        quota_label: item.quota_label.clone(),
        quota_windows,
        reset_at,
        plan_ends_at,
        codex_reset_credits_remaining: item.codex_reset_credits_remaining,
        codex_reset_credits_earliest_expires_at: item
            .codex_reset_credits_earliest_expires_at
            .clone(),
        last_updated,
        last_http_status: item.last_http_status,
        diagnostic_message: item.last_diagnostic_message.clone(),
        note: item.note.clone(),
        linked_authorization_id: item.linked_authorization_id.clone(),
    }
}

fn map_swift_provider(provider: &str) -> Option<&'static str> {
    match provider {
        "Tavily" => Some("tavily"),
        "Brave" => Some("brave"),
        "SerpAPI" => Some("serpapi"),
        "Serper" => Some("serper"),
        "Exa" => Some("exa"),
        "Querit" => Some("querit"),
        "Bocha" => Some("bocha"),
        "AnySearch" => Some("anysearch"),
        "微信搜索" | "WeChat Search" => Some("wxmp"),
        "DeepSeek" | "Deepseek" => Some("deepseek"),
        "Claude Subscription" => Some("claude"),
        "Codex Subscription" => Some("codex"),
        "Kimi Subscription" => Some("kimi"),
        "OpenCode Go" => Some("opencode_go"),
        "讯飞星火" | "XFYun Spark Coding Plan" => Some("xfyun_coding_plan"),
        "火山引擎" | "Volcengine Coding Plan" => Some("volcengine_coding_plan"),
        "Aliyun Coding Plan" => Some("aliyun_coding_plan"),
        "Tencent Cloud Coding Plan" => Some("tencent_cloud_coding_plan"),
        _ => None,
    }
}

fn is_supported_language(language: &str) -> bool {
    matches!(language, "en" | "zh-Hans" | "zh-Hant" | "ja" | "ko")
}

fn map_auto_refresh_interval(value: &str) -> Option<RefreshInterval> {
    match value {
        "off" => Some(RefreshInterval::Off),
        "fiveMinutes" | "fifteenMinutes" | "thirtyMinutes" => Some(RefreshInterval::ThirtyMinutes),
        "oneHour" => Some(RefreshInterval::OneHour),
        _ => None,
    }
}

fn map_costly_refresh_interval(value: &str) -> Option<RefreshInterval> {
    match value {
        "off" => Some(RefreshInterval::Off),
        "sixHours" | "twelveHours" | "oneDay" => Some(RefreshInterval::SixHours),
        _ => None,
    }
}

fn map_proxy_mode(value: &str) -> Option<ProxyMode> {
    match value {
        "system" => Some(ProxyMode::System),
        "direct" => Some(ProxyMode::Direct),
        "custom" => Some(ProxyMode::Custom),
        _ => None,
    }
}

fn migrated_provider_order(swift_order: &[String]) -> Vec<String> {
    let mut order = Vec::new();
    for provider in swift_order
        .iter()
        .filter_map(|provider| map_swift_provider(provider))
    {
        if !order.iter().any(|existing| existing == provider) {
            order.push(provider.to_string());
        }
    }

    for provider in default_settings().provider_order {
        if !order.contains(&provider) {
            order.push(provider);
        }
    }

    order
}

fn credential_kind(
    provider_id: &str,
    name: &str,
    linked_authorization_id: Option<&str>,
) -> CredentialKind {
    if linked_authorization_id.is_some() || is_companion_api_key_name(provider_id, name) {
        return CredentialKind::StoredApiKeyOnly;
    }

    if matches!(provider_id, "exa") {
        return CredentialKind::AdminCredential;
    }

    if is_dashboard_authorization_provider(provider_id) {
        return CredentialKind::DashboardCookie;
    }

    CredentialKind::ApiKey
}

fn is_dashboard_authorization_provider(provider_id: &str) -> bool {
    matches!(
        provider_id,
        "claude"
            | "codex"
            | "kimi"
            | "opencode_go"
            | "xfyun_coding_plan"
            | "volcengine_coding_plan"
            | "aliyun_coding_plan"
            | "tencent_cloud_coding_plan"
    )
}

fn is_companion_api_key_name(provider_id: &str, name: &str) -> bool {
    let expected = match provider_id {
        "claude" => "ANTHROPIC_API_KEY",
        "codex" => "OPENAI_API_KEY",
        "kimi" => "KIMI_API_KEY",
        "opencode_go" => "OPENCODE_GO_API_KEY",
        "xfyun_coding_plan" => "XFYUN_CODING_PLAN_API_KEY",
        "volcengine_coding_plan" => "VOLCENGINE_CODING_PLAN_API_KEY",
        "aliyun_coding_plan" => "ALIYUN_CODING_PLAN_API_KEY",
        "tencent_cloud_coding_plan" => "TENCENT_CLOUD_CODING_PLAN_API_KEY",
        _ => return false,
    };

    name == expected
}

fn credential_status(item: &SwiftStoredApiKey, has_quota_snapshot: bool) -> CredentialStatus {
    if !item.is_active {
        return CredentialStatus::Disabled;
    }

    match item.last_http_status {
        Some(401 | 403) => CredentialStatus::Expired,
        Some(status) if status >= 400 => CredentialStatus::Failed,
        Some(_) if has_quota_snapshot => CredentialStatus::Healthy,
        _ if has_quota_snapshot => CredentialStatus::Healthy,
        _ => CredentialStatus::NotChecked,
    }
}

fn remaining_badge_text(remaining: Option<f64>, limit: Option<f64>) -> Option<String> {
    Some(format!(
        "{} / {}",
        format_number(remaining?),
        format_number(limit?)
    ))
}

fn default_badge_text(kind: &CredentialKind) -> &'static str {
    match kind {
        CredentialKind::DashboardCookie => "Authorization saved",
        CredentialKind::StoredApiKeyOnly => "API key saved",
        CredentialKind::AdminCredential => "Credential saved",
        CredentialKind::ApiKey => "Saved",
    }
}

fn quota_windows(
    remaining: Option<f64>,
    limit: Option<f64>,
    reset_at: Option<&str>,
) -> Vec<QuotaWindow> {
    let Some(remaining) = remaining else {
        return Vec::new();
    };
    let Some(limit) = limit.filter(|limit| *limit > 0.0) else {
        return Vec::new();
    };
    let Some(reset_at) = reset_at else {
        return Vec::new();
    };

    vec![QuotaWindow::percent(
        "month",
        (remaining / limit * 100.0 * 10.0).round() / 10.0,
        reset_at,
    )]
}

fn masked_value(kind: &CredentialKind, secret: Option<&str>) -> String {
    if matches!(kind, CredentialKind::DashboardCookie) {
        return "Web login authorization saved".to_string();
    }

    secret
        .map(mask_secret)
        .unwrap_or_else(|| "••••".to_string())
}

fn mask_secret(secret: &str) -> String {
    let chars = secret.chars().collect::<Vec<_>>();
    if chars.len() <= 8 {
        return "••••".to_string();
    }

    let prefix = chars.iter().take(4).collect::<String>();
    let suffix = chars
        .iter()
        .skip(chars.len().saturating_sub(4))
        .collect::<String>();
    format!("{prefix}••••{suffix}")
}

fn swift_date_to_rfc3339(value: Option<&Value>) -> Option<String> {
    const APPLE_REFERENCE_UNIX_OFFSET: f64 = 978_307_200.0;

    match value? {
        Value::Number(number) => {
            let swift_seconds = number.as_f64()?;
            let unix_seconds = (swift_seconds + APPLE_REFERENCE_UNIX_OFFSET).round() as i64;
            let date_time = DateTime::<Utc>::from_timestamp(unix_seconds, 0)?;
            Some(date_time.to_rfc3339_opts(SecondsFormat::Secs, true))
        }
        Value::String(text) => DateTime::parse_from_rfc3339(text)
            .map(|date_time| {
                date_time
                    .with_timezone(&Utc)
                    .to_rfc3339_opts(SecondsFormat::Secs, true)
            })
            .ok()
            .or_else(|| Some(text.clone())),
        _ => None,
    }
}

fn format_number(value: f64) -> String {
    if (value.fract()).abs() < f64::EPSILON {
        return format!("{}", value.round() as i64);
    }

    format!("{value:.2}")
        .trim_end_matches('0')
        .trim_end_matches('.')
        .to_string()
}
