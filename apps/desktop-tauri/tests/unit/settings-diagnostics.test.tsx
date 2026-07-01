import { fireEvent, render, screen, within } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { LocaleContext } from "../../src/i18n";
import { AboutPage } from "../../src/pages/AboutPage";
import { DiagnosticsPage } from "../../src/pages/DiagnosticsPage";
import { SettingsPage } from "../../src/pages/SettingsPage";

describe("DiagnosticsPage", () => {
  it("shows credential health and HTTP status without duplicating quota values", () => {
    render(<DiagnosticsPage />);

    const tavily = screen.getByRole("region", { name: "Tavily diagnostics" });
    const codex = screen.getByRole("region", { name: "Codex diagnostics" });

    expect(within(tavily).getByText("Tavily")).toBeInTheDocument();
    expect(within(tavily).getByText("Healthy")).toBeInTheDocument();
    expect(within(tavily).getByText("HTTP 200")).toBeInTheDocument();
    expect(within(codex).getByText("Codex")).toBeInTheDocument();
    expect(within(codex).getByText("Expired")).toBeInTheDocument();
    expect(within(codex).getByText("HTTP 401")).toBeInTheDocument();

    expect(screen.queryByText("920 / 1000")).not.toBeInTheDocument();
    expect(screen.queryByText("Week 40%")).not.toBeInTheDocument();
    expect(screen.queryByText("Month 8.4%")).not.toBeInTheDocument();
  });

  it("localizes provider diagnostics region labels", () => {
    render(
      <LocaleContext.Provider value="zh-Hans">
        <DiagnosticsPage />
      </LocaleContext.Provider>,
    );

    expect(screen.getByRole("region", { name: "Tavily 诊断" })).toBeInTheDocument();
    expect(screen.queryByRole("region", { name: "Tavily diagnostics" })).not.toBeInTheDocument();
  });
});

describe("SettingsPage", () => {
  it("contains core desktop preferences", () => {
    render(<SettingsPage />);

    [
      "Language",
      "Custom provider order",
      "Launch at login",
      "Check for updates",
      "Auto refresh",
      "Costly refresh",
      "Network proxy",
      "Menu bar transparency",
    ].forEach((label) => {
      expect(screen.getByText(label)).toBeInTheDocument();
    });
  });

  it("localizes language picker option labels", () => {
    render(
      <LocaleContext.Provider value="zh-Hans">
        <SettingsPage />
      </LocaleContext.Provider>,
    );

    const languagePicker = screen.getByRole("combobox", { name: "语言" });
    expect(
      within(languagePicker)
        .getAllByRole("option")
        .map((option) => option.textContent),
    ).toEqual(["英语", "简体中文", "繁体中文", "日语", "韩语"]);
  });

  it("opens a provider order dialog separated by category", () => {
    render(<SettingsPage />);

    fireEvent.click(screen.getByRole("button", { name: "Customize provider order" }));
    const dialog = screen.getByRole("dialog", { name: "Provider order" });

    const aiSearch = within(dialog).getByRole("group", { name: "AI Search" });
    const llm = within(dialog).getByRole("group", { name: "LLM" });

    expect(within(aiSearch).getByText("Tavily")).toBeInTheDocument();
    expect(within(aiSearch).getByText("Brave")).toBeInTheDocument();
    expect(within(llm).getByText("Claude")).toBeInTheDocument();
    expect(within(llm).getByText("Kimi")).toBeInTheDocument();
  });
});

describe("AboutPage", () => {
  it("summarizes the cross-platform desktop app", () => {
    render(<AboutPage />);

    expect(screen.getByRole("heading", { name: "Quota Radar" })).toBeInTheDocument();
    expect(screen.getByText("Tauri desktop preview")).toBeInTheDocument();
    expect(screen.getByText("Internal prerelease parity QA")).toBeInTheDocument();
    expect(screen.getByText("Swift parity, provider login QA, and cross-platform packaging in progress")).toBeInTheDocument();
    expect(screen.queryByText("Mock UI first, backend contracts next")).not.toBeInTheDocument();
    expect(screen.queryByText("No real provider secrets in preview data")).not.toBeInTheDocument();
  });

  it("localizes the desktop app summary", () => {
    render(
      <LocaleContext.Provider value="zh-Hans">
        <AboutPage />
      </LocaleContext.Provider>,
    );

    expect(screen.getByRole("heading", { name: "Quota Radar" })).toBeInTheDocument();
    expect(screen.getByText("Tauri 桌面预览版")).toBeInTheDocument();
    expect(screen.getByText("平台目标")).toBeInTheDocument();
    expect(screen.queryByText("Tauri desktop preview")).not.toBeInTheDocument();
    expect(screen.queryByText("Platform target")).not.toBeInTheDocument();
  });
});
