import { useEffect, useState } from "react";
import {
  getAppState,
  getSettings,
  mockAppState,
  mockSettings,
  moveProvider,
  resetProviderOrder,
  updateSettings,
} from "./lib/tauriClient";
import { AppShell } from "./shell/AppShell";
import type { AppPage } from "./shell/Sidebar";
import { CredentialsPage } from "./pages/CredentialsPage";
import { DiagnosticsPage } from "./pages/DiagnosticsPage";
import { QuotaMonitoringPage } from "./pages/QuotaMonitoringPage";
import { SettingsPage } from "./pages/SettingsPage";
import { TrayPopover } from "./tray/TrayPopover";
import type { AppSettings, ProviderDefinition } from "./shared/types";

function orderProviders(providers: ProviderDefinition[], providerOrder: string[]) {
  const order = new Map(providerOrder.map((providerId, index) => [providerId, index]));

  return [...providers].sort((left, right) => {
    const leftIndex = order.get(left.id) ?? Number.MAX_SAFE_INTEGER;
    const rightIndex = order.get(right.id) ?? Number.MAX_SAFE_INTEGER;
    return leftIndex - rightIndex;
  });
}

export default function App() {
  const [activePage, setActivePage] = useState<AppPage>("quota");
  const [appState, setAppState] = useState(mockAppState);
  const [settings, setSettings] = useState(mockSettings);

  useEffect(() => {
    let cancelled = false;

    void Promise.all([getAppState(), getSettings()]).then(([state, loadedSettings]) => {
      if (!cancelled) {
        setAppState(state);
        setSettings(loadedSettings);
      }
    });

    return () => {
      cancelled = true;
    };
  }, []);

  const providers = orderProviders(appState.providers, settings.providerOrder);

  async function handleSettingsChange(nextSettings: AppSettings) {
    setSettings(nextSettings);
    setSettings(await updateSettings(nextSettings));
  }

  async function handleMoveProvider(providerId: string, toIndex: number) {
    const nextSettings = await moveProvider(providerId, toIndex);
    setSettings(nextSettings);
  }

  async function handleResetProviderOrder() {
    const nextSettings = await resetProviderOrder();
    setSettings(nextSettings);
  }

  if (new URLSearchParams(window.location.search).get("view") === "tray") {
    return (
      <main className="tray-preview">
        <TrayPopover credentials={appState.credentials} />
      </main>
    );
  }

  const page = {
    quota: <QuotaMonitoringPage providers={providers} credentials={appState.credentials} />,
    credentials: <CredentialsPage providers={providers} credentials={appState.credentials} />,
    diagnostics: <DiagnosticsPage providers={providers} credentials={appState.credentials} />,
    settings: (
      <SettingsPage
        settings={settings}
        onMoveProvider={handleMoveProvider}
        onResetProviderOrder={handleResetProviderOrder}
        onSettingsChange={handleSettingsChange}
      />
    ),
  }[activePage];

  return (
    <AppShell
      activePage={activePage}
      credentials={appState.credentials}
      onNavigate={setActivePage}
      providers={providers}
    >
      {page}
    </AppShell>
  );
}
