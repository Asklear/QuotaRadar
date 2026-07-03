pub mod app_state;
pub mod auth;
pub mod credentials;
pub mod external;
pub mod providers;
pub mod settings;
pub mod updates;
pub mod window;

#[cfg(test)]
mod auth_tests;
#[cfg(all(test, not(target_os = "windows")))]
mod credentials_tests;
