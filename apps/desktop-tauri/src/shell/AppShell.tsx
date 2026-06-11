import type { ReactNode } from "react";
import { Sidebar } from "./Sidebar";

interface AppShellProps {
  children?: ReactNode;
}

export function AppShell({ children }: AppShellProps) {
  return (
    <div className="app-shell">
      <Sidebar />
      <main className="app-main">
        {children ?? (
          <section className="app-panel">
            <h2 className="page-title">Quota Monitoring</h2>
            <p className="page-subtitle">Mock desktop shell ready for quota pages.</p>
          </section>
        )}
      </main>
    </div>
  );
}
