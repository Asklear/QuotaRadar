import { invoke } from "@tauri-apps/api/core";
import { mockCredentials, providerRegistry } from "../shared/mockData";
import type { AppSettings, AppState } from "../shared/types";

export const mockAppState: AppState = {
  providers: providerRegistry,
  credentials: mockCredentials,
};

export const mockSettings: AppSettings = {
  language: "en",
  launchAtLogin: true,
  updateCheck: true,
  autoRefreshInterval: "off",
  costlyRefreshInterval: "off",
  proxy: {
    mode: "system",
  },
  trayTransparency: 82,
  providerOrder: providerRegistry.map((provider) => provider.id),
};

function isTauriRuntime() {
  return Boolean((window as Window & { __TAURI_INTERNALS__?: unknown }).__TAURI_INTERNALS__);
}

export async function getAppState(): Promise<AppState> {
  if (!isTauriRuntime()) {
    return mockAppState;
  }

  return invoke<AppState>("get_app_state");
}

export async function getSettings(): Promise<AppSettings> {
  if (!isTauriRuntime()) {
    return mockSettings;
  }

  return invoke<AppSettings>("get_settings");
}

export async function updateSettings(settings: AppSettings): Promise<AppSettings> {
  if (!isTauriRuntime()) {
    return settings;
  }

  return invoke<AppSettings>("update_settings", { settings });
}

export async function moveProvider(providerId: string, toIndex: number): Promise<AppSettings> {
  if (!isTauriRuntime()) {
    if (!mockSettings.providerOrder.includes(providerId)) {
      return mockSettings;
    }

    const providerOrder = mockSettings.providerOrder.filter((id) => id !== providerId);
    providerOrder.splice(Math.min(toIndex, providerOrder.length), 0, providerId);
    return { ...mockSettings, providerOrder };
  }

  return invoke<AppSettings>("move_provider", { providerId, toIndex });
}

export async function resetProviderOrder(): Promise<AppSettings> {
  if (!isTauriRuntime()) {
    return mockSettings;
  }

  return invoke<AppSettings>("reset_provider_order");
}
