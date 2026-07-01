import { Activity, Gauge, Info, KeyRound, SlidersHorizontal, Stethoscope } from "lucide-react";
import type { ReactNode } from "react";
import { AppMark } from "../components/AppMark";
import { useLocale, useTranslate } from "../i18n";
import { mockCredentials, providerRegistry } from "../shared/mockData";
import { buildMenuSummary, buildProviderStats } from "../shared/selectors";
import type { CredentialView, ProviderDefinition } from "../shared/types";
import type { UpdateState } from "../shared/types";
import { SidebarNavItem } from "./SidebarNavItem";
import { SidebarUpdateFooter } from "./SidebarUpdateFooter";

export type AppPage = "quota" | "credentials" | "diagnostics" | "settings" | "about";

interface SidebarProps {
  activePage?: AppPage;
  credentials?: CredentialView[];
  onNavigate?: (page: AppPage) => void;
  providers?: ProviderDefinition[];
  updateState?: UpdateState;
  onCheckForUpdates?: () => void;
}

export function Sidebar({
  activePage = "quota",
  credentials = mockCredentials,
  onNavigate,
  onCheckForUpdates,
  providers = providerRegistry,
  updateState,
}: SidebarProps) {
  const locale = useLocale();
  const t = useTranslate();
  const stats = buildProviderStats(providers, credentials, locale);
  const summary = buildMenuSummary(credentials);
  const navItems = [
    { id: "quota", label: t("quota.overviewTitle"), icon: <Gauge size={17} /> },
    { id: "credentials", label: t("nav.credentials"), icon: <KeyRound size={17} /> },
    { id: "diagnostics", label: t("nav.diagnostics"), icon: <Stethoscope size={17} /> },
    { id: "settings", label: t("nav.settings"), icon: <SlidersHorizontal size={17} /> },
    { id: "about", label: t("nav.about"), icon: <Info size={17} /> },
  ] satisfies Array<{ id: AppPage; label: string; icon: ReactNode }>;
  const statistics = [
    { label: t("sidebar.creds"), value: credentials.length },
    { label: t("sidebar.providers"), value: stats.length },
    { label: t("tray.low"), value: summary.lowCount, tone: summary.lowCount > 0 ? "attention" : "healthy" },
  ];

  return (
    <aside className="app-sidebar">
      <div className="app-brand">
        <AppMark testId="app-mark" />
        <div>
          <h1 className="app-brand-title">{t("app.name")}</h1>
          <span className="app-brand-subtitle">{t("app.subtitle")}</span>
        </div>
      </div>

      <nav className="sidebar-nav" aria-label={t("sidebar.primaryNavigation")}>
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

      <section className="sidebar-statistics" aria-label={t("sidebar.statistics")}>
        <h2>{t("sidebar.statistics")}</h2>
        <div className="sidebar-stat-list">
          {statistics.map((item) => (
            <div className="sidebar-stat-row" data-tone={item.tone} key={item.label}>
              <span>{item.label}</span>
              <strong>{item.value}</strong>
            </div>
          ))}
        </div>
      </section>

      <div className="sidebar-spacer" />
      <div className="sidebar-health">
        <Activity size={14} />
        <span>{t("sidebar.needAttention").replace("{count}", String(summary.failedCount + summary.lowCount))}</span>
      </div>
      <SidebarUpdateFooter onCheckForUpdates={onCheckForUpdates} updateState={updateState} />
    </aside>
  );
}
