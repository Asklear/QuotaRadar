import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import App from "../../src/App";
import { mockSettings, mockUpdateState } from "../../src/lib/tauriClient";
import type { AppState, CredentialView, ProviderDefinition } from "../../src/shared/types";

vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn(),
}));

vi.mock("@tauri-apps/api/event", () => ({
  listen: vi.fn(() => Promise.resolve(() => undefined)),
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

const claudeProvider: ProviderDefinition = {
  id: "claude",
  displayName: "Claude",
  familyName: "Anthropic",
  category: "LLM",
  planType: "Pro",
  icon: "claude",
  dashboardUrl: "https://claude.ai/settings/usage",
  supportsReauth: true,
  supportsRefresh: true,
  quotaCheckConsumesSearchQuota: false,
};

const claudeAuthorization: CredentialView = {
  id: "claude-web-pro",
  providerId: "claude",
  name: "Claude Pro Login",
  kind: "dashboardCookie",
  maskedValue: "Web login authorization saved",
  copyable: false,
  active: true,
  status: "expired",
  remainingBadgeText: "Login expired",
  quotaWindows: [],
};

function mockDesktopCommands(state: AppState) {
  vi.mocked(invoke).mockImplementation((command, args) => {
    if (command === "get_app_state") {
      return Promise.resolve(state);
    }
    if (command === "get_settings") {
      return Promise.resolve({
        ...mockSettings,
        providerOrder: ["claude"],
      });
    }
    if (command === "get_update_state") {
      return Promise.resolve(mockUpdateState);
    }
    if (command === "start_web_authorization") {
      return Promise.resolve({
        providerId: "claude",
        targetCredentialId: (args as { targetCredentialId?: string }).targetCredentialId,
        loginUrl: "https://claude.ai/settings/usage",
        message: "Ready to update Claude Pro Login",
      });
    }
    if (command === "open_external_url") {
      return Promise.resolve(undefined);
    }
    throw new Error(`Unexpected command: ${command}`);
  });
}

describe("web authorization UI shell", () => {
  afterEach(() => {
    const mockedWindowOpen = window.open as typeof window.open & { mockRestore?: () => void };
    mockedWindowOpen.mockRestore?.();
    vi.mocked(invoke).mockReset();
    vi.mocked(listen).mockReset();
    vi.mocked(listen).mockImplementation(() => Promise.resolve(() => undefined));
    setTauriRuntime(false);
  });

  it("starts reauthorization for the provider and the existing dashboard account", async () => {
    vi.spyOn(window, "open").mockImplementation(() => null);
    setTauriRuntime(true);
    mockDesktopCommands({
      providers: [claudeProvider],
      credentials: [claudeAuthorization],
    });

    render(<App />);
    await waitFor(() => expect(invoke).toHaveBeenCalledWith("get_app_state"));

    fireEvent.click(await screen.findByRole("button", { name: "Claude Reauthorize Claude Pro Login" }));

    await waitFor(() =>
      expect(invoke).toHaveBeenCalledWith("start_web_authorization", {
        providerId: "claude",
        targetCredentialId: "claude-web-pro",
      }),
    );
  });

  it("does not silently choose a target when multiple dashboard authorizations exist", async () => {
    vi.spyOn(window, "open").mockImplementation(() => null);
    setTauriRuntime(true);
    mockDesktopCommands({
      providers: [claudeProvider],
      credentials: [
        claudeAuthorization,
        {
          ...claudeAuthorization,
          id: "claude-web-max",
          name: "Claude Max Login",
        },
      ],
    });

    render(<App />);
    await waitFor(() => expect(invoke).toHaveBeenCalledWith("get_app_state"));

    fireEvent.click(await screen.findByRole("button", { name: "Claude Reauthorize choose account" }));

    await waitFor(() =>
      expect(invoke).toHaveBeenCalledWith("start_web_authorization", {
        providerId: "claude",
        targetCredentialId: undefined,
      }),
    );
  });

  it("starts first-time web authorization in the desktop auth window from the add credential dialog", async () => {
    const open = vi.spyOn(window, "open").mockImplementation(() => null);
    setTauriRuntime(true);
    mockDesktopCommands({
      providers: [claudeProvider],
      credentials: [],
    });
    vi.mocked(invoke).mockImplementation((command, args) => {
      if (command === "get_app_state") {
        return Promise.resolve({
          providers: [claudeProvider],
          credentials: [],
        });
      }
      if (command === "get_settings") {
        return Promise.resolve({
          ...mockSettings,
          providerOrder: ["claude"],
        });
      }
      if (command === "get_update_state") {
        return Promise.resolve(mockUpdateState);
      }
      if (command === "list_credentials") {
        return Promise.resolve([]);
      }
      if (command === "start_web_authorization") {
        return Promise.resolve({
          providerId: "claude",
          targetCredentialId: (args as { targetCredentialId?: string }).targetCredentialId,
          loginUrl: "https://claude.ai/settings/usage",
          message: "Choose an authorization target",
        });
      }
      if (command === "open_external_url") {
        return Promise.resolve(undefined);
      }
      throw new Error(`Unexpected command: ${command}`);
    });

    render(<App />);
    await waitFor(() => expect(invoke).toHaveBeenCalledWith("get_app_state"));

    fireEvent.click(screen.getByRole("button", { name: "Credentials" }));
    fireEvent.click(await screen.findByRole("button", { name: "Add Credential" }));
    fireEvent.click(await screen.findByRole("button", { name: "Open web login Claude" }));

    await waitFor(() => expect(invoke).toHaveBeenCalledWith("start_web_authorization", {
      providerId: "claude",
      targetCredentialId: undefined,
    }));
    expect(invoke).not.toHaveBeenCalledWith("open_external_url", {
      url: "https://claude.ai/settings/usage",
    });
    expect(open).not.toHaveBeenCalled();
  });

  it("shows a recoverable error when desktop web authorization capture fails", async () => {
    setTauriRuntime(true);
    const eventHandlers = new Map<string, (event: { payload: unknown }) => void>();
    vi.mocked(listen).mockImplementation((event, handler) => {
      eventHandlers.set(event, handler as (event: { payload: unknown }) => void);
      return Promise.resolve(() => undefined);
    });
    mockDesktopCommands({
      providers: [claudeProvider],
      credentials: [claudeAuthorization],
    });

    render(<App />);

    await waitFor(() =>
      expect(listen).toHaveBeenCalledWith("web_authorization_failed", expect.any(Function)),
    );
    eventHandlers.get("web_authorization_failed")?.({
      payload: {
        providerId: "claude",
        message: "Could not capture required login cookies. Please try again.",
      },
    });

    expect(await screen.findByRole("alert")).toHaveTextContent("Web login authorization failed");
    expect(screen.getByRole("alert")).toHaveTextContent("Could not capture required login cookies");
  });
});
