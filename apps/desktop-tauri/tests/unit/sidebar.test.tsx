import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { AppShell } from "../../src/shell/AppShell";

describe("AppShell", () => {
  it("renders navigation in the product order", () => {
    render(<AppShell />);
    const labels = screen.getAllByRole("button").map((button) => button.textContent);
    expect(labels.join("|")).toContain("Quota Overview|Credentials|Diagnostics|Settings");
    expect(screen.getByText("Internal prerelease parity QA in progress.")).toBeInTheDocument();
    expect(screen.queryByText("Mock desktop shell ready for quota pages.")).not.toBeInTheDocument();
  });

  it("renders sidebar statistics as the Swift-style vertical list", () => {
    const { container } = render(<AppShell />);

    expect(screen.getByRole("heading", { name: "STATISTICS" })).toBeVisible();
    expect(screen.getByText("Keys")).toBeVisible();
    expect(screen.getByText("Providers")).toBeVisible();
    expect(screen.getByText("Low")).toBeVisible();
    expect(container.querySelector(".sidebar-statistics")).toBeInTheDocument();
    expect(container.querySelector(".sidebar-metrics")).not.toBeInTheDocument();
  });
});
