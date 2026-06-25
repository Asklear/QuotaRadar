use std::{fs, path::Path, path::PathBuf};

use serde_json::{Map, Value as JsonValue};

use super::{
    metadata_store::MetadataStore,
    migration::{migrate_swift_configuration, MigrationSummary, SwiftMigrationInput},
    secret_store::SecretVault,
};

pub const SWIFT_MIGRATION_COMPLETED_KEY: &str = "swiftConfigurationMigrationCompleted";

#[derive(Debug, Clone)]
pub struct SwiftMigrationFilePaths {
    pub quota_radar_preferences: PathBuf,
    pub quota_bar_preferences: PathBuf,
    pub quota_radar_secrets: PathBuf,
    pub quota_bar_secrets: PathBuf,
}

impl SwiftMigrationFilePaths {
    pub fn for_home(home_dir: impl Into<PathBuf>) -> Self {
        let home_dir = home_dir.into();
        Self {
            quota_radar_preferences: home_dir
                .join("Library")
                .join("Preferences")
                .join("com.gaorongvc.quotaradar.plist"),
            quota_bar_preferences: home_dir
                .join("Library")
                .join("Preferences")
                .join("com.gaorongvc.quotabar.plist"),
            quota_radar_secrets: home_dir
                .join("Library")
                .join("Application Support")
                .join("QuotaRadar")
                .join("secrets.json"),
            quota_bar_secrets: home_dir
                .join("Library")
                .join("Application Support")
                .join("QuotaBar")
                .join("secrets.json"),
        }
    }
}

pub fn migrate_swift_configuration_from_paths(
    metadata_store: &impl MetadataStore,
    secret_vault: &impl SecretVault,
    paths: &SwiftMigrationFilePaths,
) -> Result<MigrationSummary, String> {
    let migration_completed = metadata_store
        .get_value(SWIFT_MIGRATION_COMPLETED_KEY)
        .and_then(|value| value.as_bool())
        == Some(true);

    let quota_radar_preferences = read_plist(&paths.quota_radar_preferences)?;
    let quota_bar_preferences = read_plist(&paths.quota_bar_preferences)?;
    let quota_radar_defaults_json = if migration_completed {
        None
    } else {
        quota_radar_preferences
            .as_ref()
            .and_then(defaults_json_from_plist)
    };
    let quota_bar_defaults_json = if migration_completed {
        None
    } else {
        quota_bar_preferences
            .as_ref()
            .and_then(defaults_json_from_plist)
    };
    let quota_radar_metadata_json = quota_radar_preferences
        .as_ref()
        .and_then(|plist| data_string_from_plist(plist, "apiKeyMetadata"));
    let quota_bar_metadata_json = quota_bar_preferences
        .as_ref()
        .and_then(|plist| data_string_from_plist(plist, "apiKeyMetadata"));
    let quota_radar_secrets_json = read_text_file(&paths.quota_radar_secrets)?;
    let quota_bar_secrets_json = read_text_file(&paths.quota_bar_secrets)?;
    let metadata_cleared_by_user = quota_radar_preferences
        .as_ref()
        .and_then(|plist| bool_from_plist(plist, "apiKeyMetadataClearedByUser"))
        .unwrap_or(false);
    let legacy_migration_already_completed = quota_radar_preferences
        .as_ref()
        .and_then(|plist| bool_from_plist(plist, "didMigrateQuotaBarDefaultsToQuotaRadar"))
        .unwrap_or(false);

    let summary = migrate_swift_configuration(
        metadata_store,
        secret_vault,
        SwiftMigrationInput {
            quota_radar_defaults_json: quota_radar_defaults_json.as_deref(),
            quota_bar_defaults_json: quota_bar_defaults_json.as_deref(),
            quota_radar_metadata_json: quota_radar_metadata_json.as_deref(),
            quota_bar_metadata_json: quota_bar_metadata_json.as_deref(),
            quota_radar_secrets_json: quota_radar_secrets_json.as_deref(),
            quota_bar_secrets_json: quota_bar_secrets_json.as_deref(),
            metadata_cleared_by_user,
            legacy_migration_already_completed,
        },
    )?;

    metadata_store.set_value(SWIFT_MIGRATION_COMPLETED_KEY, JsonValue::Bool(true));
    metadata_store.save()?;
    Ok(summary)
}

