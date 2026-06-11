use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct QuotaWindow {
    pub name: String,
    pub percent_remaining: Option<f64>,
    pub remaining_text: Option<String>,
    pub reset_at: Option<String>,
}

impl QuotaWindow {
    pub fn percent(name: &str, percent_remaining: f64, reset_at: &str) -> Self {
        Self {
            name: name.to_string(),
            percent_remaining: Some(percent_remaining),
            remaining_text: None,
            reset_at: Some(reset_at.to_string()),
        }
    }
}
