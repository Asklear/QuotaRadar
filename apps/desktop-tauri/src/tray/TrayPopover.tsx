import { AttentionList } from "./AttentionList";
import { RiskSummaryCard } from "./RiskSummaryCard";
import { TrayHeader } from "./TrayHeader";
import { mockCredentials } from "../shared/mockData";
import { buildMenuSummary } from "../shared/selectors";
import type { CredentialView } from "../shared/types";

interface TrayPopoverProps {
  credentials?: CredentialView[];
}

export function TrayPopover({ credentials = mockCredentials }: TrayPopoverProps) {
  const summary = buildMenuSummary(credentials);

  return (
    <div
      className="tray-popover"
      data-testid="tray-popover"
      style={{ width: "var(--qr-tray-width)", height: "var(--qr-tray-height)" }}
    >
      <TrayHeader />
      <RiskSummaryCard summary={summary} />
      <AttentionList credentials={credentials} />
    </div>
  );
}
