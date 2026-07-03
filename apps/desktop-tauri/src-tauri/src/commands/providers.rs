use tauri::{AppHandle, Runtime};

use crate::{
    domain::{AppState, CredentialKind, CredentialStatus, CredentialView, ProviderDefinition},
    providers::{
        codex_subscription::CodexSubscriptionProvider,
        registry::{provider_clients, visible_provider_definitions},
        ProviderCredential, ProviderTransport, QuotaSnapshot, ReqwestProviderTransport,
    },
    storage::{
        metadata_store::{
            load_credentials, load_settings, save_credentials, MetadataStore, TauriMetadataStore,
        },
        secret_store::{SecretVault, TauriSecretVault},
    },
};

#[tauri::command]
pub fn list_provider_definitions() -> Vec<ProviderDefinition> {
    visible_provider_definitions()
}

#[tauri::command]
pub fn refresh_provider<R: Runtime>(
    app: AppHandle<R>,
    provider_id: String,
    mode: String,
) -> Result<AppState, String> {
    let metadata_store = TauriMetadataStore::open(&app)?;
    let secret_vault = TauriSecretVault::open(&app)?;
    let settings = load_settings(&metadata_store)?;
    let transport = ReqwestProviderTransport::from_proxy_settings(&settings.proxy)
        .map_err(|error| error.to_string())?;
    refresh_provider_with_transport(
        &metadata_store,
        &secret_vault,
        &provider_id,
        &mode,
        now_rfc3339,
        &transport,
    )
}

#[tauri::command]
pub fn reset_codex_quota<R: Runtime>(
    app: AppHandle<R>,
    credential_id: String,
) -> Result<AppState, String> {
    let metadata_store = TauriMetadataStore::open(&app)?;
    let secret_vault = TauriSecretVault::open(&app)?;
    let settings = load_settings(&metadata_store)?;
    let transport = ReqwestProviderTransport::from_proxy_settings(&settings.proxy)
        .map_err(|error| error.to_string())?;
    reset_codex_quota_with_transport(
        &metadata_store,
        &secret_vault,
        &credential_id,
        now_rfc3339,
        &transport,
    )
}

#[cfg(test)]
fn refresh_provider_with_stores(
    metadata_store: &impl MetadataStore,
    secret_vault: &impl SecretVault,
    provider_id: &str,
    mode: &str,
    now: impl Fn() -> String,
) -> Result<AppState, String> {
    refresh_provider_core(metadata_store, secret_vault, provider_id, mode, now, None)
}

fn refresh_provider_with_transport(
    metadata_store: &impl MetadataStore,
    secret_vault: &impl SecretVault,
    provider_id: &str,
    mode: &str,
    now: impl Fn() -> String,
    transport: &dyn ProviderTransport,
) -> Result<AppState, String> {
    refresh_provider_core(
        metadata_store,
        secret_vault,
        provider_id,
        mode,
        now,
        Some(transport),
    )
}

fn reset_codex_quota_with_transport(
    metadata_store: &impl MetadataStore,
    secret_vault: &impl SecretVault,
    credential_id: &str,
    now: impl Fn() -> String,
    transport: &dyn ProviderTransport,
) -> Result<AppState, String> {
    let mut credentials = load_credentials(metadata_store)?;
    let credential = credentials
        .iter_mut()
        .find(|credential| credential.id == credential_id)
        .ok_or_else(|| "Credential was not found".to_string())?;

    if credential.provider_id != "codex" {
        return Err("Codex reset credits are only supported for Codex credentials".to_string());
    }

    if matches!(credential.kind, CredentialKind::StoredApiKeyOnly) {
        return Err("Codex reset credits require web login authorization".to_string());
    }

    let checked_at = now();
    let result = secret_vault
        .read(&credential.id)
        .and_then(|secret| secret.ok_or_else(|| "Credential value was not found".to_string()))
        .and_then(|secret| {
            CodexSubscriptionProvider
                .consume_reset_credit(
                    ProviderCredential {
                        provider_id: credential.provider_id.clone(),
                        secret,
                    },
                    transport,
                )
                .map_err(|error| error.to_string())
        });

    match result {
        Ok(snapshot) => apply_quota_snapshot(credential, snapshot, checked_at),
        Err(message) => apply_refresh_failure(credential, message, checked_at),
    }

    save_credentials(metadata_store, &credentials)?;
    Ok(super::app_state::app_state_from_credentials(credentials))
}

