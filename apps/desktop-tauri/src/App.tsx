import { useEffect, useState } from "react";
import {
  getAppState,
  getSettings,
  getUpdateState,
  listenForWebAuthorizationSaved,
  mockAppState,
  mockSettings,
  mockUpdateState,
  moveProvider,
  refreshProvider,
  resetProviderOrder,
  checkForUpdates,
  startWebAuthorization,
  updateSettings,
} from "./lib/tauriClient";
import { AppShell } from "./shell/AppShell";
import type { AppPage } from "./shell/Sidebar";
import { CredentialsPage } from "./pages/CredentialsPage";
import { DiagnosticsPage } from "./pages/DiagnosticsPage";
import { QuotaMonitoringPage } from "./pages/QuotaMonitoringPage";
import { SettingsPage } from "./pages/SettingsPage";
import { TrayPopover } from "./tray/TrayPopover";
import type { AppSettings, ProviderDefinition, WebAuthorizationSession } from "./shared/types";
import { LocaleContext, normalizeLocale } from "./i18n";

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
  const [updateState, setUpdateState] = useState(mockUpdateState);
  const isTrayView = new URLSearchParams(window.location.search).get("view") === "tray";

  useEffect(() => {
    let cancelled = false;

    void Promise.all([getAppState(), getSettings(), getUpdateState()]).then(([state, loadedSettings, loadedUpdateState]) => {
      if (!cancelled) {
        setAppState(state);
        setSettings(loadedSettings);
        setUpdateState(loadedUpdateState);
      }
    });

    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    let cancelled = false;
    let unsubscribe: (() => void) | undefined;

    void listenForWebAuthorizationSaved(async () => {
      const state = await getAppState();
      if (!cancelled) {
        setAppState(state);
      }
    }).then((listener) => {
      unsubscribe = listener;
      if (cancelled) {
        unsubscribe();
      }
    });

    return () => {
      cancelled = true;
      unsubscribe?.();
    };
  }, []);

  useEffect(() => {
    document.body.dataset.qrView = isTrayView ? "tray" : "main";

    return () => {
      delete document.body.dataset.qrView;
    };
  }, [isTrayView]);

  const providers = orderProviders(appState.providers, settings.providerOrder);
  const locale = normalizeLocale(settings.language);

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

  async function handleCheckForUpdates() {
    setUpdateState((current) => ({ ...current, status: "checking" }));
    setUpdateState(await checkForUpdates());
  }

  async function handleRefreshProvider(providerId: string) {
    setAppState(await refreshProvider(providerId, "manual"));
  }

  async function handleStartWebAuthorization(
    providerId: string,
    targetCredentialId?: string,
  ): Promise<WebAuthorizationSession> {
    return startWebAuthorization(providerId, targetCredentialId);
  }

  if (isTrayView) {
    return (
      <LocaleContext.Provider value={locale}>
        <main className="tray-preview">
          <TrayPopover credentials={appState.credentials} />
        </main>
      </LocaleContext.Provider>
    );
  }

  const page = {
    quota: (
      <QuotaMonitoringPage
        providers={providers}
        credentials={appState.credentials}
        onRefreshProvider={handleRefreshProvider}
        onStartWebAuthorization={handleStartWebAuthorization}
      />
    ),
    credentials: (
      <CredentialsPage
        providers={providers}
        credentials={appState.credentials}
        onStartWebAuthorization={handleStartWebAuthorization}
      />
    ),
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
    <LocaleContext.Provider value={locale}>
      <AppShell
        activePage={activePage}
        credentials={appState.credentials}
        onCheckForUpdates={handleCheckForUpdates}
        onNavigate={setActivePage}
        providers={providers}
        updateState={updateState}
      >
        {page}
      </AppShell>
    </LocaleContext.Provider>
  );
}
