import { useEffect, useState } from "react";
import {
  getAppState,
  getSettings,
  getUpdateState,
  listenForWebAuthorizationFailed,
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
import type { AppSettings, CredentialView, ProviderDefinition, WebAuthorizationSession } from "./shared/types";
import { formatSystemDisplayText, LocaleContext, normalizeLocale, translate } from "./i18n";

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
  const [webAuthorizationError, setWebAuthorizationError] = useState<string | undefined>();
  const [lastWebAuthorizationSaved, setLastWebAuthorizationSaved] = useState<CredentialView>();
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

    void listenForWebAuthorizationSaved(async (credential) => {
      let state;
      let refreshError: string | undefined;
      try {
        state = isTrayView
          ? await getAppState()
          : await refreshProvider(credential.providerId, "manual");
      } catch (error) {
        state = await getAppState();
        refreshError = `Saved authorization, but quota refresh failed: ${errorMessage(error)}`;
      }
      if (!cancelled) {
        setWebAuthorizationError(refreshError);
        setAppState(state);
        setLastWebAuthorizationSaved(credential);
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
    let cancelled = false;
    let unsubscribe: (() => void) | undefined;

    void listenForWebAuthorizationFailed((failure) => {
      if (!cancelled) {
        setWebAuthorizationError(failure.message);
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

  function handleCredentialsChanged(credentials: CredentialView[]) {
    setAppState((currentState) => ({
      ...currentState,
      credentials,
    }));
  }

  async function handleStartWebAuthorization(
    providerId: string,
    targetCredentialId?: string,
    targetName?: string,
  ): Promise<WebAuthorizationSession> {
    setWebAuthorizationError(undefined);
    return startWebAuthorization(providerId, targetCredentialId, targetName);
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
        lastWebAuthorizationSaved={lastWebAuthorizationSaved}
        onCredentialsChanged={handleCredentialsChanged}
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
  const webAuthorizationAlert = webAuthorizationError
    ? `${translate("app.webAuthorizationFailed", locale)} ${formatSystemDisplayText(
        webAuthorizationError,
        (key) => translate(key, locale),
      )}`
    : undefined;

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
        {webAuthorizationAlert ? (
          <div className="app-alert" data-tone="error" role="alert">
            {webAuthorizationAlert}
          </div>
        ) : null}
        {page}
      </AppShell>
    </LocaleContext.Provider>
  );
}

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : String(error);
}
