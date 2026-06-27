import { describe, expect, it } from "vitest";

import cargoToml from "../../src-tauri/Cargo.toml?raw";
import libRs from "../../src-tauri/src/lib.rs?raw";

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
});
