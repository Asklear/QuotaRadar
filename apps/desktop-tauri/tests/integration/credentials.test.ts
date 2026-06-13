import { invoke } from "@tauri-apps/api/core";
import { afterEach, describe, expect, it, vi } from "vitest";
import {
  copyCredentialValue,
  createCredential,
  importClaudeSettings,
  listCredentials,
} from "../../src/lib/tauriClient";
import type { CredentialInput } from "../../src/shared/types";

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

describe("credential commands", () => {
  afterEach(() => {
    vi.mocked(invoke).mockReset();
    setTauriRuntime(false);
  });

  it("lists credentials through Tauri in desktop runtime", async () => {
    setTauriRuntime(true);
    vi.mocked(invoke).mockResolvedValue([
      {
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
      },
    ]);

    const credentials = await listCredentials();

    expect(invoke).toHaveBeenCalledWith("list_credentials");
    expect(credentials[0].maskedValue).toBe("tvly••••alue");
  });

  it("creates credentials without sending raw values to metadata APIs", async () => {
    setTauriRuntime(true);
    const input: CredentialInput = {
      id: "tavily-test",
      providerId: "tavily",
      name: "Tavily Test",
      kind: "apiKey",
      secret: "tvly-real-secret-value",
    };
    vi.mocked(invoke).mockResolvedValue({
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
    });

    const credential = await createCredential(input);

    expect(invoke).toHaveBeenCalledWith("create_credential", { input });
    expect(JSON.stringify(credential)).not.toContain("tvly-real-secret-value");
  });

  it("copies only copyable credential values", async () => {
    setTauriRuntime(true);
    vi.mocked(invoke).mockResolvedValue("tvly-real-secret-value");

    const secret = await copyCredentialValue("tavily-test");

    expect(invoke).toHaveBeenCalledWith("copy_credential_value", {
      credentialId: "tavily-test",
    });
    expect(secret).toBe("tvly-real-secret-value");
  });

  it("imports Claude settings through Tauri in desktop runtime", async () => {
    setTauriRuntime(true);
    vi.mocked(invoke).mockResolvedValue({
      added: 1,
      updated: 1,
      credentials: [
        {
          id: "imported-claude-anthropic-api-key",
          providerId: "claude",
          name: "ANTHROPIC_API_KEY",
          kind: "storedAPIKeyOnly",
          maskedValue: "anth••••alue",
          copyable: true,
          active: true,
          status: "notChecked",
          remainingBadgeText: "API key saved",
          quotaWindows: [],
        },
      ],
    });

    const summary = await importClaudeSettings();

    expect(invoke).toHaveBeenCalledWith("import_claude_settings");
    expect(summary.added).toBe(1);
    expect(JSON.stringify(summary)).not.toContain("anthropic-example-value");
  });

  it("does not expose mock web login authorization secrets outside Tauri runtime", async () => {
    await expect(copyCredentialValue("claude-web-pro")).rejects.toThrow(
      "Credential value is not copyable",
    );
    expect(invoke).not.toHaveBeenCalled();
  });
});
