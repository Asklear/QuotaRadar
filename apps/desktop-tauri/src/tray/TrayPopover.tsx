import { AttentionList } from "./AttentionList";
import { RiskSummaryCard } from "./RiskSummaryCard";
import { TrayHeader } from "./TrayHeader";
import { hideCurrentTrayWindow } from "../lib/platform";
import { mockCredentials } from "../shared/mockData";
import { buildMenuSummary } from "../shared/selectors";
import type { CredentialView } from "../shared/types";

interface TrayPopoverProps {
  credentials?: CredentialView[];
  onRequestClose?: () => void;
}

export function TrayPopover({
  credentials = mockCredentials,
  onRequestClose = () => {
    void hideCurrentTrayWindow();
  },
}: TrayPopoverProps) {
  const summary = buildMenuSummary(credentials);

  return (
    <div
      className="tray-popover"
      data-testid="tray-popover"
      onPointerLeave={onRequestClose}
      style={{ width: "var(--qr-tray-width)", height: "var(--qr-tray-height)" }}
    >
      <TrayHeader />
      <RiskSummaryCard summary={summary} />
      <AttentionList credentials={credentials} />
    </div>
  );
}
