import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { mockCredentials, providerRegistry } from "../shared/mockData";
import type {
  AppSettings,
  AppState,
  CapturedWebAuthorization,
  CredentialImportSummary,
  CredentialInput,
  CredentialUpdateInput,
  CredentialView,
  RefreshMode,
  UpdateState,
  WebAuthorizationFailure,
  WebAuthorizationSession,
} from "../shared/types";

export const mockAppState: AppState = {
  providers: providerRegistry,
  credentials: mockCredentials,
};

export const mockSettings: AppSettings = {
  language: "en",
  launchAtLogin: false,
  updateCheck: true,
  autoRefreshInterval: "off",
  costlyRefreshInterval: "off",
  proxy: {
    mode: "system",
  },
  trayTransparency: 82,
  providerOrder: providerRegistry.map((provider) => provider.id),
};

export const mockUpdateState: UpdateState = {
  currentVersion: "0.0.0",
  status: "upToDate",
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

export async function updateCredential(input: CredentialUpdateInput): Promise<CredentialView> {
  if (!isTauriRuntime()) {
    return buildMockCredential({
      ...input,
      secret: input.secret ?? input.name,
    });
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

export async function importClaudeSettings(): Promise<CredentialImportSummary> {
  if (!isTauriRuntime()) {
    return {
      added: 0,
      updated: 0,
      credentials: mockCredentials,
    };
  }

  return invoke<CredentialImportSummary>("import_claude_settings");
}

export async function refreshProvider(providerId: string, mode: RefreshMode = "manual"): Promise<AppState> {
  if (!isTauriRuntime()) {
    return mockAppState;
  }

  return invoke<AppState>("refresh_provider", { providerId, mode });
}

export async function startWebAuthorization(
  providerId: string,
  targetCredentialId?: string,
  targetName?: string,
): Promise<WebAuthorizationSession> {
  if (!isTauriRuntime()) {
    return {
      providerId,
      targetCredentialId,
      loginUrl: providerRegistry.find((provider) => provider.id === providerId)?.dashboardUrl,
      message: targetCredentialId
        ? `Ready to update ${targetCredentialId}`
        : "Choose an authorization target",
    };
  }

  return invoke<WebAuthorizationSession>(
    "start_web_authorization",
    targetName === undefined
      ? { providerId, targetCredentialId }
      : { providerId, targetCredentialId, targetName },
  );
}

export async function openExternalUrl(url?: string): Promise<void> {
  if (!url) {
    return;
  }

  if (isTauriRuntime()) {
    return invoke<void>("open_external_url", { url });
  }

  window.open(url, "_blank", "noopener,noreferrer");
}

export async function saveWebAuthorization(input: CapturedWebAuthorization): Promise<CredentialView> {
  if (!isTauriRuntime()) {
    return buildMockCredential({
      id: input.targetCredentialId ?? `${input.providerId}-web-authorization`,
      providerId: input.providerId,
      name: input.name ?? `${input.providerId} Web Login`,
      kind: "dashboardCookie",
      secret: JSON.stringify(input.capturedFields),
    });
  }

  return invoke<CredentialView>("save_web_authorization", { input });
}

export async function listenForWebAuthorizationSaved(
  onSaved: (credential: CredentialView) => void | Promise<void>,
): Promise<() => void> {
  if (!isTauriRuntime()) {
    return () => {};
  }

  return listen<CredentialView>("web_authorization_saved", (event) => {
    void onSaved(event.payload);
  });
}

export async function listenForWebAuthorizationFailed(
  onFailed: (failure: WebAuthorizationFailure) => void | Promise<void>,
): Promise<() => void> {
  if (!isTauriRuntime()) {
    return () => {};
  }

  return listen<WebAuthorizationFailure>("web_authorization_failed", (event) => {
    void onFailed(event.payload);
  });
}

export async function getUpdateState(): Promise<UpdateState> {
  if (!isTauriRuntime()) {
    return mockUpdateState;
  }

  return invoke<UpdateState>("get_update_state");
}

export async function checkForUpdates(): Promise<UpdateState> {
  if (!isTauriRuntime()) {
    return mockUpdateState;
  }

  return invoke<UpdateState>("check_for_updates");
}

export async function downloadAndInstallUpdate(): Promise<UpdateState> {
  if (!isTauriRuntime()) {
    return {
      ...mockUpdateState,
      status: "notImplemented",
      errorMessage: "Tauri desktop signed update artifacts are not configured yet.",
    };
  }

  return invoke<UpdateState>("download_and_install_update");
}

function buildMockCredential(input: CredentialInput & { active?: boolean }): CredentialView {
  const copyable = input.kind !== "dashboardCookie";
  const maskedValue = copyable ? maskSecret(input.secret) : "Web login authorization saved";

  return {
    id: input.id,
    providerId: input.providerId,
    name: input.name,
    kind: input.kind,
    maskedValue,
    copyable,
    active: input.active ?? true,
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
