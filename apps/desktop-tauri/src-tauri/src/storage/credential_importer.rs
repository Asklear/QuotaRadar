use std::{fs, io::ErrorKind, path::Path};

use serde::Deserialize;
use serde::Serialize;

use crate::domain::{CredentialKind, CredentialView};

use super::{
    metadata_store::{load_credentials, save_credentials, MetadataStore},
    secret_store::{build_credential_metadata, save_secret, CredentialSecretInput, SecretVault},
};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ImportedCredentialSource {
    EnvFile,
    ClaudeSettings,
}

impl ImportedCredentialSource {
    fn note(self) -> &'static str {
        match self {
            Self::EnvFile => "Imported from .env",
            Self::ClaudeSettings => "Imported from ~/.claude/settings.json",
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct ImportedCredential {
    pub provider_id: String,
    pub name: String,
    pub kind: CredentialKind,
    pub secret: String,
    pub note: Option<String>,
}

#[derive(Debug, Clone, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct CredentialImportSummary {
    pub added: usize,
    pub updated: usize,
    pub credentials: Vec<CredentialView>,
}

#[derive(Debug, Deserialize)]
struct ClaudeSettings {
    env: Option<serde_json::Map<String, serde_json::Value>>,
}

pub fn import_claude_settings_content(content: &str) -> Result<Vec<ImportedCredential>, String> {
    let settings = serde_json::from_str::<ClaudeSettings>(content)
        .map_err(|error| format!("Could not parse Claude settings: {error}"))?;
    let env = settings
        .env
        .unwrap_or_default()
        .into_iter()
        .filter_map(|(key, value)| value.as_str().map(|value| (key, value.to_string())));

    Ok(parse_environment(
        env,
        ImportedCredentialSource::ClaudeSettings,
    ))
}

pub fn import_claude_settings_file(
    metadata_store: &impl MetadataStore,
    secret_vault: &impl SecretVault,
    settings_path: &Path,
) -> Result<CredentialImportSummary, String> {
    let content = match fs::read_to_string(settings_path) {
        Ok(content) => content,
        Err(error) if error.kind() == ErrorKind::NotFound => {
            return import_credentials_into_store(metadata_store, secret_vault, Vec::new());
        }
        Err(error) => {
            return Err(format!(
                "Could not read Claude settings file {}: {error}",
                settings_path.display()
            ));
        }
    };
    let imported = import_claude_settings_content(&content)?;

    import_credentials_into_store(metadata_store, secret_vault, imported)
}

pub fn parse_env_content(
    content: &str,
    source: ImportedCredentialSource,
) -> Vec<ImportedCredential> {
    parse_environment(content.lines().filter_map(parse_env_line), source)
}

pub fn import_credentials_into_store(
    metadata_store: &impl MetadataStore,
    secret_vault: &impl SecretVault,
    imported_credentials: Vec<ImportedCredential>,
) -> Result<CredentialImportSummary, String> {
    let mut credentials = load_credentials(metadata_store)?;
    let mut added = 0;
    let mut updated = 0;

    for imported in imported_credentials {
        let existing_index = credentials.iter().position(|credential| {
            credential.provider_id == imported.provider_id && credential.name == imported.name
        });
        let id = existing_index
            .and_then(|index| {
                credentials
                    .get(index)
                    .map(|credential| credential.id.clone())
            })
            .unwrap_or_else(|| next_imported_credential_id(&credentials, &imported));
        let linked_authorization_id = existing_index
            .and_then(|index| credentials.get(index))
            .and_then(|credential| credential.linked_authorization_id.clone());
        let input = CredentialSecretInput {
            id,
            provider_id: imported.provider_id,
            name: imported.name,
            kind: imported.kind,
            secret: imported.secret,
            linked_authorization_id,
            note: imported.note,
        };
        let metadata = build_credential_metadata(&input);

        save_secret(secret_vault, &metadata.id, &input.secret)?;
        if let Some(index) = existing_index {
            credentials[index] = metadata;
            updated += 1;
        } else {
            credentials.push(metadata);
            added += 1;
        }
    }

    if added > 0 || updated > 0 {
        save_credentials(metadata_store, &credentials)?;
    }

    Ok(CredentialImportSummary {
        added,
        updated,
        credentials,
    })
}

fn parse_environment(
    entries: impl IntoIterator<Item = (String, String)>,
    source: ImportedCredentialSource,
) -> Vec<ImportedCredential> {
    let mut credentials = entries
        .into_iter()
        .filter_map(|(name, value)| imported_credential_from_env_value(&name, &value, source))
        .collect::<Vec<_>>();
    credentials.sort_by(|left, right| {
        left.provider_id
            .cmp(&right.provider_id)
            .then_with(|| left.name.cmp(&right.name))
    });
    credentials
}

fn parse_env_line(line: &str) -> Option<(String, String)> {
    let mut line = line.trim();
    if line.is_empty() || line.starts_with('#') {
        return None;
    }
    if let Some(rest) = line.strip_prefix("export ") {
        line = rest.trim_start();
    }

    let (name, value) = line.split_once('=')?;
    Some((name.trim().to_string(), clean_env_value(value)))
}

fn imported_credential_from_env_value(
    name: &str,
    value: &str,
    source: ImportedCredentialSource,
) -> Option<ImportedCredential> {
    let secret = clean_env_value(value);
    if secret.is_empty() || secret == "xxx" {
        return None;
    }
    let (provider_id, kind) = detect_importable_credential(name)?;
    Some(ImportedCredential {
        provider_id: provider_id.to_string(),
        name: name.trim().to_string(),
        kind,
        secret,
        note: Some(source.note().to_string()),
    })
}

fn next_imported_credential_id(
    credentials: &[CredentialView],
    imported: &ImportedCredential,
) -> String {
    let base = format!(
        "imported-{}-{}",
        imported.provider_id,
        slugify_credential_name(&imported.name)
    );
    if !credentials.iter().any(|credential| credential.id == base) {
        return base;
    }

    for suffix in 2.. {
        let candidate = format!("{base}-{suffix}");
        if !credentials
            .iter()
            .any(|credential| credential.id == candidate)
        {
            return candidate;
        }
    }

    unreachable!("unbounded suffix loop should always return")
}

fn slugify_credential_name(name: &str) -> String {
    let slug = name
        .chars()
        .map(|character| {
            if character.is_ascii_alphanumeric() {
                character.to_ascii_lowercase()
            } else {
                '-'
            }
        })
        .collect::<String>()
        .split('-')
        .filter(|part| !part.is_empty())
        .collect::<Vec<_>>()
        .join("-");

    if slug.is_empty() {
        "credential".to_string()
    } else {
        slug
    }
}

fn clean_env_value(value: &str) -> String {
    value
        .trim()
        .trim_matches('"')
        .trim_matches('\'')
        .trim()
        .to_string()
}

fn detect_importable_credential(name: &str) -> Option<(&'static str, CredentialKind)> {
    let uppercased = name.to_ascii_uppercase();

    if uppercased.contains("TAVILY") {
        return Some(("tavily", CredentialKind::ApiKey));
    }
    if uppercased.contains("BRAVE") {
        return Some(("brave", CredentialKind::ApiKey));
    }
    if uppercased.contains("SERPAPI") {
        return Some(("serpapi", CredentialKind::ApiKey));
    }
    if uppercased.contains("SERPER") {
        return Some(("serper", CredentialKind::ApiKey));
    }
    if uppercased.contains("EXA") {
        return Some(("exa", CredentialKind::AdminCredential));
    }
    if uppercased.contains("BOCHA") {
        return Some(("bocha", CredentialKind::ApiKey));
    }
    if uppercased.contains("ANYSEARCH") {
        return Some(("anysearch", CredentialKind::ApiKey));
    }
    if (uppercased.contains("WX") && uppercased.contains("SEARCH")) || uppercased.contains("WECHAT")
    {
        return Some(("wxmp", CredentialKind::ApiKey));
    }
    if uppercased.contains("QUERIT") {
        if contains_any(&uppercased, &["COOKIE", "SESSION"]) {
            return Some(("querit", CredentialKind::DashboardCookie));
        }
        if contains_any(&uppercased, &["API_KEY", "KEY"]) {
            return Some(("querit", CredentialKind::StoredApiKeyOnly));
        }
    }
    if uppercased.contains("DEEPSEEK")
        && uppercased.contains("API_KEY")
        && !uppercased.contains("WEB_SEARCH_PRO")
    {
        return Some(("deepseek", CredentialKind::ApiKey));
    }
    if uppercased.contains("ANTHROPIC")
        && uppercased.contains("API_KEY")
        && !uppercased.contains("AUTH_TOKEN")
    {
        return Some(("claude", CredentialKind::StoredApiKeyOnly));
    }
    if (uppercased.contains("OPENAI") || uppercased.contains("CODEX"))
        && uppercased.contains("API_KEY")
        && !contains_any(&uppercased, &["SESSION", "COOKIE"])
    {
        return Some(("codex", CredentialKind::StoredApiKeyOnly));
    }
    if uppercased.contains("KIMI") {
        if uppercased.contains("API_KEY") {
            return Some(("kimi", CredentialKind::StoredApiKeyOnly));
        }
        if contains_any(&uppercased, &["COOKIE", "SESSION", "AUTH", "ACCESS_TOKEN"]) {
            return Some(("kimi", CredentialKind::DashboardCookie));
        }
    }
    if uppercased.contains("OPENCODE")
        && (uppercased.contains("GO") || contains_any(&uppercased, &["COOKIE", "SESSION"]))
    {
        if uppercased.contains("API_KEY") {
            return Some(("opencode_go", CredentialKind::StoredApiKeyOnly));
        }
        return Some(("opencode_go", CredentialKind::DashboardCookie));
    }
    if contains_any(&uppercased, &["XFYUN", "IFLYTEK", "SPARK"])
        && contains_any(
            &uppercased,
            &["CODING", "COOKIE", "SESSION", "API_KEY", "KEY"],
        )
    {
        if uppercased.contains("API_KEY") || uppercased.ends_with("_KEY") {
            return Some(("xfyun_coding_plan", CredentialKind::StoredApiKeyOnly));
        }
        return Some(("xfyun_coding_plan", CredentialKind::DashboardCookie));
    }
    if contains_any(&uppercased, &["VOLCENGINE", "VOLC", "ARK"])
        && contains_any(
            &uppercased,
            &["CODING", "COOKIE", "SESSION", "API_KEY", "KEY"],
        )
    {
        if uppercased.contains("API_KEY") || uppercased.ends_with("_KEY") {
            return Some(("volcengine_coding_plan", CredentialKind::StoredApiKeyOnly));
        }
        return Some(("volcengine_coding_plan", CredentialKind::DashboardCookie));
    }
    if uppercased.contains("ALIYUN")
        && uppercased.contains("CODING")
        && contains_any(&uppercased, &["API_KEY", "KEY", "COOKIE", "SESSION"])
    {
        if uppercased.contains("API_KEY") || uppercased.ends_with("_KEY") {
            return Some(("aliyun_coding_plan", CredentialKind::StoredApiKeyOnly));
        }
        return Some(("aliyun_coding_plan", CredentialKind::DashboardCookie));
    }
    if uppercased.contains("TENCENT")
        && uppercased.contains("CODING")
        && contains_any(&uppercased, &["API_KEY", "KEY", "COOKIE", "SESSION"])
    {
        if uppercased.contains("API_KEY") || uppercased.ends_with("_KEY") {
            return Some((
                "tencent_cloud_coding_plan",
                CredentialKind::StoredApiKeyOnly,
            ));
        }
        return Some(("tencent_cloud_coding_plan", CredentialKind::DashboardCookie));
    }

    None
}

fn contains_any(value: &str, needles: &[&str]) -> bool {
    needles.iter().any(|needle| value.contains(needle))
}
