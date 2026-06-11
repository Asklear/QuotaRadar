import { Activity, Gauge, KeyRound, Radar, SlidersHorizontal, Stethoscope } from "lucide-react";
import type { ReactNode } from "react";
import { translate } from "../i18n";
import { mockCredentials, providerRegistry } from "../shared/mockData";
import { buildMenuSummary, buildProviderStats } from "../shared/selectors";
import type { CredentialView, ProviderDefinition } from "../shared/types";
import { SidebarNavItem } from "./SidebarNavItem";
import { SidebarUpdateFooter } from "./SidebarUpdateFooter";

export type AppPage = "quota" | "credentials" | "diagnostics" | "settings";

const navItems = [
  { id: "quota", label: translate("nav.quotaMonitoring"), icon: <Gauge size={17} /> },
  { id: "credentials", label: translate("nav.credentials"), icon: <KeyRound size={17} /> },
  { id: "diagnostics", label: translate("nav.diagnostics"), icon: <Stethoscope size={17} /> },
  { id: "settings", label: translate("nav.settings"), icon: <SlidersHorizontal size={17} /> },
] satisfies Array<{ id: AppPage; label: string; icon: ReactNode }>;

interface SidebarProps {
  activePage?: AppPage;
  credentials?: CredentialView[];
  onNavigate?: (page: AppPage) => void;
  providers?: ProviderDefinition[];
}

export function Sidebar({
  activePage = "quota",
  credentials = mockCredentials,
  onNavigate,
  providers = providerRegistry,
}: SidebarProps) {
  const stats = buildProviderStats(providers, credentials);
  const summary = buildMenuSummary(credentials);

  return (
    <aside className="app-sidebar">
      <div className="app-brand">
        <div className="app-mark" aria-hidden="true">
          <Radar size={23} strokeWidth={2.2} />
        </div>
        <div>
          <h1 className="app-brand-title">{translate("app.name")}</h1>
          <span className="app-brand-subtitle">{translate("app.subtitle")}</span>
        </div>
      </div>

      <nav className="sidebar-nav" aria-label="Primary">
        {navItems.map((item) => (
          <SidebarNavItem
            key={item.id}
            icon={item.icon}
            label={item.label}
            active={activePage === item.id}
            onClick={() => onNavigate?.(item.id)}
          />
        ))}
      </nav>

      <div className="sidebar-metrics" aria-label="Quota summary">
        <div className="sidebar-metric">
          <span>{credentials.length}</span>
          <small>Creds</small>
        </div>
        <div className="sidebar-metric">
          <span>{stats.length}</span>
          <small>Providers</small>
        </div>
        <div className="sidebar-metric" data-tone={summary.lowCount > 0 ? "attention" : "healthy"}>
          <span>{summary.lowCount}</span>
          <small>Low</small>
        </div>
      </div>

      <div className="sidebar-spacer" />
      <div className="sidebar-health">
        <Activity size={14} />
        <span>{summary.failedCount + summary.lowCount} need attention</span>
      </div>
      <SidebarUpdateFooter />
    </aside>
  );
}
