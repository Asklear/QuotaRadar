import { useEffect, useState } from "react";
import {
  getAppState,
  getSettings,
  getUpdateState,
  listenForMainWindowNavigation,
  listenForWebAuthorizationFailed,
  listenForWebAuthorizationSaved,
  mockAppState,
  mockSettings,
  mockUpdateState,
  moveProvider,
  openMainWindow,
  refreshProvider,
  resetCodexQuota,
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
import { AboutPage } from "./pages/AboutPage";
import { TrayPopover } from "./tray/TrayPopover";
import type {
  AppSettings,
  AppState,
  CredentialView,
  MainWindowTarget,
  ProviderDefinition,
  WebAuthorizationSession,
} from "./shared/types";
import {
  formatSystemDisplayText,
  LocaleContext,
  normalizeLocale,
  translate,
  type LocaleCode,
} from "./i18n";

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
  const [webAuthorizationAlertState, setWebAuthorizationAlertState] =
    useState<WebAuthorizationAlertState>();
  const [manualRefreshFailure, setManualRefreshFailure] = useState<ProviderRefreshFailure>();
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
        if (!isTrayView) {
          refreshError = webAuthorizationRefreshFailureMessage(state, credential.providerId);
        }
      } catch (error) {
        state = await getAppState();
        refreshError = `Saved authorization, but quota refresh failed: ${errorMessage(error)}`;
      }
      if (!cancelled) {
        setWebAuthorizationAlertState(
          refreshError ? { kind: "savedRefreshFailure", message: refreshError } : undefined,
        );
        setManualRefreshFailure(undefined);
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

    void listenForMainWindowNavigation((target) => {
      if (!cancelled && target.page && isAppPage(target.page)) {
        setActivePage(target.page);
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
        setWebAuthorizationAlertState({
          kind: "authorizationFailure",
          message: failure.message,
        });
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
    setManualRefreshFailure(undefined);
    setWebAuthorizationAlertState(undefined);
    const state = await refreshProvider(providerId, "manual");
    setAppState(state);
    setManualRefreshFailure(providerRefreshFailure(state, providerId));
  }

  async function handleResetCodexQuota(credentialId: string) {
    setManualRefreshFailure(undefined);
    setWebAuthorizationAlertState(undefined);
    try {
      const state = await resetCodexQuota(credentialId);
      setAppState(state);
      setManualRefreshFailure(providerRefreshFailure(state, "codex"));
    } catch (error) {
      setManualRefreshFailure({
        providerName: "Codex",
        message: errorMessage(error),
      });
    }
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
    setWebAuthorizationAlertState(undefined);
    setManualRefreshFailure(undefined);
    return startWebAuthorization(providerId, targetCredentialId, targetName);
  }

  if (isTrayView) {
    return (
      <LocaleContext.Provider value={locale}>
        <main className="tray-preview">
          <TrayPopover
            credentials={appState.credentials}
            onOpenMainWindow={(target) => {
              void openMainWindow(target);
            }}
          />
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
        onResetCodexQuota={handleResetCodexQuota}
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
    diagnostics: (
      <DiagnosticsPage providers={providers} credentials={appState.credentials} settings={settings} />
    ),
    settings: (
      <SettingsPage
        settings={settings}
        onMoveProvider={handleMoveProvider}
        onResetProviderOrder={handleResetProviderOrder}
        onSettingsChange={handleSettingsChange}
      />
    ),
    about: <AboutPage updateState={updateState} onCheckForUpdates={handleCheckForUpdates} />,
  }[activePage];
  const webAuthorizationAlert = webAuthorizationAlertState
    ? formatWebAuthorizationAlert(webAuthorizationAlertState, locale)
    : undefined;
  const manualRefreshAlert = manualRefreshFailure
    ? translate("app.providerRefreshFailed", locale)
        .replace("{provider}", manualRefreshFailure.providerName)
        .replace(
          "{message}",
          formatSystemDisplayText(manualRefreshFailure.message, (key) => translate(key, locale)),
        )
    : undefined;
  const appAlert = webAuthorizationAlert ?? manualRefreshAlert;

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
        {appAlert ? (
          <div className="app-alert" data-tone="error" role="alert">
            {appAlert}
          </div>
        ) : null}
        {page}
      </AppShell>
    </LocaleContext.Provider>
  );
}

interface ProviderRefreshFailure {
  providerName: string;
  message: string;
}

interface WebAuthorizationAlertState {
  kind: "authorizationFailure" | "savedRefreshFailure";
  message: string;
}

function formatWebAuthorizationAlert(state: WebAuthorizationAlertState, locale: LocaleCode) {
  const message = formatSystemDisplayText(state.message, (key) => translate(key, locale));
  return state.kind === "savedRefreshFailure"
    ? message
    : `${translate("app.webAuthorizationFailed", locale)} ${message}`;
}

function providerRefreshFailure(state: AppState, providerId: string): ProviderRefreshFailure | undefined {
  const failedCredential = state.credentials.find(
    (credential) =>
      credential.providerId === providerId &&
      credential.active &&
      credential.status === "failed" &&
      credential.diagnosticMessage,
  );
  if (!failedCredential?.diagnosticMessage) {
    return undefined;
  }

  const providerName =
    state.providers.find((provider) => provider.id === providerId)?.displayName ?? providerId;
  return {
    providerName,
    message: failedCredential.diagnosticMessage,
  };
}

function providerRefreshFailureMessage(state: AppState, providerId: string) {
  return providerRefreshFailure(state, providerId)?.message;
}

function webAuthorizationRefreshFailureMessage(state: AppState, providerId: string) {
  const message = providerRefreshFailureMessage(state, providerId);
  return message ? `Saved authorization, but quota refresh failed: ${message}` : undefined;
}

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : String(error);
}

function isAppPage(value: MainWindowTarget["page"]): value is NonNullable<MainWindowTarget["page"]> {
  return ["quota", "credentials", "diagnostics", "settings", "about"].includes(String(value));
}
