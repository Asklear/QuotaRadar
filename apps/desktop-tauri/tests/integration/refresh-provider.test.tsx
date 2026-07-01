import { invoke } from "@tauri-apps/api/core";
import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import App from "../../src/App";
import { formatCompactDateTime } from "../../src/i18n";
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

const tavilyProvider: ProviderDefinition = {
  id: "tavily",
  displayName: "Tavily",
  familyName: "Tavily",
  category: "AI Search",
  icon: "tavily",
  dashboardUrl: "https://app.tavily.com/home",
  supportsReauth: false,
  supportsRefresh: true,
  quotaCheckConsumesSearchQuota: false,
};

const initialCredential: CredentialView = {
  id: "tavily-test",
  providerId: "tavily",
  name: "Tavily Test",
  kind: "apiKey",
  maskedValue: "tvly••••alue",
  copyable: true,
  active: true,
  status: "notChecked",
  remainingBadgeText: "Saved",
  quotaWindows: [],
  lastUpdated: "2026-06-10T12:00:00+08:00",
};

function appStateWith(credential: CredentialView): AppState {
  return {
    providers: [tavilyProvider],
    credentials: [credential],
  };
}

function mockDesktopCommands(initialState: AppState, refreshedState: AppState) {
  vi.mocked(invoke).mockImplementation((command, args) => {
    if (command === "get_app_state") {
      return Promise.resolve(initialState);
    }
    if (command === "get_settings") {
      return Promise.resolve({
        ...mockSettings,
        providerOrder: ["tavily"],
      });
    }
    if (command === "get_update_state") {
      return Promise.resolve(mockUpdateState);
    }
    if (command === "refresh_provider") {
      expect(args).toEqual({ providerId: "tavily", mode: "manual" });
      return Promise.resolve(refreshedState);
    }
    throw new Error(`Unexpected command: ${command}`);
  });
}

describe("refresh provider flow", () => {
  afterEach(() => {
    vi.mocked(invoke).mockReset();
    setTauriRuntime(false);
  });

  it("clicking refresh calls refresh_provider and updates the last updated value", async () => {
    setTauriRuntime(true);
    const refreshedCredential: CredentialView = {
      ...initialCredential,
      status: "healthy",
      remaining: 920,
      limit: 1000,
      remainingBadgeText: "920 / 1000",
      quotaWindows: [{ name: "month", percentRemaining: 92, resetAt: "2026-07-01T00:00:00+08:00" }],
      resetAt: "2026-07-01T00:00:00+08:00",
      lastUpdated: "2026-06-11T12:30:00+08:00",
      lastHttpStatus: 200,
    };
    mockDesktopCommands(appStateWith(initialCredential), appStateWith(refreshedCredential));

    render(<App />);
    await waitFor(() => expect(invoke).toHaveBeenCalledWith("get_app_state"));

    fireEvent.click(await screen.findByRole("button", { name: "Tavily Refresh" }));

    await waitFor(() => expect(invoke).toHaveBeenCalledWith("refresh_provider", { providerId: "tavily", mode: "manual" }));
    fireEvent.click(screen.getByText("Tavily"));

    expect(
      await screen.findByText(formatCompactDateTime(refreshedCredential.lastUpdated!, "en")),
    ).toBeInTheDocument();
    expect(screen.getByText("920 / 1000")).toBeInTheDocument();
  });

  it("shows failed refresh diagnostics from the returned app state", async () => {
    setTauriRuntime(true);
    const failedCredential: CredentialView = {
      ...initialCredential,
      status: "failed",
      remainingBadgeText: "Check failed",
      lastUpdated: "2026-06-11T12:35:00+08:00",
      lastHttpStatus: 500,
      diagnosticMessage: "Provider fixture parse failed",
    };
    mockDesktopCommands(appStateWith(initialCredential), appStateWith(failedCredential));

    render(<App />);
    await waitFor(() => expect(invoke).toHaveBeenCalledWith("get_app_state"));

    fireEvent.click(await screen.findByRole("button", { name: "Tavily Refresh" }));
    fireEvent.click(await screen.findByRole("button", { name: "Diagnostics" }));

    expect(await screen.findByText("Provider fixture parse failed")).toBeInTheDocument();
    expect(screen.getByText("HTTP 500")).toBeInTheDocument();
    expect(screen.getByText("Failed")).toBeInTheDocument();
  });

  it("shows a persistent alert when manual refresh returns failed diagnostics", async () => {
    setTauriRuntime(true);
    const failedCredential: CredentialView = {
      ...initialCredential,
      status: "failed",
      remainingBadgeText: "Check failed",
      lastUpdated: "2026-06-11T12:35:00+08:00",
      diagnosticMessage: "Tavily quota endpoint returned HTTP 401",
    };
    mockDesktopCommands(appStateWith(initialCredential), appStateWith(failedCredential));

    render(<App />);
    await waitFor(() => expect(invoke).toHaveBeenCalledWith("get_app_state"));

    fireEvent.click(await screen.findByRole("button", { name: "Tavily Refresh" }));

    const alert = await screen.findByRole("alert");
    expect(alert).toHaveTextContent("Refresh failed for Tavily");
    expect(alert).toHaveTextContent("Tavily quota endpoint returned HTTP 401");
  });
});
