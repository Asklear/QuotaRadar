import { fireEvent, render, screen, within } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { CredentialEditorDialog } from "../../src/credentials/CredentialEditorDialog";
import { CredentialsPage } from "../../src/pages/CredentialsPage";

describe("CredentialsPage", () => {
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

  it("shows import feedback when importing Claude settings", async () => {
    render(<CredentialsPage />);

    fireEvent.click(screen.getByRole("button", { name: "Import Claude settings" }));

    expect(await screen.findByRole("status")).toHaveTextContent("Import complete:");
    expect(screen.getByRole("status")).toHaveTextContent("added 0");
    expect(screen.getByRole("status")).toHaveTextContent("updated 0");
  });
});
