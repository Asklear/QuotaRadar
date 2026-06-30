import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { QuotaMonitoringPage } from "../../src/pages/QuotaMonitoringPage";
import { providerRegistry } from "../../src/shared/providerRegistry";

describe("QuotaMonitoringPage", () => {
  it("renders the Swift-style quota overview title and summary", () => {
    render(<QuotaMonitoringPage />);

    expect(screen.getByRole("heading", { name: "Quota Overview" })).toBeVisible();
    expect(screen.getByText(/configured .* supported/)).toBeVisible();
  });

  it("renders AI Search before LLM", () => {
    render(<QuotaMonitoringPage />);
    const aiSearch = screen.getByRole("heading", { name: "AI Search" });
    const llm = screen.getByRole("heading", { name: "LLM" });
    expect(aiSearch.compareDocumentPosition(llm) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
  });

  it("renders provider summary headers", () => {
    render(<QuotaMonitoringPage />);
    for (const header of ["Provider", "Key Quota", "Credential Pool", "Critical Time", "State"]) {
      expect(screen.getAllByText(header).length).toBeGreaterThan(0);
    }
  });

  it("uses compact disclosure rows instead of a browser-style provider table", () => {
    const { container } = render(<QuotaMonitoringPage />);

    expect(container.querySelector(".provider-table")).not.toBeInTheDocument();
    expect(container.querySelector(".provider-list")).toBeInTheDocument();

    const tavilyRow = screen.getByRole("button", { name: /Tavily.*92%/ });
    expect(tavilyRow).toHaveClass("provider-row-card");
    expect(tavilyRow).toHaveAttribute("aria-expanded", "false");

    fireEvent.click(tavilyRow);

    expect(tavilyRow).toHaveAttribute("aria-expanded", "true");
    expect(screen.getByTestId("provider-detail-tavily")).toHaveClass("provider-detail-panel");
  });

  it("hides providers with no configured credentials", () => {
    render(<QuotaMonitoringPage />);
    expect(screen.queryByText("Exa")).not.toBeInTheDocument();
  });

  it("expands provider rows to credential details", () => {
    render(<QuotaMonitoringPage />);
    fireEvent.click(screen.getByText("Tavily"));
    expect(screen.getByText("Tavily Key 1")).toBeInTheDocument();
    expect(screen.getByText("920 / 1000")).toBeInTheDocument();
  });

  it("shows Codex reset credits and earliest expiry in credential details", () => {
    const codexProvider = providerRegistry.find((provider) => provider.id === "codex");

    render(
      <QuotaMonitoringPage
        providers={codexProvider ? [codexProvider] : []}
        credentials={[
          {
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
            quotaWindows: [
              { name: "5h", percentRemaining: 80, resetAt: "2026-06-30T16:00:00Z" },
              { name: "week", percentRemaining: 60, resetAt: "2026-07-07T16:00:00Z" },
            ],
            planEndsAt: "2026-07-08T16:42:25Z",
            codexResetCreditsRemaining: 2,
            codexResetCreditsEarliestExpiresAt: "2026-07-18T00:38:14Z",
            lastUpdated: "2026-06-30T10:00:00Z",
            lastHttpStatus: 200,
          },
        ]}
      />,
    );

    fireEvent.click(screen.getByText("Codex"));

    expect(screen.getByText("2 credits")).toBeInTheDocument();
    expect(screen.getByText(/Earliest expires/)).toBeInTheDocument();
  });
});
