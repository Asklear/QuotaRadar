import { invoke } from "@tauri-apps/api/core";
import { render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import {
  checkForUpdates,
  downloadAndInstallUpdate,
  getUpdateState,
  mockSettings,
  updateSettings,
} from "../../src/lib/tauriClient";
import { SidebarUpdateFooter } from "../../src/shell/SidebarUpdateFooter";
import type { AppSettings, UpdateState } from "../../src/shared/types";

vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn(),
}));

function setTauriRuntime(enabled: boolean) {
  if (enabled) {
    Object.defineProperty(window, "__TAURI_INTERNALS__", {
      value: {},
      configurable: true,
    });
    return;
  }

  Reflect.deleteProperty(window, "__TAURI_INTERNALS__");
}

describe("update and refresh settings commands", () => {
  afterEach(() => {
    vi.mocked(invoke).mockReset();
    vi.unstubAllEnvs();
    setTauriRuntime(false);
  });

  it("loads update state and renders it in the sidebar footer", async () => {
    setTauriRuntime(true);
    const updateState: UpdateState = {
      currentVersion: "0.0.0",
      latestVersion: "0.1.0",
      status: "available",
      releaseNotes: "Credential storage preview",
    };
    vi.mocked(invoke).mockResolvedValue(updateState);

    const state = await getUpdateState();
    render(<SidebarUpdateFooter updateState={state} />);

    expect(invoke).toHaveBeenCalledWith("get_update_state");
    expect(screen.getByText("v0.0.0 preview")).toBeInTheDocument();
    expect(screen.getByText("Update 0.1.0 available")).toBeInTheDocument();
  });

  it("renders the desktop build label when provided", () => {
    vi.stubEnv("VITE_QUOTARADAR_BUILD_LABEL", "local-win-qa-20260627");

    render(<SidebarUpdateFooter updateState={{ currentVersion: "0.0.0", status: "upToDate" }} />);

    expect(screen.getByText("local-win-qa-20260627")).toBeInTheDocument();
  });

  it("checks for updates and keeps install as an explicit command", async () => {
    setTauriRuntime(true);
    vi.mocked(invoke)
      .mockResolvedValueOnce({ currentVersion: "0.0.0", status: "upToDate" })
      .mockResolvedValueOnce({
        currentVersion: "0.0.0",
        status: "notImplemented",
        errorMessage: "Tauri desktop signed update artifacts are not configured yet.",
      });

    await checkForUpdates();
    await downloadAndInstallUpdate();

    expect(invoke).toHaveBeenNthCalledWith(1, "check_for_updates");
    expect(invoke).toHaveBeenNthCalledWith(2, "download_and_install_update");
  });

  it("accepts system, direct, and custom proxy modes through settings", async () => {
    setTauriRuntime(true);
    const modes: AppSettings["proxy"]["mode"][] = ["system", "direct", "custom"];

    for (const mode of modes) {
      const settings: AppSettings = {
        ...mockSettings,
        proxy: {
          mode,
          customUrl: mode === "custom" ? "socks5://127.0.0.1:7890" : undefined,
        },
      };
      vi.mocked(invoke).mockResolvedValueOnce(settings);

      const saved = await updateSettings(settings);

      expect(saved.proxy.mode).toBe(mode);
    }

    expect(invoke).toHaveBeenCalledTimes(3);
  });
});
