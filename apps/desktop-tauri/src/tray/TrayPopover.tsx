import { AttentionList } from "./AttentionList";
import { RiskSummaryCard } from "./RiskSummaryCard";
import { TrayHeader } from "./TrayHeader";
import { mockCredentials } from "../shared/mockData";
import { buildMenuSummary } from "../shared/selectors";

export function TrayPopover() {
  const summary = buildMenuSummary(mockCredentials);

  return (
    <div
      className="tray-popover"
      data-testid="tray-popover"
      style={{ width: "var(--qr-tray-width)", height: "var(--qr-tray-height)" }}
    >
      <TrayHeader />
      <RiskSummaryCard summary={summary} />
      <AttentionList credentials={mockCredentials} />
    </div>
  );
}
