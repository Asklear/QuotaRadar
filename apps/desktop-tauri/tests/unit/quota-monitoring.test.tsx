import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { QuotaMonitoringPage } from "../../src/pages/QuotaMonitoringPage";

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
});
