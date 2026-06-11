import { useEffect, useState } from "react";
import { getAppState, mockAppState } from "./lib/tauriClient";
import { AppShell } from "./shell/AppShell";
import type { AppPage } from "./shell/Sidebar";
import { CredentialsPage } from "./pages/CredentialsPage";
import { DiagnosticsPage } from "./pages/DiagnosticsPage";
import { QuotaMonitoringPage } from "./pages/QuotaMonitoringPage";
import { SettingsPage } from "./pages/SettingsPage";
import { TrayPopover } from "./tray/TrayPopover";

export default function App() {
  const [activePage, setActivePage] = useState<AppPage>("quota");
  const [appState, setAppState] = useState(mockAppState);

  useEffect(() => {
    let cancelled = false;

    void getAppState().then((state) => {
      if (!cancelled) {
        setAppState(state);
      }
    });

    return () => {
      cancelled = true;
    };
  }, []);

  if (new URLSearchParams(window.location.search).get("view") === "tray") {
    return (
      <main className="tray-preview">
        <TrayPopover credentials={appState.credentials} />
      </main>
    );
  }

  const page = {
    quota: <QuotaMonitoringPage providers={appState.providers} credentials={appState.credentials} />,
    credentials: <CredentialsPage providers={appState.providers} credentials={appState.credentials} />,
    diagnostics: <DiagnosticsPage providers={appState.providers} credentials={appState.credentials} />,
    settings: <SettingsPage />,
  }[activePage];

  return (
    <AppShell
      activePage={activePage}
      credentials={appState.credentials}
      onNavigate={setActivePage}
      providers={appState.providers}
    >
      {page}
    </AppShell>
  );
}
