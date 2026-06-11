import { invoke } from "@tauri-apps/api/core";
import { mockCredentials, providerRegistry } from "../shared/mockData";
import type { AppState } from "../shared/types";

export const mockAppState: AppState = {
  providers: providerRegistry,
  credentials: mockCredentials,
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
