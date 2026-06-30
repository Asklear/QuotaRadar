import { Copy, Pencil } from "lucide-react";
import { StatusPill } from "../components/StatusPill";
import {
  formatCredentialKind,
  formatCredentialStatus,
  formatSystemDisplayText,
  useTranslate,
} from "../i18n";
import { credentialNeedsAttention } from "../shared/status";
import type { CredentialView } from "../shared/types";

interface CredentialRowProps {
  credential: CredentialView;
  onCopy?: (credential: CredentialView) => void;
  onEdit?: (credential: CredentialView) => void;
}

export function CredentialRow({ credential, onCopy, onEdit }: CredentialRowProps) {
  const t = useTranslate();
  const statusTone = credentialNeedsAttention(credential) ? "attention" : "healthy";

  return (
    <div className="credential-row" data-testid={`credential-row-${credential.id}`}>
      <div className="credential-row-main">
        <span className="credential-dot" data-tone={statusTone} aria-hidden="true" />
        <div className="credential-row-text">
          <strong>{credential.name}</strong>
          <span>{formatSystemDisplayText(credential.maskedValue, t)}</span>
        </div>
        <span className="credential-kind-badge">{formatCredentialKind(credential.kind, t)}</span>
      </div>
      <div className="credential-row-actions" aria-label={`${credential.name} actions`}>
        <span className="credential-action-slot">
          <span data-testid="credential-action">{t("credential.action.status")}</span>
          <StatusPill tone={statusTone} label={formatCredentialStatus(credential.status, t)} />
        </span>
        <span className="credential-action-slot">
          <span data-testid="credential-action">{t("credential.action.enabled")}</span>
          <span className="mock-switch" data-enabled={credential.active} aria-hidden="true" />
        </span>
        {credential.copyable ? (
          <span className="credential-action-slot">
            <span data-testid="credential-action">{t("credential.action.copy")}</span>
            <button aria-label={`${t("credential.action.copy")} ${credential.name}`} onClick={() => onCopy?.(credential)}>
              <Copy size={14} />
            </button>
          </span>
        ) : null}
        <span className="credential-action-slot">
          <span data-testid="credential-action">{t("credential.action.edit")}</span>
          <button
            aria-label={`${t("credential.action.edit")} ${credential.name}`}
            onClick={() => onEdit?.(credential)}
          >
            <Pencil size={14} />
          </button>
        </span>
      </div>
    </div>
  );
}
