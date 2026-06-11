import { invoke } from "@tauri-apps/api/core";
import { mockCredentials, providerRegistry } from "../shared/mockData";
import type { AppSettings, AppState, CredentialInput, CredentialView } from "../shared/types";

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

export function isTauriRuntime() {
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

export async function listCredentials(): Promise<CredentialView[]> {
  if (!isTauriRuntime()) {
    return mockCredentials;
  }

  return invoke<CredentialView[]>("list_credentials");
}

export async function createCredential(input: CredentialInput): Promise<CredentialView> {
  if (!isTauriRuntime()) {
    return buildMockCredential(input);
  }

  return invoke<CredentialView>("create_credential", { input });
}

export async function updateCredential(input: CredentialInput): Promise<CredentialView> {
  if (!isTauriRuntime()) {
    return buildMockCredential(input);
  }

  return invoke<CredentialView>("update_credential", { input });
}

export async function deleteCredential(credentialId: string): Promise<CredentialView[]> {
  if (!isTauriRuntime()) {
    return mockCredentials.filter((credential) => credential.id !== credentialId);
  }

  return invoke<CredentialView[]>("delete_credential", { credentialId });
}

export async function setCredentialActive(credentialId: string, active: boolean): Promise<CredentialView> {
  if (!isTauriRuntime()) {
    const credential = mockCredentials.find((item) => item.id === credentialId);
    if (!credential) {
      throw new Error("Credential was not found");
    }
    return { ...credential, active };
  }

  return invoke<CredentialView>("set_credential_active", { credentialId, active });
}

export async function copyCredentialValue(credentialId: string): Promise<string> {
  if (!isTauriRuntime()) {
    const credential = mockCredentials.find((item) => item.id === credentialId);
    if (!credential) {
      throw new Error("Credential was not found");
    }
    if (!credential.copyable) {
      throw new Error("Credential value is not copyable");
    }
    return credential.maskedValue;
  }

  return invoke<string>("copy_credential_value", { credentialId });
}

function buildMockCredential(input: CredentialInput): CredentialView {
  const copyable = input.kind !== "dashboardCookie";
  const maskedValue = copyable ? maskSecret(input.secret) : "Web login authorization saved";

  return {
    id: input.id,
    providerId: input.providerId,
    name: input.name,
    kind: input.kind,
    maskedValue,
    copyable,
    active: true,
    status: "notChecked",
    remainingBadgeText: input.kind === "dashboardCookie" ? "Authorization saved" : "Saved",
    quotaWindows: [],
    note: input.note,
    linkedAuthorizationId: input.linkedAuthorizationId,
  };
}

function maskSecret(secret: string) {
  if (secret.length <= 8) {
    return "••••";
  }

  return `${secret.slice(0, 4)}••••${secret.slice(-4)}`;
}
