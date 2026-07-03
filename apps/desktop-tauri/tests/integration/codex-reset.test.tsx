import { invoke } from "@tauri-apps/api/core";
import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import App from "../../src/App";
import { mockSettings, mockUpdateState } from "../../src/lib/tauriClient";
import type { AppState, CredentialView, ProviderDefinition } from "../../src/shared/types";

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

const codexProvider: ProviderDefinition = {
  id: "codex",
  displayName: "Codex",
  familyName: "OpenAI",
  category: "LLM",
  planType: "Pro",
  icon: "codex",
  dashboardUrl: "https://chatgpt.com",
  supportsReauth: true,
  supportsRefresh: true,
  quotaCheckConsumesSearchQuota: false,
};

const codexCredential: CredentialView = {
  id: "codex-web-pro",
  providerId: "codex",
  name: "Codex Pro Login",
  kind: "dashboardCookie",
  maskedValue: "Web login saved",
  copyable: false,
  active: true,
  status: "healthy",
  remaining: 6000,
  limit: 10000,
  remainingBadgeText: "5h 80% · week 60%",
  quotaWindows: [],
  codexResetCreditsRemaining: 2,
  codexResetCreditsEarliestExpiresAt: "2026-07-18T00:38:14Z",
};

function appStateWith(credential: CredentialView): AppState {
  return {
    providers: [codexProvider],
    credentials: [credential],
  };
}

describe("Codex reset credits", () => {
  afterEach(() => {
    vi.mocked(invoke).mockReset();
    setTauriRuntime(false);
  });

  it("clicking the Codex reset action invokes Tauri and updates quota details", async () => {
    setTauriRuntime(true);
    const resetCredential: CredentialView = {
      ...codexCredential,
      remaining: 8000,
      remainingBadgeText: "5h 96% · week 80%",
      codexResetCreditsRemaining: 1,
      codexResetCreditsEarliestExpiresAt: "2026-07-26T23:56:41Z",
      lastUpdated: "2026-06-11T12:40:00+08:00",
      lastHttpStatus: 200,
    };
    vi.mocked(invoke).mockImplementation((command, args) => {
      if (command === "get_app_state") {
        return Promise.resolve(appStateWith(codexCredential));
      }
      if (command === "get_settings") {
        return Promise.resolve({
          ...mockSettings,
          providerOrder: ["codex"],
        });
      }
      if (command === "get_update_state") {
        return Promise.resolve(mockUpdateState);
      }
      if (command === "reset_codex_quota") {
        expect(args).toEqual({ credentialId: "codex-web-pro" });
        return Promise.resolve(appStateWith(resetCredential));
      }
      throw new Error(`Unexpected command: ${command}`);
    });

    render(<App />);
    await waitFor(() => expect(invoke).toHaveBeenCalledWith("get_app_state"));

    fireEvent.click(await screen.findByText("Codex"));
    fireEvent.click(screen.getByRole("button", { name: "Codex Pro Login Use reset credit" }));

    await waitFor(() =>
      expect(invoke).toHaveBeenCalledWith("reset_codex_quota", {
        credentialId: "codex-web-pro",
      }),
    );
    expect(await screen.findByText("1 credits")).toBeInTheDocument();
    expect(screen.getByText("5h 96% · Week 80%")).toBeInTheDocument();
  });
});
