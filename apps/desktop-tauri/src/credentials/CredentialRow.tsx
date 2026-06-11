import { Copy, Pencil } from "lucide-react";
import { StatusPill } from "../components/StatusPill";
import { credentialNeedsAttention } from "../shared/status";
import type { CredentialView } from "../shared/types";

interface CredentialRowProps {
  credential: CredentialView;
  onCopy?: (credential: CredentialView) => void;
}

function credentialKindLabel(kind: CredentialView["kind"]) {
  switch (kind) {
    case "dashboardCookie":
      return "Web Login";
    case "storedAPIKeyOnly":
      return "Companion Key";
    case "adminCredential":
      return "Management Credential";
    case "apiKey":
    default:
      return "API Key";
  }
}

export function CredentialRow({ credential, onCopy }: CredentialRowProps) {
  const statusTone = credentialNeedsAttention(credential) ? "attention" : "healthy";

  return (
    <div className="credential-row" data-testid={`credential-row-${credential.id}`}>
      <div className="credential-row-main">
        <span className="credential-dot" data-tone={statusTone} aria-hidden="true" />
        <div className="credential-row-text">
          <strong>{credential.name}</strong>
          <span>{credential.maskedValue}</span>
        </div>
        <span className="credential-kind-badge">{credentialKindLabel(credential.kind)}</span>
      </div>
      <div className="credential-row-actions" aria-label={`${credential.name} actions`}>
        <span className="credential-action-slot">
          <span data-testid="credential-action">Status</span>
          <StatusPill tone={statusTone} label={credential.status} />
        </span>
        <span className="credential-action-slot">
          <span data-testid="credential-action">Enabled</span>
          <span className="mock-switch" data-enabled={credential.active} aria-hidden="true" />
        </span>
        {credential.copyable ? (
          <span className="credential-action-slot">
            <span data-testid="credential-action">Copy</span>
            <button aria-label={`Copy ${credential.name}`} onClick={() => onCopy?.(credential)}>
              <Copy size={14} />
            </button>
          </span>
        ) : null}
        <span className="credential-action-slot">
          <span data-testid="credential-action">Edit</span>
          <button aria-label={`Edit ${credential.name}`}>
            <Pencil size={14} />
          </button>
        </span>
      </div>
    </div>
  );
}
