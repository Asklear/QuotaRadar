import { getCurrentWindow } from "@tauri-apps/api/window";

export function isTauriRuntime() {
  return "__TAURI_INTERNALS__" in window;
}

export async function hideCurrentTrayWindow() {
  if (!isTauriRuntime()) {
    return;
  }

  await getCurrentWindow().hide();
}
