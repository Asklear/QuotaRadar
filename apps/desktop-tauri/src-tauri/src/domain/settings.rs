use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "kebab-case")]
pub enum RefreshInterval {
    #[serde(rename = "off")]
    Off,
    #[serde(rename = "30m")]
    ThirtyMinutes,
    #[serde(rename = "1h")]
    OneHour,
    #[serde(rename = "6h")]
    SixHours,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub enum ProxyMode {
    System,
    Direct,
    Custom,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ProxySettings {
    pub mode: ProxyMode,
    pub custom_url: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct AppSettings {
    pub language: String,
    pub launch_at_login: bool,
    pub update_check: bool,
    pub auto_refresh_interval: RefreshInterval,
    pub costly_refresh_interval: RefreshInterval,
    pub proxy: ProxySettings,
    pub tray_transparency: u8,
    pub provider_order: Vec<String>,
}

impl Default for AppSettings {
    fn default() -> Self {
        Self {
            language: "en".to_string(),
            launch_at_login: true,
            update_check: true,
            auto_refresh_interval: RefreshInterval::Off,
            costly_refresh_interval: RefreshInterval::Off,
            proxy: ProxySettings {
                mode: ProxyMode::System,
                custom_url: None,
            },
            tray_transparency: 82,
            provider_order: default_provider_order(),
        }
    }
}

pub fn default_provider_order() -> Vec<String> {
    [
        "tavily",
        "brave",
        "serpapi",
        "serper",
        "exa",
        "bocha",
        "anysearch",
        "wxmp",
        "querit",
        "deepseek",
        "claude",
        "codex",
        "kimi",
        "opencode_go",
        "xfyun_coding_plan",
        "volcengine_coding_plan",
        "aliyun_coding_plan",
        "tencent_cloud_coding_plan",
    ]
    .into_iter()
    .map(ToString::to_string)
    .collect()
}
