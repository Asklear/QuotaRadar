import { invoke } from "@tauri-apps/api/core";
import { afterEach, describe, expect, it, vi } from "vitest";
import { getAppState, openExternalUrl, saveWebAuthorization } from "../../src/lib/tauriClient";

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

  it("saves captured web authorization through Tauri in desktop runtime", async () => {
    setTauriRuntime(true);
    vi.mocked(invoke).mockResolvedValue({
      id: "claude-web-pro",
      providerId: "claude",
      name: "Claude Pro Login",
      kind: "dashboardCookie",
      maskedValue: "Web login authorization saved",
      copyable: false,
      active: true,
      status: "notChecked",
      remainingBadgeText: "Authorization saved",
      quotaWindows: [],
    });

    const credential = await saveWebAuthorization({
      providerId: "claude",
      targetCredentialId: "claude-web-pro",
      name: "Claude Pro Login",
      capturedFields: { cookie: "sessionKey=mock-session" },
    });

    expect(invoke).toHaveBeenCalledWith("save_web_authorization", {
      input: {
        providerId: "claude",
        targetCredentialId: "claude-web-pro",
        name: "Claude Pro Login",
        capturedFields: { cookie: "sessionKey=mock-session" },
      },
    });
    expect(credential.copyable).toBe(false);
  });

  it("opens external URLs through Tauri in desktop runtime", async () => {
    setTauriRuntime(true);
    vi.mocked(invoke).mockResolvedValue(undefined);

    await openExternalUrl("https://chatgpt.com");

    expect(invoke).toHaveBeenCalledWith("open_external_url", { url: "https://chatgpt.com" });
  });
});
