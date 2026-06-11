import { fireEvent, render, screen, within } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { CredentialsPage } from "../../src/pages/CredentialsPage";

describe("CredentialsPage", () => {
  it("hides providers with no configured credentials", () => {
    render(<CredentialsPage />);
    expect(screen.queryByText("Exa")).not.toBeInTheDocument();
  });

  it("toggles provider groups from the banner", () => {
    render(<CredentialsPage />);
    expect(screen.getByText("Tavily Key 1")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Tavily 1 active 1 credential" }));
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
    expect(screen.getByText("Web Login Authorization")).toBeInTheDocument();
    expect(screen.getByText("Companion API Key")).toBeInTheDocument();
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
    fireEvent.click(screen.getByRole("button", { name: "Add" }));

    expect(await screen.findByText("Tavily Test Key")).toBeInTheDocument();
    expect(screen.getByText("tvly••••alue")).toBeInTheDocument();
  });
});
