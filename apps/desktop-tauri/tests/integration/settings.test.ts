import { invoke } from "@tauri-apps/api/core";
import { afterEach, describe, expect, it, vi } from "vitest";
import {
  getSettings,
  mockSettings,
  moveProvider,
  resetProviderOrder,
  updateSettings,
} from "../../src/lib/tauriClient";
import type { AppSettings } from "../../src/shared/types";

vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn(),
}));

function setTauriRuntime(enabled: boolean) {
  if (enabled) {
    Object.defineProperty(window, "__TAURI_INTERNALS__", {
      value: {},
      configurable: true,
    });
    return;
  }

  Reflect.deleteProperty(window, "__TAURI_INTERNALS__");
}

describe("settings commands", () => {
  afterEach(() => {
    vi.mocked(invoke).mockReset();
    setTauriRuntime(false);
  });

  it("loads settings from Tauri in desktop runtime", async () => {
    setTauriRuntime(true);
    vi.mocked(invoke).mockResolvedValue(mockSettings);

    const settings = await getSettings();

    expect(invoke).toHaveBeenCalledWith("get_settings");
    expect(settings.providerOrder[0]).toBe("tavily");
  });

  it("updates full settings through the Tauri command", async () => {
    setTauriRuntime(true);
    const nextSettings: AppSettings = {
      ...mockSettings,
      language: "zh-Hans",
      proxy: { mode: "custom", customUrl: "socks5://127.0.0.1:7890" },
      autoRefreshInterval: "1h",
      costlyRefreshInterval: "6h",
    };
    vi.mocked(invoke).mockResolvedValue(nextSettings);

    const settings = await updateSettings(nextSettings);

    expect(invoke).toHaveBeenCalledWith("update_settings", { settings: nextSettings });
    expect(settings.proxy.mode).toBe("custom");
  });

  it("moves and resets provider order through dedicated commands", async () => {
    setTauriRuntime(true);
    vi.mocked(invoke)
      .mockResolvedValueOnce({ ...mockSettings, providerOrder: ["kimi", "tavily"] })
      .mockResolvedValueOnce(mockSettings);

    await moveProvider("kimi", 0);
    await resetProviderOrder();

    expect(invoke).toHaveBeenNthCalledWith(1, "move_provider", { providerId: "kimi", toIndex: 0 });
    expect(invoke).toHaveBeenNthCalledWith(2, "reset_provider_order");
  });

  it("falls back to mock settings outside Tauri runtime", async () => {
    const settings = await getSettings();

    expect(invoke).not.toHaveBeenCalled();
    expect(settings).toEqual(mockSettings);
  });
});