fn refresh_provider_core(
    metadata_store: &impl MetadataStore,
    secret_vault: &impl SecretVault,
    provider_id: &str,
    mode: &str,
    now: impl Fn() -> String,
    transport: Option<&dyn ProviderTransport>,
) -> Result<AppState, String> {
    let mut credentials = load_credentials(metadata_store)?;
    let clients = provider_clients();
    let client = clients
        .iter()
        .find(|candidate| candidate.provider_id() == provider_id)
        .ok_or_else(|| format!("Provider client is not registered: {provider_id}"))?;

    if client.consumes_quota_on_check() && !refresh_mode_allows_costly(mode) {
        return Ok(super::app_state::app_state_from_credentials(credentials));
    }

    for credential in credentials
        .iter_mut()
        .filter(|credential| credential.provider_id == provider_id && credential.active)
    {
        if matches!(credential.kind, CredentialKind::StoredApiKeyOnly) {
            continue;
        }

        let checked_at = now();
        let result = secret_vault
            .read(&credential.id)
            .and_then(|secret| secret.ok_or_else(|| "Credential value was not found".to_string()))
            .and_then(|secret| {
                let provider_credential = ProviderCredential {
                    provider_id: credential.provider_id.clone(),
                    secret,
                };
                match transport {
                    Some(transport) => client.check_quota(provider_credential, transport),
                    None => client.check_fixture_quota(provider_credential),
                }
                .map_err(|error| error.to_string())
            });

        match result {
            Ok(snapshot) => apply_quota_snapshot(credential, snapshot, checked_at),
            Err(message) => apply_refresh_failure(credential, message, checked_at),
        }
    }

    save_credentials(metadata_store, &credentials)?;
    Ok(super::app_state::app_state_from_credentials(credentials))
}

fn apply_quota_snapshot(
    credential: &mut CredentialView,
    snapshot: QuotaSnapshot,
    checked_at: String,
) {
    credential.status = CredentialStatus::Healthy;
    credential.remaining = snapshot.remaining;
    credential.limit = snapshot.limit;
    credential.remaining_badge_text = snapshot.remaining_badge_text;
    credential.quota_label = snapshot.quota_label;
    credential.quota_windows = snapshot.quota_windows;
    credential.reset_at = snapshot.reset_at;
    credential.plan_ends_at = snapshot.plan_ends_at;
    credential.codex_reset_credits_remaining = snapshot.codex_reset_credits_remaining;
    credential.codex_reset_credits_earliest_expires_at =
        snapshot.codex_reset_credits_earliest_expires_at;
    credential.last_updated = Some(checked_at);
    credential.last_http_status = Some(200);
    credential.diagnostic_message = None;
}

fn apply_refresh_failure(credential: &mut CredentialView, message: String, checked_at: String) {
    credential.status = CredentialStatus::Failed;
    credential.remaining_badge_text = "Check failed".to_string();
    credential.quota_windows.clear();
    credential.last_updated = Some(checked_at);
    credential.last_http_status = None;
    credential.diagnostic_message = Some(message);
}

fn refresh_mode_allows_costly(mode: &str) -> bool {
    matches!(mode, "manual" | "costlyAutomatic")
}

fn now_rfc3339() -> String {
    chrono::Utc::now().to_rfc3339()
}

#[cfg(test)]
mod tests {
    use crate::{
        domain::{CredentialStatus, CredentialView},
        providers::http::{MockProviderTransport, ProviderHttpResponse},
        storage::{
            metadata_store::{load_credentials, save_credentials, MemoryMetadataStore},
            secret_store::{save_secret, MemorySecretVault},
        },
    };

    use super::{
        refresh_provider_with_stores, refresh_provider_with_transport,
        reset_codex_quota_with_transport,
    };

    fn fixed_now() -> String {
        "2026-06-11T12:40:00+08:00".to_string()
    }

    #[test]
    fn refresh_provider_updates_active_api_key_snapshot() {
        let metadata_store = MemoryMetadataStore::default();
        let secret_vault = MemorySecretVault::default();
        let credential = CredentialView::api_key(
            "tavily-test",
            "tavily",
            "Tavily Test",
            "tvly••••alue",
            CredentialStatus::NotChecked,
            "Saved",
            None,
            None,
            Vec::new(),
            None,
            None,
            None,
        );
        save_credentials(&metadata_store, &[credential]).expect("metadata should save");
        save_secret(&secret_vault, "tavily-test", "tvly-fixture").expect("secret should save");

        let state = refresh_provider_with_stores(
            &metadata_store,
            &secret_vault,
            "tavily",
            "manual",
            fixed_now,
        )
        .expect("refresh should succeed");

        let updated = state
            .credentials
            .iter()
            .find(|credential| credential.id == "tavily-test")
            .expect("credential should remain visible");
        assert_eq!(updated.status, CredentialStatus::Healthy);
        assert_eq!(updated.remaining, Some(920.0));
        assert_eq!(updated.limit, Some(1000.0));
        assert_eq!(updated.remaining_badge_text, "920 / 1000");
        assert_eq!(
            updated.last_updated.as_deref(),
            Some("2026-06-11T12:40:00+08:00")
        );
        assert_eq!(updated.last_http_status, Some(200));

        let persisted = load_credentials(&metadata_store).expect("metadata should load");
        assert_eq!(persisted[0].status, CredentialStatus::Healthy);
    }

