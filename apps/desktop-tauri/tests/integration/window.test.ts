import { invoke } from "@tauri-apps/api/core";
import { afterEach, describe, expect, it, vi } from "vitest";
import { openMainWindow } from "../../src/lib/tauriClient";

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

describe("window commands", () => {
  afterEach(() => {
    vi.mocked(invoke).mockReset();
    setTauriRuntime(false);
  });

  it("opens the main window with an optional navigation target", async () => {
    setTauriRuntime(true);
    vi.mocked(invoke).mockResolvedValue(undefined);

    await openMainWindow({ page: "settings" });

    expect(invoke).toHaveBeenCalledWith("open_main_window", {
      target: { page: "settings" },
    });
  });

  it("no-ops outside Tauri runtime", async () => {
    await openMainWindow({ page: "quota", providerId: "tavily" });

    expect(invoke).not.toHaveBeenCalled();
  });
});
