import { fireEvent, render, screen, within } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { LocaleContext } from "../../src/i18n";
import { AboutPage } from "../../src/pages/AboutPage";
import { DiagnosticsPage } from "../../src/pages/DiagnosticsPage";
import { SettingsPage } from "../../src/pages/SettingsPage";
import { mockSettings } from "../../src/lib/tauriClient";

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

  it("localizes provider diagnostic messages without dynamic details", () => {
    render(
      <LocaleContext.Provider value="zh-Hans">
        <DiagnosticsPage
          providers={[
            {
              id: "tavily",
              displayName: "Tavily",
              familyName: "Tavily",
              category: "AI Search",
              icon: "tavily",
              supportsReauth: false,
              supportsRefresh: true,
              quotaCheckConsumesSearchQuota: false,
            },
          ]}
          credentials={[
            {
              id: "tavily-primary",
              providerId: "tavily",
              name: "Tavily Key",
              kind: "apiKey",
              maskedValue: "tvly••••9Q2a",
              copyable: true,
              active: true,
              status: "failed",
              remainingBadgeText: "Check failed",
              quotaWindows: [],
              diagnosticMessage: "Provider fixture parse failed",
            },
          ]}
        />
      </LocaleContext.Provider>,
    );

    expect(screen.getByText("服务商 fixture 解析失败")).toBeInTheDocument();
    expect(screen.queryByText("Provider fixture parse failed")).not.toBeInTheDocument();
  });

  it("shows Swift-style diagnostic details for request context and refresh policy", () => {
    render(
      <DiagnosticsPage
        settings={{
          ...mockSettings,
          autoRefreshInterval: "1h",
          costlyRefreshInterval: "off",
          proxy: { mode: "custom", customUrl: "socks5://127.0.0.1:7890" },
        }}
        providers={[
          {
            id: "brave",
            displayName: "Brave",
            familyName: "Brave",
            category: "AI Search",
            icon: "brave",
            dashboardUrl: "https://api.search.brave.com/app/dashboard",
            supportsReauth: false,
            supportsRefresh: true,
            quotaCheckConsumesSearchQuota: true,
          },
        ]}
        credentials={[
          {
            id: "brave-low",
            providerId: "brave",
            name: "Brave Key",
            kind: "apiKey",
            maskedValue: "BSA••••82y2",
            copyable: true,
            active: true,
            status: "failed",
            remainingBadgeText: "Check failed",
            quotaWindows: [],
            resetAt: "2026-07-01T00:00:00+08:00",
            lastUpdated: "2026-06-11T10:02:00+08:00",
            lastHttpStatus: 429,
            diagnosticMessage: "Brave quota endpoint returned HTTP 429",
          },
        ]}
      />,
    );

    expect(screen.getByText("Diagnostic details")).toBeInTheDocument();
    expect(screen.getByText("Last HTTP status")).toBeInTheDocument();
    expect(screen.getByText("Request proxy mode")).toBeInTheDocument();
    expect(screen.getByText("Custom · socks5://127.0.0.1:7890")).toBeInTheDocument();
    expect(screen.getByText("Reset")).toBeInTheDocument();
    expect(screen.getByText("Automatic refresh")).toBeInTheDocument();
    expect(screen.getByText("Skipped unless costly refresh is enabled")).toBeInTheDocument();
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

  it("edits custom proxy URLs when custom proxy mode is selected", () => {
    const onSettingsChange = vi.fn();
    render(
      <SettingsPage
        settings={{
          ...mockSettings,
          proxy: { mode: "custom", customUrl: "socks5://127.0.0.1:7890" },
        }}
        onSettingsChange={onSettingsChange}
      />,
    );

    const input = screen.getByRole("textbox", { name: "Custom proxy URL" });
    expect(input).toHaveValue("socks5://127.0.0.1:7890");

    fireEvent.change(input, { target: { value: "http://127.0.0.1:8080" } });

    expect(onSettingsChange).toHaveBeenLastCalledWith(
      expect.objectContaining({
        proxy: { mode: "custom", customUrl: "http://127.0.0.1:8080" },
      }),
    );
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

  it("shows version and update status with an explicit update check action", () => {
    const onCheckForUpdates = vi.fn();

    render(
      <AboutPage
        updateState={{
          currentVersion: "0.4.0",
          latestVersion: "0.4.1",
          status: "available",
          releaseNotes: "Provider login fixes",
        }}
        onCheckForUpdates={onCheckForUpdates}
      />,
    );

    expect(screen.getByText("v0.4.0 preview")).toBeInTheDocument();
    expect(screen.getByText("Update 0.4.1 available")).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "Check for updates" }));

    expect(onCheckForUpdates).toHaveBeenCalledTimes(1);
  });
});
