import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { AppShell } from "../../src/shell/AppShell";

describe("AppShell", () => {
  it("renders navigation in the product order", () => {
    render(<AppShell />);
    const labels = screen.getAllByRole("button").map((button) => button.textContent);
    expect(labels.join("|")).toContain("Quota Monitoring|Credentials|Diagnostics|Settings");
  });
});
