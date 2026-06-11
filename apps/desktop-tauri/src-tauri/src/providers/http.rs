use std::time::Duration;

use crate::domain::{ProxyMode, ProxySettings};

use super::ProviderError;

#[derive(Debug, Clone, PartialEq)]
pub struct ProviderHttpRequest {
    pub method: String,
    pub url: String,
    pub headers: Vec<(String, String)>,
    pub body: Option<String>,
}

impl ProviderHttpRequest {
    pub fn get(url: &str) -> Self {
        Self {
            method: "GET".to_string(),
            url: url.to_string(),
            headers: Vec::new(),
            body: None,
        }
    }

    pub fn post(url: &str) -> Self {
        Self {
            method: "POST".to_string(),
            url: url.to_string(),
            headers: Vec::new(),
            body: None,
        }
    }

    pub fn header(mut self, name: &str, value: &str) -> Self {
        self.headers.push((name.to_string(), value.to_string()));
        self
    }

    pub fn body(mut self, body: &str) -> Self {
        self.body = Some(body.to_string());
        self
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct ProviderHttpResponse {
    pub status: u16,
    pub body: String,
}

pub trait ProviderTransport: Send + Sync {
    fn send(&self, request: ProviderHttpRequest) -> Result<ProviderHttpResponse, ProviderError>;
}

pub struct ReqwestProviderTransport {
    client: reqwest::blocking::Client,
}

impl ReqwestProviderTransport {
    pub fn from_proxy_settings(settings: &ProxySettings) -> Result<Self, ProviderError> {
        let mut builder = reqwest::blocking::Client::builder().timeout(Duration::from_secs(30));
        match settings.mode {
            ProxyMode::System => {}
            ProxyMode::Direct => {
                builder = builder.no_proxy();
            }
            ProxyMode::Custom => {
                if let Some(url) = settings
                    .custom_url
                    .as_deref()
                    .filter(|url| !url.trim().is_empty())
                {
                    let proxy = reqwest::Proxy::all(url.trim())
                        .map_err(|error| ProviderError::Network(error.to_string()))?;
                    builder = builder.proxy(proxy);
                }
            }
        }

        let client = builder
            .build()
            .map_err(|error| ProviderError::Network(error.to_string()))?;
        Ok(Self { client })
    }
}

impl ProviderTransport for ReqwestProviderTransport {
    fn send(&self, request: ProviderHttpRequest) -> Result<ProviderHttpResponse, ProviderError> {
        let method = request
            .method
            .parse::<reqwest::Method>()
            .map_err(|error| ProviderError::Network(error.to_string()))?;
        let mut builder = self.client.request(method, request.url);
        for (name, value) in request.headers {
            builder = builder.header(name, value);
        }
        if let Some(body) = request.body {
            builder = builder.body(body);
        }

        let response = builder
            .send()
            .map_err(|error| ProviderError::Network(error.to_string()))?;
        let status = response.status().as_u16();
        let body = response
            .text()
            .map_err(|error| ProviderError::Network(error.to_string()))?;
        Ok(ProviderHttpResponse { status, body })
    }
}

#[cfg(test)]
#[derive(Default)]
pub struct MockProviderTransport {
    response: std::sync::Mutex<Option<Result<ProviderHttpResponse, ProviderError>>>,
    requests: std::sync::Mutex<Vec<ProviderHttpRequest>>,
}

#[cfg(test)]
impl MockProviderTransport {
    pub fn responding(response: ProviderHttpResponse) -> Self {
        Self {
            response: std::sync::Mutex::new(Some(Ok(response))),
            requests: std::sync::Mutex::new(Vec::new()),
        }
    }

    pub fn requests(&self) -> Vec<ProviderHttpRequest> {
        self.requests.lock().expect("requests lock").clone()
    }
}

#[cfg(test)]
impl ProviderTransport for MockProviderTransport {
    fn send(&self, request: ProviderHttpRequest) -> Result<ProviderHttpResponse, ProviderError> {
        self.requests.lock().expect("requests lock").push(request);
        self.response
            .lock()
            .expect("response lock")
            .take()
            .expect("mock response should be configured")
    }
}
