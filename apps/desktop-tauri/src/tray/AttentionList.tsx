import { translate } from "../i18n";
import {
  credentialNeedsAttention,
  credentialPercentRemaining,
  isAttentionStatus,
  isLowCredential,
} from "../shared/status";
import type { CredentialView } from "../shared/types";

interface AttentionListProps {
  credentials: CredentialView[];
}

function itemLabel(credential: CredentialView) {
  const percent = credentialPercentRemaining(credential);
  const suffix = typeof percent === "number" ? ` · ${Math.round(percent * 10) / 10}%` : "";
  return `${credential.name}${suffix}`;
}

function sortByPlanEnd(left: CredentialView, right: CredentialView) {
  return (left.planEndsAt ?? "").localeCompare(right.planEndsAt ?? "");
}

function formatCompactDateTime(value: string) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }

  const includeYear = date.getFullYear() !== new Date().getFullYear();
  return new Intl.DateTimeFormat("en", {
    month: "short",
    day: "numeric",
    year: includeYear ? "numeric" : undefined,
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(date);
}

function attentionReason(credential: CredentialView) {
  if (isAttentionStatus(credential.status)) {
    return credential.status;
  }

  if (isLowCredential(credential)) {
    return "low quota";
  }

  return credential.status;
}

export function AttentionList({ credentials }: AttentionListProps) {
  const active = credentials.filter((credential) => credential.active);
  const lowCredentials = active
    .filter((credential) => !isAttentionStatus(credential.status) && isLowCredential(credential))
    .slice(0, 3);
  const expiringCredentials = active
    .filter((credential) => credential.planEndsAt)
    .sort(sortByPlanEnd)
    .slice(0, 3);
  const needsAttention = active.filter(credentialNeedsAttention).slice(0, 2);

  return (
    <div className="attention-grid">
      <section className="attention-section">
        <h2>{translate("tray.low")}</h2>
        {lowCredentials.map((credential) => (
          <div key={credential.id} className="attention-item" data-testid="low-quota-item">
            <span>{itemLabel(credential)}</span>
            <small>{credential.providerId}</small>
          </div>
        ))}
      </section>
      <section className="attention-section">
        <h2>{translate("tray.expiringSoon")}</h2>
        {expiringCredentials.map((credential) => (
          <div key={credential.id} className="attention-item" data-testid="expiring-item">
            <span>{credential.name}</span>
            <small>{credential.planEndsAt ? formatCompactDateTime(credential.planEndsAt) : ""}</small>
          </div>
        ))}
      </section>
      <section className="attention-section attention-section-wide">
        <h2>{translate("tray.needsAttention")}</h2>
        {needsAttention.map((credential) => (
          <div key={credential.id} className="attention-item" data-testid="needs-attention-item">
            <span>{credential.name}</span>
            <small>{attentionReason(credential)}</small>
          </div>
        ))}
      </section>
    </div>
  );
}
