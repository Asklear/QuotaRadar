import { useTranslate } from "../i18n";
import type { MenuSummary } from "../shared/types";

interface RiskSummaryCardProps {
  summary: MenuSummary;
}

export function RiskSummaryCard({ summary }: RiskSummaryCardProps) {
  const t = useTranslate();

  return (
    <section className="risk-card monitor-module" aria-label="Risk summary">
      <div className="risk-card-item" data-tone="attention">
        <span>{summary.lowCount}</span>
        <small>{t("tray.low")}</small>
      </div>
      <div className="risk-card-item" data-tone="attention">
        <span>{summary.failedCount}</span>
        <small>{t("tray.failed")}</small>
      </div>
      <div className="risk-card-item" data-tone="healthy">
        <span>{summary.availableCount}</span>
        <small>{t("tray.available")}</small>
      </div>
    </section>
  );
}
