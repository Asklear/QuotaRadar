import { invoke } from "@tauri-apps/api/core";
import { fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import App from "../../src/App";
import { mockSettings, mockUpdateState } from "../../src/lib/tauriClient";
import type { AppState, CredentialInput, CredentialView, ProviderDefinition } from "../../src/shared/types";

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

const createdCredential: CredentialView = {
  id: "tavily-synced-key",
  providerId: "tavily",
  name: "Tavily Synced Key",
  kind: "apiKey",
  maskedValue: "tvly••••alue",
  copyable: true,
  active: true,
  status: "notChecked",
  remainingBadgeText: "Saved",
  quotaWindows: [],
};

function emptyAppState(): AppState {
  return {
    providers: [tavilyProvider],
    credentials: [],
  };
}

describe("credential state sync", () => {
  afterEach(() => {
    vi.mocked(invoke).mockReset();
    setTauriRuntime(false);
  });

  it("shows newly added credentials in quota overview without restarting", async () => {
    setTauriRuntime(true);
    let storedCredentials: CredentialView[] = [];

    vi.mocked(invoke).mockImplementation((command, args) => {
      if (command === "get_app_state") {
        return Promise.resolve(emptyAppState());
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
      if (command === "list_credentials") {
        return Promise.resolve(storedCredentials);
      }
      if (command === "create_credential") {
        expect((args as { input: CredentialInput }).input.providerId).toBe("tavily");
        storedCredentials = [createdCredential];
        return Promise.resolve(createdCredential);
      }
      throw new Error(`Unexpected command: ${command}`);
    });

    render(<App />);
    await waitFor(() => expect(invoke).toHaveBeenCalledWith("get_app_state"));

    fireEvent.click(screen.getByRole("button", { name: "Credentials" }));
    fireEvent.click(await screen.findByRole("button", { name: "Add Credential" }));

    const dialog = await screen.findByRole("dialog", { name: "Add Credential" });
    fireEvent.change(within(dialog).getByPlaceholderText("Tavily Credential"), {
      target: { value: "Tavily Synced Key" },
    });
    fireEvent.change(within(dialog).getByLabelText("API key"), {
      target: { value: "tvly-synced-test-value" },
    });
    fireEvent.click(within(dialog).getByRole("button", { name: "Add Credential" }));

    expect(await screen.findByText("Tavily Synced Key")).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "Quota Overview" }));

    expect(await screen.findByText("Tavily")).toBeInTheDocument();
    expect(screen.getByText("Saved")).toBeInTheDocument();
  });
});
