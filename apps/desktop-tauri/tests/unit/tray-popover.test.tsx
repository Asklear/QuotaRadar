import { render, screen, within } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { TrayPopover } from "../../src/tray/TrayPopover";

describe("TrayPopover", () => {
  it("uses fixed popover size tokens", () => {
    render(<TrayPopover />);
    expect(screen.getByTestId("tray-popover")).toHaveStyle({
      width: "var(--qr-tray-width)",
      height: "var(--qr-tray-height)",
    });
  });

  it("renders header, quote, and settings action", () => {
    render(<TrayPopover />);
    expect(screen.getByText("Quota Radar")).toBeInTheDocument();
    expect(screen.getByText("Keep quota anxiety visible, not loud.")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Settings" })).toBeInTheDocument();
  });

  it("renders risk summary buckets", () => {
    render(<TrayPopover />);
    const summary = within(screen.getByLabelText("Risk summary"));
    expect(summary.getByText("Low")).toBeInTheDocument();
    expect(summary.getByText("Failed")).toBeInTheDocument();
    expect(summary.getByText("Available")).toBeInTheDocument();
  });

  it("limits attention lists for menu bar density", () => {
    render(<TrayPopover />);
    expect(screen.getAllByTestId("low-quota-item").length).toBeLessThanOrEqual(3);
    expect(screen.getAllByTestId("expiring-item").length).toBeLessThanOrEqual(3);
    expect(screen.getAllByTestId("needs-attention-item").length).toBeLessThanOrEqual(2);
  });

  it("keeps expiring dates compact", () => {
    render(<TrayPopover />);
    for (const item of screen.getAllByTestId("expiring-item")) {
      expect(item).not.toHaveTextContent("T");
    }
  });
});
