import { AttentionList } from "./AttentionList";
import { RiskSummaryCard } from "./RiskSummaryCard";
import { TrayHeader } from "./TrayHeader";
import { hideCurrentTrayWindow } from "../lib/platform";
import { mockCredentials } from "../shared/mockData";
import { buildMenuSummary } from "../shared/selectors";
import type { CredentialView, MainWindowTarget } from "../shared/types";

interface TrayPopoverProps {
  credentials?: CredentialView[];
  onOpenMainWindow?: (target: MainWindowTarget) => void | Promise<void>;
  onRequestClose?: () => void;
}

export function TrayPopover({
  credentials = mockCredentials,
  onOpenMainWindow,
  onRequestClose = () => {
    void hideCurrentTrayWindow();
  },
}: TrayPopoverProps) {
  const summary = buildMenuSummary(credentials);
  function openMain(target: MainWindowTarget) {
    void onOpenMainWindow?.(target);
    onRequestClose();
  }

  return (
    <div
      className="tray-popover"
      data-testid="tray-popover"
      data-style="native-popover"
      onPointerLeave={onRequestClose}
      style={{ width: "var(--qr-tray-width)", height: "var(--qr-tray-height)" }}
    >
      <TrayHeader onOpenSettings={() => openMain({ page: "settings" })} />
      <RiskSummaryCard summary={summary} />
      <AttentionList
        credentials={credentials}
        onOpenCredential={(credential) =>
          openMain({
            page: "quota",
            providerId: credential.providerId,
            credentialId: credential.id,
          })
        }
      />
    </div>
  );
}
