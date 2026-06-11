import { translate } from "../i18n";
import type { MenuSummary } from "../shared/types";

interface RiskSummaryCardProps {
  summary: MenuSummary;
}

export function RiskSummaryCard({ summary }: RiskSummaryCardProps) {
  return (
    <section className="risk-card" aria-label="Risk summary">
      <div className="risk-card-item" data-tone="attention">
        <span>{summary.lowCount}</span>
        <small>{translate("tray.low")}</small>
      </div>
      <div className="risk-card-item" data-tone="attention">
        <span>{summary.failedCount}</span>
        <small>{translate("tray.failed")}</small>
      </div>
      <div className="risk-card-item" data-tone="healthy">
        <span>{summary.availableCount}</span>
        <small>{translate("tray.available")}</small>
      </div>
    </section>
  );
}
