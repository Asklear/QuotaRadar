import { invoke } from "@tauri-apps/api/core";
import { fireEvent, render, screen, within } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { CredentialEditorDialog } from "../../src/credentials/CredentialEditorDialog";
import { LocaleContext } from "../../src/i18n";
import { CredentialsPage } from "../../src/pages/CredentialsPage";
import type { ProviderDefinition } from "../../src/shared/types";

vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn(),
}));

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

describe("CredentialsPage", () => {
  afterEach(() => {
    vi.mocked(invoke).mockReset();
    setTauriRuntime(false);
  });

  it("hides providers with no configured credentials", () => {
    render(<CredentialsPage />);
    expect(screen.queryByText("Exa")).not.toBeInTheDocument();
  });

  it("toggles provider groups from the banner", () => {
    render(<CredentialsPage />);
    expect(screen.getByText("Tavily Key 1")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Tavily 1 Active 1 Credential" }));
    expect(screen.queryByText("Tavily Key 1")).not.toBeInTheDocument();
  });

  it("keeps credential action order stable", () => {
    render(<CredentialsPage />);
    const tavilyRow = screen.getByTestId("credential-row-tavily-primary");
    const actions = within(tavilyRow).getAllByTestId("credential-action").map((node) => node.textContent);
    expect(actions).toEqual(["Status", "Enabled", "Copy", "Edit"]);
  });

  it("toggles credential active state directly from the row", async () => {
    render(<CredentialsPage />);

    const tavilyRow = screen.getByTestId("credential-row-tavily-primary");
    fireEvent.click(within(tavilyRow).getByRole("switch", { name: "Disable Tavily Key 1" }));

    const updatedRow = await screen.findByTestId("credential-row-tavily-primary");
    expect(updatedRow.querySelector(".mock-switch")).toHaveAttribute("data-enabled", "false");
  });

  it("localizes credential action group labels", () => {
    render(
      <LocaleContext.Provider value="zh-Hans">
        <CredentialsPage />
      </LocaleContext.Provider>,
    );

    expect(screen.getByRole("group", { name: "Tavily Key 1 操作" })).toBeInTheDocument();
    expect(screen.queryByRole("group", { name: "Tavily Key 1 actions" })).not.toBeInTheDocument();
  });

  it("does not show copy for web login authorization", () => {
    render(<CredentialsPage />);
    const claudeRow = screen.getByTestId("credential-row-claude-web-pro");
    expect(within(claudeRow).queryByRole("button", { name: "Copy Claude Pro Login" })).not.toBeInTheDocument();
  });

  it("distinguishes companion API keys from web login authorization", () => {
    render(<CredentialsPage />);
    expect(screen.getAllByText("Web Login Authorization").length).toBeGreaterThan(0);
    expect(screen.getAllByText("Companion API Key").length).toBeGreaterThan(0);
  });

  it("opens editor dialog with hidden secret fields", () => {
    render(<CredentialsPage />);
    fireEvent.click(screen.getByRole("button", { name: "Add Credential" }));
    expect(screen.getByRole("dialog", { name: "Add Credential" })).toBeInTheDocument();
    expect(screen.getByLabelText("API key")).toHaveAttribute("type", "password");
    expect(screen.getByText("Web login authorization")).toBeInTheDocument();
  });

  it("adds a copy-safe API key credential from the editor", async () => {
    render(<CredentialsPage />);

    fireEvent.click(screen.getByRole("button", { name: "Add Credential" }));
    fireEvent.change(screen.getByPlaceholderText("Tavily Credential"), {
      target: { value: "Tavily Test Key" },
    });
    fireEvent.change(screen.getByLabelText("API key"), {
      target: { value: "tvly-local-test-value" },
    });
    fireEvent.click(within(screen.getByRole("dialog", { name: "Add Credential" })).getByRole("button", { name: "Add Credential" }));

    expect(await screen.findByText("Tavily Test Key")).toBeInTheDocument();
    expect(screen.getByText("tvly••••alue")).toBeInTheDocument();
  });

  it("opens existing credentials in edit mode and replaces the row on save", async () => {
    render(<CredentialsPage />);

    fireEvent.click(screen.getByRole("button", { name: "Edit Tavily Key 1" }));

    const dialog = await screen.findByRole("dialog", { name: "Edit Credential" });
    expect(within(dialog).getByDisplayValue("Tavily Key 1")).toBeInTheDocument();

    fireEvent.change(within(dialog).getByDisplayValue("Tavily Key 1"), {
      target: { value: "Tavily Edited Key" },
    });
    fireEvent.change(within(dialog).getByLabelText("API key"), {
      target: { value: "tvly-edited-secret-1234" },
    });
    fireEvent.click(within(dialog).getByLabelText("Active"));
    fireEvent.click(within(dialog).getByRole("button", { name: "Save" }));

    expect(await screen.findByText("Tavily Edited Key")).toBeInTheDocument();
    expect(screen.getByText("tvly••••1234")).toBeInTheDocument();
    expect(screen.queryByText("Tavily Key 1")).not.toBeInTheDocument();
    expect(screen.getByTestId("credential-row-tavily-primary").querySelector(".mock-switch"))
      .toHaveAttribute("data-enabled", "false");
  });

  it("locks provider selection when editing an existing credential", async () => {
    render(<CredentialsPage />);

    fireEvent.click(screen.getByRole("button", { name: "Edit Tavily Key 1" }));

    const dialog = await screen.findByRole("dialog", { name: "Edit Credential" });
    expect(within(dialog).getByRole("button", { name: "Tavily" })).toBeDisabled();
    expect(within(dialog).getByRole("button", { name: "Brave" })).toBeDisabled();
  });

  it("deletes an existing credential from the editor", async () => {
    render(<CredentialsPage />);

    fireEvent.click(screen.getByRole("button", { name: "Edit Tavily Key 1" }));
    fireEvent.click(await screen.findByRole("button", { name: "Delete" }));

    expect(screen.queryByText("Tavily Key 1")).not.toBeInTheDocument();
  });

  it("keeps the editor open and shows save failures", async () => {
    render(
      <CredentialEditorDialog
        open
        onClose={vi.fn()}
        onSave={async () => {
          throw new Error("Windows store save failed");
        }}
      />,
    );

    fireEvent.change(screen.getByLabelText("API key"), {
      target: { value: "tvly-local-test-value" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Add Credential" }));

    expect(await screen.findByRole("alert")).toHaveTextContent(
      "Could not save credential: Windows store save failed",
    );
    expect(screen.getByRole("dialog", { name: "Add Credential" })).toBeInTheDocument();
  });

  it("localizes known system errors in editor save failures", async () => {
    render(
      <LocaleContext.Provider value="zh-Hans">
        <CredentialEditorDialog
          open
          onClose={vi.fn()}
          onSave={async () => {
            throw new Error("Credential was not found");
          }}
        />
      </LocaleContext.Provider>,
    );

    fireEvent.change(screen.getByLabelText("API 密钥"), {
      target: { value: "tvly-local-test-value" },
    });
    fireEvent.click(screen.getByRole("button", { name: "添加凭据" }));

    expect(await screen.findByRole("alert")).toHaveTextContent("无法保存凭据：未找到凭据");
    expect(screen.getByRole("alert")).not.toHaveTextContent("Credential was not found");
  });

  it("localizes known system errors in editor web authorization failures", async () => {
    render(
      <LocaleContext.Provider value="zh-Hans">
        <CredentialEditorDialog
          open
          onClose={vi.fn()}
          providers={[claudeProvider]}
          onStartWebAuthorization={async () => {
            throw new Error("Provider does not have a web authorization URL");
          }}
        />
      </LocaleContext.Provider>,
    );

    fireEvent.click(screen.getByRole("button", { name: "打开网页登录 Claude" }));

    expect(await screen.findByRole("status")).toHaveTextContent(
      "网页登录失败：服务商没有网页登录 URL",
    );
    expect(screen.getByRole("status")).not.toHaveTextContent(
      "Provider does not have a web authorization URL",
    );
  });

  it("localizes known system errors in Claude settings import failures", async () => {
    setTauriRuntime(true);
    vi.mocked(invoke).mockImplementation((command) => {
      if (command === "list_credentials") {
        return Promise.resolve([]);
      }
      if (command === "import_claude_settings") {
        return Promise.reject(new Error("Credential value was not found"));
      }
      throw new Error(`Unexpected command: ${command}`);
    });

    render(
      <LocaleContext.Provider value="zh-Hans">
        <CredentialsPage />
      </LocaleContext.Provider>,
    );

    fireEvent.click(screen.getByRole("button", { name: "导入 Claude 设置" }));

    expect(await screen.findByRole("status")).toHaveTextContent("导入失败：未找到凭据值");
    expect(screen.getByRole("status")).not.toHaveTextContent("Credential value was not found");
  });

  it("shows import feedback when importing Claude settings", async () => {
    render(<CredentialsPage />);

    fireEvent.click(screen.getByRole("button", { name: "Import Claude settings" }));

    expect(await screen.findByRole("status")).toHaveTextContent("Import complete:");
    expect(screen.getByRole("status")).toHaveTextContent("added 0");
    expect(screen.getByRole("status")).toHaveTextContent("updated 0");
  });

  it("localizes Claude settings import success feedback as one sentence", async () => {
    render(
      <LocaleContext.Provider value="zh-Hans">
        <CredentialsPage />
      </LocaleContext.Provider>,
    );

    fireEvent.click(screen.getByRole("button", { name: "导入 Claude 设置" }));

    expect(await screen.findByRole("status")).toHaveTextContent(
      "导入完成：新增 0，更新 0。",
    );
  });
});
