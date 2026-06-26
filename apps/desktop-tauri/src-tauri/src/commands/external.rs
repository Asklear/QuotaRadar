use std::process::{Command, Stdio};

#[tauri::command]
pub fn open_external_url(url: String) -> Result<(), String> {
    let url = normalize_external_url(&url)?;
    let mut command = external_url_command(url);
    command
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null());

    command
        .spawn()
        .map(|_| ())
        .map_err(|error| format!("failed to open external URL: {error}"))
}

fn normalize_external_url(url: &str) -> Result<&str, String> {
    let trimmed = url.trim();
    if trimmed.is_empty() {
        return Err("external URL is empty".to_string());
    }
    if trimmed.chars().any(char::is_whitespace) {
        return Err("external URL contains whitespace".to_string());
    }

    let lower = trimmed.to_ascii_lowercase();
    if lower.starts_with("https://") || lower.starts_with("http://") {
        return Ok(trimmed);
    }

    Err("external URL must use http or https".to_string())
}

fn external_url_command(url: &str) -> Command {
    let (program, args) = external_url_command_spec(url);
    let mut command = Command::new(program);
    command.args(args);
    command
}

#[cfg(target_os = "windows")]
fn external_url_command_spec(url: &str) -> (&'static str, Vec<String>) {
    (
        "rundll32.exe",
        vec!["url.dll,FileProtocolHandler".to_string(), url.to_string()],
    )
}

#[cfg(target_os = "macos")]
fn external_url_command_spec(url: &str) -> (&'static str, Vec<String>) {
    ("open", vec![url.to_string()])
}

#[cfg(all(unix, not(target_os = "macos")))]
fn external_url_command_spec(url: &str) -> (&'static str, Vec<String>) {
    ("xdg-open", vec![url.to_string()])
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn external_url_accepts_http_and_https() {
        assert_eq!(
            normalize_external_url(" https://chatgpt.com ").unwrap(),
            "https://chatgpt.com"
        );
        assert_eq!(
            normalize_external_url("http://localhost:1420").unwrap(),
            "http://localhost:1420"
        );
    }

    #[test]
    fn external_url_rejects_non_web_schemes() {
        assert!(normalize_external_url("file:///tmp/token.txt").is_err());
        assert!(normalize_external_url("javascript:alert(1)").is_err());
    }

    #[test]
    fn external_url_rejects_blank_relative_and_whitespace_urls() {
        assert!(normalize_external_url("").is_err());
        assert!(normalize_external_url("/settings").is_err());
        assert!(normalize_external_url("https://chatgpt.com/a path").is_err());
    }

    #[cfg(target_os = "windows")]
    #[test]
    fn windows_external_url_uses_file_protocol_handler_without_cmd_shell() {
        let (program, args) = external_url_command_spec("https://chatgpt.com");

        assert_eq!(program, "rundll32.exe");
        assert_eq!(
            args,
            vec![
                "url.dll,FileProtocolHandler".to_string(),
                "https://chatgpt.com".to_string()
            ]
        );
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn macos_external_url_uses_open() {
        let (program, args) = external_url_command_spec("https://chatgpt.com");

        assert_eq!(program, "open");
        assert_eq!(args, vec!["https://chatgpt.com".to_string()]);
    }

    #[cfg(all(unix, not(target_os = "macos")))]
    #[test]
    fn linux_external_url_uses_xdg_open() {
        let (program, args) = external_url_command_spec("https://chatgpt.com");

        assert_eq!(program, "xdg-open");
        assert_eq!(args, vec!["https://chatgpt.com".to_string()]);
    }
}