    #[test]
    fn refresh_provider_transport_path_updates_from_http_response() {
        let metadata_store = MemoryMetadataStore::default();
        let secret_vault = MemorySecretVault::default();
        let credential = CredentialView::api_key(
            "tavily-live",
            "tavily",
            "Tavily Live",
            "tvly••••live",
            CredentialStatus::NotChecked,
            "Saved",
            None,
            None,
            Vec::new(),
            None,
            None,
            None,
        );
        save_credentials(&metadata_store, &[credential]).expect("metadata should save");
        save_secret(&secret_vault, "tavily-live", "tvly-live-test").expect("secret should save");
        let transport = MockProviderTransport::responding(ProviderHttpResponse::new(
            200,
            r#"{"key":{"usage":125,"limit":1000},"account":{"plan_usage":300,"plan_limit":5000}}"#,
        ));

        let state = refresh_provider_with_transport(
            &metadata_store,
            &secret_vault,
            "tavily",
            "manual",
            fixed_now,
            &transport,
        )
        .expect("refresh should use transport");

        let updated = &state.credentials[0];
        assert_eq!(updated.status, CredentialStatus::Healthy);
        assert_eq!(updated.remaining, Some(875.0));
        assert_eq!(updated.limit, Some(1000.0));
        assert_eq!(updated.remaining_badge_text, "875 / 1000");
        assert_eq!(transport.requests().len(), 1);
    }

