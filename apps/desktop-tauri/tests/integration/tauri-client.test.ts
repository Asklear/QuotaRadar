import { invoke } from "@tauri-apps/api/core";
import { afterEach, describe, expect, it, vi } from "vitest";
import { getAppState } from "../../src/lib/tauriClient";

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

describe("tauriClient", () => {
  afterEach(() => {
    vi.mocked(invoke).mockReset();
    setTauriRuntime(false);
  });

  it("loads typed app state from the Tauri command in desktop runtime", async () => {
    setTauriRuntime(true);
    vi.mocked(invoke).mockResolvedValue({
      providers: [
        {
          id: "tavily",
          displayName: "Tavily",
          familyName: "Tavily",
          category: "AI Search",
          icon: "tavily",
          supportsReauth: false,
          supportsRefresh: true,
          quotaCheckConsumesSearchQuota: false,
        },
      ],
      credentials: [],
    });

    const state = await getAppState();

    expect(invoke).toHaveBeenCalledWith("get_app_state");
    expect(state.providers[0].displayName).toBe("Tavily");
  });

  it("falls back to local mock state outside Tauri runtime", async () => {
    setTauriRuntime(false);

    const state = await getAppState();

    expect(invoke).not.toHaveBeenCalled();
    expect(state.providers.length).toBeGreaterThan(0);
    expect(state.credentials.length).toBeGreaterThan(0);
  });
});
