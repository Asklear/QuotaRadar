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
    expect(screen.getByRole("heading", { name: "Quota Radar" })).toBeInTheDocument();
    expect(screen.getByText("Good prompts save spend.")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Settings" })).toBeInTheDocument();
  });

  it("renders risk summary buckets", () => {
    render(<TrayPopover />);
    expect(screen.getByRole("heading", { name: "Statistics" })).toBeInTheDocument();
    const summary = within(screen.getByLabelText("Risk summary"));
    expect(summary.getByText("Low")).toBeInTheDocument();
    expect(summary.getByText("Failed")).toBeInTheDocument();
    expect(summary.getByText("Available")).toBeInTheDocument();
  });

  it("uses a compact native-monitor surface instead of a dashboard card grid", () => {
    const { container } = render(<TrayPopover />);

    expect(screen.getByTestId("tray-popover")).toHaveAttribute("data-style", "native-popover");
    expect(container.querySelector(".monitor-module")).toBeInTheDocument();
    expect(container.querySelector(".attention-grid")).not.toBeInTheDocument();
    expect(container.querySelector(".tray-section-stack")).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Favorites" })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Heads Up" })).toBeInTheDocument();
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
    expect(screen.getAllByText("即将到期").length).toBeGreaterThan(0);
    expect(screen.getAllByText("需要关注").length).toBeGreaterThan(0);
    expect(screen.getAllByText("额度紧张").length).toBeGreaterThan(0);
    expect(screen.queryAllByText(/Jul|low quota/i)).toHaveLength(0);
  });

  it("requests close when the pointer leaves the popover", () => {
    const onRequestClose = vi.fn();

    render(<TrayPopover onRequestClose={onRequestClose} />);
    fireEvent.pointerLeave(screen.getByTestId("tray-popover"));

    expect(onRequestClose).toHaveBeenCalledOnce();
  });

  it("opens the settings page from the tray settings button", () => {
    const onOpenMainWindow = vi.fn();
    const onRequestClose = vi.fn();

    render(<TrayPopover onOpenMainWindow={onOpenMainWindow} onRequestClose={onRequestClose} />);
    fireEvent.click(screen.getByRole("button", { name: "Settings" }));

    expect(onOpenMainWindow).toHaveBeenCalledWith({ page: "settings" });
    expect(onRequestClose).toHaveBeenCalledOnce();
  });

  it("opens the quota page for clicked tray credentials", () => {
    const onOpenMainWindow = vi.fn();
    const onRequestClose = vi.fn();

    render(<TrayPopover onOpenMainWindow={onOpenMainWindow} onRequestClose={onRequestClose} />);
    fireEvent.click(screen.getAllByTestId("favorite-item")[0]);

    expect(onOpenMainWindow).toHaveBeenCalledWith({
      page: "quota",
      providerId: expect.any(String),
      credentialId: expect.any(String),
    });
    expect(onRequestClose).toHaveBeenCalledOnce();
  });
});