    #[test]
    fn reset_codex_quota_consumes_credit_and_persists_refreshed_snapshot() {
        let metadata_store = MemoryMetadataStore::default();
        let secret_vault = MemorySecretVault::default();
        let mut credential = CredentialView::web_login(
            "codex-web-pro",
            "codex",
            "Codex Pro Login",
            "Web login saved",
            CredentialStatus::Healthy,
            "5h 20% · week 40%",
            Vec::new(),
            Some("2026-07-08T16:42:25Z"),
            Some("2026-06-11T10:00:00+08:00"),
            Some(200),
        );
        credential.codex_reset_credits_remaining = Some(2);
        credential.codex_reset_credits_earliest_expires_at =
            Some("2026-07-18T00:38:14Z".to_string());
        save_credentials(&metadata_store, &[credential]).expect("metadata should save");
        save_secret(
            &secret_vault,
            "codex-web-pro",
            "__Secure-next-auth.session-token=chatgpt-session-placeholder; __search-next-auth=search-session-placeholder",
        )
        .expect("secret should save");
        let transport = MockProviderTransport::responding_many(vec![
            ProviderHttpResponse::new(200, r#"{"accessToken":"at1","account":{"id":"acct1"}}"#),
            ProviderHttpResponse::new(200, r#"{"ok":true}"#),
            ProviderHttpResponse::new(
                200,
                r#"{"plan_type":"pro","rate_limit":{"primary_window":{"used_percent":4,"limit_window_seconds":18000,"reset_at":1782864000},"secondary_window":{"used_percent":20,"limit_window_seconds":604800,"reset_at":1783468800}}}"#,
            ),
            ProviderHttpResponse::new(
                200,
                r#"{"active_until":"2026-07-08T16:42:25Z","plan_type":"pro"}"#,
            ),
            ProviderHttpResponse::new(
                200,
                r#"{"credits":[{"id":"reset-3","reset_type":"codex_rate_limits","status":"available","expires_at":"2026-07-26T23:56:41Z","redeemed_at":null}],"available_count":1}"#,
            ),
        ]);

        let state = reset_codex_quota_with_transport(
            &metadata_store,
            &secret_vault,
            "codex-web-pro",
            fixed_now,
            &transport,
        )
        .expect("reset should return updated app state");

        let updated = state
            .credentials
            .iter()
            .find(|credential| credential.id == "codex-web-pro")
            .expect("credential should remain visible");
        assert_eq!(updated.status, CredentialStatus::Healthy);
        assert_eq!(updated.remaining, Some(8000.0));
        assert_eq!(updated.remaining_badge_text, "5h 96% · week 80%");
        assert_eq!(updated.last_http_status, Some(200));
        assert_eq!(
            updated.last_updated.as_deref(),
            Some("2026-06-11T12:40:00+08:00")
        );
        assert_eq!(updated.codex_reset_credits_remaining, Some(1));

        let persisted = load_credentials(&metadata_store).expect("metadata should load");
        assert_eq!(persisted[0].codex_reset_credits_remaining, Some(1));
        assert_eq!(transport.requests()[1].method, "POST");
    }

    #[test]
    fn refresh_provider_skips_stored_api_key_only_credentials() {
        let metadata_store = MemoryMetadataStore::default();
        let secret_vault = MemorySecretVault::default();
        let credential = CredentialView::stored_api_key(
            "tavily-stored-key",
            "tavily",
            "Tavily Stored Key",
            "tvly••••alue",
            "Saved",
            None,
            None,
        );
        save_credentials(&metadata_store, &[credential]).expect("metadata should save");

        let state = refresh_provider_with_stores(
            &metadata_store,
            &secret_vault,
            "tavily",
            "manual",
            fixed_now,
        )
        .expect("refresh should leave stored keys unchanged");

        let skipped = &state.credentials[0];
        assert_eq!(skipped.status, CredentialStatus::NotChecked);
        assert_eq!(skipped.remaining_badge_text, "Saved");
        assert_eq!(skipped.last_updated, None);
    }

    #[test]
    fn refresh_provider_persists_failed_diagnostics_when_secret_is_missing() {
        let metadata_store = MemoryMetadataStore::default();
        let secret_vault = MemorySecretVault::default();
        let credential = CredentialView::api_key(
            "tavily-missing",
            "tavily",
            "Tavily Missing",
            "tvly••••sing",
            CredentialStatus::NotChecked,
            "Saved",
            None,
            None,
            Vec::new(),
            None,
            None,
            None,
        );
        save_credentials(&metadata_store, &[credential]).expect("metadata should save");

        let state = refresh_provider_with_stores(
            &metadata_store,
            &secret_vault,
            "tavily",
            "manual",
            fixed_now,
        )
        .expect("refresh should return updated diagnostics");

        let failed = &state.credentials[0];
        assert_eq!(failed.status, CredentialStatus::Failed);
        assert_eq!(failed.remaining_badge_text, "Check failed");
        assert_eq!(
            failed.last_updated.as_deref(),
            Some("2026-06-11T12:40:00+08:00")
        );
        assert_eq!(
            failed.diagnostic_message.as_deref(),
            Some("Credential value was not found")
        );
    }

    #[test]
    fn automatic_refresh_skips_costly_provider_credentials() {
        let metadata_store = MemoryMetadataStore::default();
        let secret_vault = MemorySecretVault::default();
        let credential = CredentialView::api_key(
            "brave-test",
            "brave",
            "Brave Test",
            "BSA••••test",
            CredentialStatus::NotChecked,
            "Saved",
            None,
            None,
            Vec::new(),
            None,
            None,
            None,
        );
        save_credentials(&metadata_store, &[credential]).expect("metadata should save");
        save_secret(&secret_vault, "brave-test", "BSA-fixture").expect("secret should save");

        let state = refresh_provider_with_stores(
            &metadata_store,
            &secret_vault,
            "brave",
            "automatic",
            fixed_now,
        )
        .expect("automatic refresh should not fail");

        let skipped = &state.credentials[0];
        assert_eq!(skipped.status, CredentialStatus::NotChecked);
        assert_eq!(skipped.remaining_badge_text, "Saved");
        assert_eq!(skipped.last_updated, None);
    }

    #[test]
    fn costly_automatic_refresh_updates_costly_provider_credentials() {
        let metadata_store = MemoryMetadataStore::default();
        let secret_vault = MemorySecretVault::default();
        let credential = CredentialView::api_key(
            "brave-test",
            "brave",
            "Brave Test",
            "BSA••••test",
            CredentialStatus::NotChecked,
            "Saved",
            None,
            None,
            Vec::new(),
            None,
            None,
            None,
        );
        save_credentials(&metadata_store, &[credential]).expect("metadata should save");
        save_secret(&secret_vault, "brave-test", "BSA-fixture").expect("secret should save");

        let state = refresh_provider_with_stores(
            &metadata_store,
            &secret_vault,
            "brave",
            "costlyAutomatic",
            fixed_now,
        )
        .expect("costly automatic refresh should run when explicit");

        let refreshed = &state.credentials[0];
        assert_eq!(refreshed.status, CredentialStatus::Healthy);
        assert_eq!(refreshed.remaining_badge_text, "742 / 1000");
        assert_eq!(
            refreshed.last_updated.as_deref(),
            Some("2026-06-11T12:40:00+08:00")
        );
    }
}
