import {
  formatCompactDateTime,
  formatCredentialStatus,
  useLocale,
  useTranslate,
} from "../i18n";
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

function attentionReason(credential: CredentialView, t: ReturnType<typeof useTranslate>) {
  if (isAttentionStatus(credential.status)) {
    return formatCredentialStatus(credential.status, t);
  }

  if (isLowCredential(credential)) {
    return t("attention.lowQuota");
  }

  return formatCredentialStatus(credential.status, t);
}

export function AttentionList({ credentials }: AttentionListProps) {
  const locale = useLocale();
  const t = useTranslate();
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
    <div className="attention-stack">
      <section className="attention-section monitor-module">
        <h2>{t("tray.low")}</h2>
        {lowCredentials.map((credential) => (
          <div key={credential.id} className="attention-item" data-testid="low-quota-item">
            <span>{itemLabel(credential)}</span>
            <small>{credential.providerId}</small>
          </div>
        ))}
      </section>
      <section className="attention-section monitor-module">
        <h2>{t("tray.expiringSoon")}</h2>
        {expiringCredentials.map((credential) => (
          <div key={credential.id} className="attention-item" data-testid="expiring-item">
            <span>{credential.name}</span>
            <small>{credential.planEndsAt ? formatCompactDateTime(credential.planEndsAt, locale) : ""}</small>
          </div>
        ))}
      </section>
      <section className="attention-section monitor-module">
        <h2>{t("tray.needsAttention")}</h2>
        {needsAttention.map((credential) => (
          <div key={credential.id} className="attention-item" data-testid="needs-attention-item">
            <span>{credential.name}</span>
            <small>{attentionReason(credential, t)}</small>
          </div>
        ))}
      </section>
    </div>
  );
}
