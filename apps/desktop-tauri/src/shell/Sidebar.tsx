import { Activity, Gauge, KeyRound, Radar, SlidersHorizontal, Stethoscope } from "lucide-react";
import { translate } from "../i18n";
import { mockCredentials, providerRegistry } from "../shared/mockData";
import { buildMenuSummary, buildProviderStats } from "../shared/selectors";
import { SidebarNavItem } from "./SidebarNavItem";
import { SidebarUpdateFooter } from "./SidebarUpdateFooter";

const navItems = [
  { label: translate("nav.quotaMonitoring"), icon: <Gauge size={17} /> },
  { label: translate("nav.credentials"), icon: <KeyRound size={17} /> },
  { label: translate("nav.diagnostics"), icon: <Stethoscope size={17} /> },
  { label: translate("nav.settings"), icon: <SlidersHorizontal size={17} /> },
];

export function Sidebar() {
  const stats = buildProviderStats(providerRegistry, mockCredentials);
  const summary = buildMenuSummary(mockCredentials);

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
        {navItems.map((item, index) => (
          <SidebarNavItem key={item.label} icon={item.icon} label={item.label} active={index === 0} />
        ))}
      </nav>

      <div className="sidebar-metrics" aria-label="Quota summary">
        <div className="sidebar-metric">
          <span>{mockCredentials.length}</span>
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
