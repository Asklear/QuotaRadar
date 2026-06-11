use super::{ProviderClient, ProviderCredential, ProviderError, QuotaSnapshot};

#[derive(Debug, Default)]
pub struct AnySearchProvider;

impl ProviderClient for AnySearchProvider {
    fn provider_id(&self) -> &'static str {
        "anysearch"
    }

    fn consumes_quota_on_check(&self) -> bool {
        false
    }

    fn check_fixture_quota(
        &self,
        credential: ProviderCredential,
    ) -> Result<QuotaSnapshot, ProviderError> {
        if credential.provider_id != self.provider_id() {
            return Err(ProviderError::Unsupported(format!(
                "credential belongs to {}",
                credential.provider_id
            )));
        }

        Ok(QuotaSnapshot {
            provider_id: "anysearch".to_string(),
            remaining: None,
            limit: None,
            remaining_badge_text: "Unlimited".to_string(),
            quota_label: Some("free usage".to_string()),
            quota_windows: vec![],
            reset_at: None,
            plan_ends_at: None,
        })
    }
}
