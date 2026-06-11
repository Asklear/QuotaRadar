import { AppShell } from "./shell/AppShell";
import { QuotaMonitoringPage } from "./pages/QuotaMonitoringPage";
import { TrayPopover } from "./tray/TrayPopover";

export default function App() {
  if (new URLSearchParams(window.location.search).get("view") === "tray") {
    return (
      <main className="tray-preview">
        <TrayPopover />
      </main>
    );
  }

  return (
    <AppShell>
      <QuotaMonitoringPage />
    </AppShell>
  );
}