fn read_plist(path: &Path) -> Result<Option<plist::Value>, String> {
    if !path.exists() {
        return Ok(None);
    }

    plist::Value::from_file(path).map(Some).map_err(|error| {
        format!(
            "Could not read Swift preferences plist {}: {error}",
            path.display()
        )
    })
}

fn read_text_file(path: &Path) -> Result<Option<String>, String> {
    if !path.exists() {
        return Ok(None);
    }

    let text = fs::read_to_string(path).map_err(|error| {
        format!(
            "Could not read Swift secrets file {}: {error}",
            path.display()
        )
    })?;
    if text.trim().is_empty() {
        Ok(None)
    } else {
        Ok(Some(text))
    }
}

fn defaults_json_from_plist(plist: &plist::Value) -> Option<String> {
    let dictionary = plist.as_dictionary()?;
    let mut object = Map::new();
    copy_string(dictionary, &mut object, "appLanguage");
    copy_number(dictionary, &mut object, "statusBarTransparency");
    copy_string(dictionary, &mut object, "autoRefreshInterval");
    copy_string(dictionary, &mut object, "quotaConsumingAutoRefreshInterval");
    copy_string(dictionary, &mut object, "networkProxyMode");
    copy_string(dictionary, &mut object, "customProxyURL");
    copy_bool(dictionary, &mut object, "automaticallyCheckForUpdates");
    copy_bool(dictionary, &mut object, "customProviderOrderEnabled");
    copy_string_array(dictionary, &mut object, "providerOrder");

    if object.is_empty() {
        None
    } else {
        Some(JsonValue::Object(object).to_string())
    }
}

fn data_string_from_plist(plist: &plist::Value, key: &str) -> Option<String> {
    let value = plist.as_dictionary()?.get(key)?;
    match value {
        plist::Value::Data(data) => String::from_utf8(data.clone()).ok(),
        plist::Value::String(text) => Some(text.clone()),
        _ => None,
    }
}

fn bool_from_plist(plist: &plist::Value, key: &str) -> Option<bool> {
    plist.as_dictionary()?.get(key)?.as_boolean()
}

fn copy_string(dictionary: &plist::Dictionary, object: &mut Map<String, JsonValue>, key: &str) {
    if let Some(value) = dictionary.get(key).and_then(plist::Value::as_string) {
        object.insert(key.to_string(), JsonValue::String(value.to_string()));
    }
}

fn copy_number(dictionary: &plist::Dictionary, object: &mut Map<String, JsonValue>, key: &str) {
    if let Some(value) = dictionary.get(key).and_then(number_from_plist) {
        object.insert(key.to_string(), JsonValue::from(value));
    }
}

fn copy_bool(dictionary: &plist::Dictionary, object: &mut Map<String, JsonValue>, key: &str) {
    if let Some(value) = dictionary.get(key).and_then(plist::Value::as_boolean) {
        object.insert(key.to_string(), JsonValue::Bool(value));
    }
}

fn copy_string_array(
    dictionary: &plist::Dictionary,
    object: &mut Map<String, JsonValue>,
    key: &str,
) {
    let Some(values) = dictionary.get(key).and_then(plist::Value::as_array) else {
        return;
    };
    let strings = values
        .iter()
        .filter_map(plist::Value::as_string)
        .map(|value| JsonValue::String(value.to_string()))
        .collect::<Vec<_>>();
    object.insert(key.to_string(), JsonValue::Array(strings));
}

fn number_from_plist(value: &plist::Value) -> Option<f64> {
    match value {
        plist::Value::Real(value) => Some(*value),
        plist::Value::Integer(value) => value.as_signed().map(|value| value as f64),
        _ => None,
    }
}
