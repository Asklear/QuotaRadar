import { describe, expect, it } from "vitest";

import cargoToml from "../../src-tauri/Cargo.toml?raw";
import authRs from "../../src-tauri/src/commands/auth.rs?raw";
import libRs from "../../src-tauri/src/lib.rs?raw";
import webAuthRs from "../../src-tauri/src/platform/web_auth.rs?raw";

describe("desktop runtime source guards", () => {
  it("registers single-instance before other Tauri plugins and reopens the main window", () => {
    expect(cargoToml).toContain("tauri-plugin-single-instance");
    expect(libRs).toContain("tauri_plugin_single_instance::init");
    expect(libRs).toContain("platform::window::reopen_main_window");

    const singleInstanceIndex = libRs.indexOf("tauri_plugin_single_instance::init");
    const firstOtherPluginIndex = libRs.indexOf(".plugin(tauri_plugin_http::init())");

    expect(singleInstanceIndex).toBeGreaterThanOrEqual(0);
    expect(firstOtherPluginIndex).toBeGreaterThanOrEqual(0);
    expect(singleInstanceIndex).toBeLessThan(firstOtherPluginIndex);
  });

  it("keeps web authorization inside a capturable Tauri webview", () => {
    expect(webAuthRs).toContain("WebviewWindowBuilder::new");
    expect(webAuthRs).toContain("WebviewUrl::App");
    expect(webAuthRs).toContain("window.navigate(load_plan.navigation_url)");
    expect(webAuthRs).toContain("window.cookies()");
    expect(webAuthRs).toContain("save_web_authorization_with_stores");
  });

  it("returns web authorization window opening errors to the command caller", () => {
    expect(authRs).toContain("start_web_authorization_from_credentials");
    expect(authRs).toContain("open_web_authorization_window(&app, request)");
    expect(authRs).not.toContain("spawn_web_authorization_window");
    expect(webAuthRs).not.toContain("app.run_on_main_thread(move ||");
  });
});
