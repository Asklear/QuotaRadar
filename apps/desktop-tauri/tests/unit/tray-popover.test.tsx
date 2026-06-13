import { fireEvent, render, screen, within } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { LocaleContext } from "../../src/i18n";
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
    expect(screen.getByText("API Quota")).toBeInTheDocument();
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

  it("uses a compact native-monitor surface instead of a dashboard card grid", () => {
    const { container } = render(<TrayPopover />);

    expect(screen.getByTestId("tray-popover")).toHaveAttribute("data-style", "glass-modules");
    expect(container.querySelector(".monitor-module")).toBeInTheDocument();
    expect(container.querySelector(".attention-grid")).not.toBeInTheDocument();
    expect(container.querySelector(".attention-stack")).toBeInTheDocument();
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

  it("localizes menu bar status and timing labels", () => {
    render(
      <LocaleContext.Provider value="zh-Hans">
        <TrayPopover />
      </LocaleContext.Provider>,
    );

    expect(screen.getAllByText("紧张").length).toBeGreaterThan(0);
    expect(screen.getByText("即将到期")).toBeInTheDocument();
    expect(screen.getByText("需要关注")).toBeInTheDocument();
    expect(screen.getByText("额度紧张")).toBeInTheDocument();
    expect(screen.queryAllByText(/Jul|low quota/i)).toHaveLength(0);
  });

  it("requests close when the pointer leaves the popover", () => {
    const onRequestClose = vi.fn();

    render(<TrayPopover onRequestClose={onRequestClose} />);
    fireEvent.pointerLeave(screen.getByTestId("tray-popover"));

    expect(onRequestClose).toHaveBeenCalledOnce();
  });
});
