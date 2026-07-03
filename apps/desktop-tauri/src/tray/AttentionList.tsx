import {
  formatCompactDateTime,
  formatCredentialStatus,
  formatSystemDisplayText,
  useLocale,
  useTranslate,
} from "../i18n";
import { ProviderIcon } from "../components/ProviderIcon";
import { providerRegistry } from "../shared/mockData";
import {
  credentialNeedsAttention,
  credentialPercentRemaining,
  isAttentionStatus,
  isLowCredential,
} from "../shared/status";
import type { CredentialView } from "../shared/types";

interface AttentionListProps {
  credentials: CredentialView[];
  onOpenCredential?: (credential: CredentialView) => void | Promise<void>;
}

function itemLabel(credential: CredentialView) {
  const percent = credentialPercentRemaining(credential);
  const suffix = typeof percent === "number" ? ` · ${Math.round(percent * 10) / 10}%` : "";
  return `${credential.name}${suffix}`;
}

function remainingText(credential: CredentialView, t: ReturnType<typeof useTranslate>) {
  const percent = credentialPercentRemaining(credential);
  if (typeof percent === "number") {
    return `${Math.round(percent * 10) / 10}%`;
  }

  return formatSystemDisplayText(credential.remainingBadgeText, t);
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

export function AttentionList({ credentials, onOpenCredential }: AttentionListProps) {
  const locale = useLocale();
  const t = useTranslate();
  const active = credentials.filter((credential) => credential.active);
  const favorites = active.filter((credential) => !credentialNeedsAttention(credential)).slice(0, 2);
  const lowCredentials = active
    .filter((credential) => !isAttentionStatus(credential.status) && isLowCredential(credential))
    .slice(0, 1);
  const expiringCredentials = active
    .filter((credential) => credential.planEndsAt)
    .sort(sortByPlanEnd)
    .slice(0, 1);
  const needsAttention = active
    .filter(credentialNeedsAttention)
    .sort((left, right) => Number(isAttentionStatus(right.status)) - Number(isAttentionStatus(left.status)))
    .slice(0, 1);
  const providerFor = (credential: CredentialView) =>
    providerRegistry.find((provider) => provider.id === credential.providerId);

  return (
    <div className="tray-section-stack">
      <section className="tray-list-section monitor-module">
        <h2>{t("tray.favorites")}</h2>
        {favorites.map((credential) => {
          const provider = providerFor(credential);
          return (
            <button
              key={credential.id}
              type="button"
              className="tray-provider-row"
              data-testid="favorite-item"
              onClick={() => {
                void onOpenCredential?.(credential);
              }}
            >
              {provider ? <ProviderIcon provider={provider} /> : null}
              <div className="tray-provider-copy">
                <div>
                  <strong>{provider?.displayName ?? credential.name}</strong>
                  <span className="tray-chip" data-tone="healthy">
                    {t("tray.favorites")}
                  </span>
                  <span>{formatSystemDisplayText(credential.maskedValue, t)}</span>
                </div>
                <small>{formatSystemDisplayText(credential.remainingBadgeText, t)}</small>
              </div>
              <span className="tray-value-pill" data-tone="healthy">
                {remainingText(credential, t)}
              </span>
            </button>
          );
        })}
      </section>

      <section className="tray-list-section monitor-module">
        <h2>{t("tray.headsUp")}</h2>

        <h3>{t("tray.low").toUpperCase()}</h3>
        {lowCredentials.map((credential) => {
          const provider = providerFor(credential);
          return (
            <button
              key={credential.id}
              type="button"
              className="tray-provider-row"
              data-testid="low-quota-item"
              onClick={() => {
                void onOpenCredential?.(credential);
              }}
            >
              {provider ? <ProviderIcon provider={provider} /> : null}
              <div className="tray-provider-copy">
                <div>
                  <strong>{provider?.displayName ?? credential.name}</strong>
                  <span className="tray-chip" data-tone="warning">
                    {attentionReason(credential, t)}
                  </span>
                  <span>{credential.name}</span>
                </div>
                <small>{itemLabel(credential)}</small>
              </div>
              <span className="tray-value-pill" data-tone="warning">
                {remainingText(credential, t)}
              </span>
            </button>
          );
        })}

        <h3>{t("tray.expiringSoon").toUpperCase()}</h3>
        {expiringCredentials.map((credential) => {
          const provider = providerFor(credential);
          return (
            <button
              key={credential.id}
              type="button"
              className="tray-provider-row"
              data-testid="expiring-item"
              onClick={() => {
                void onOpenCredential?.(credential);
              }}
            >
              {provider ? <ProviderIcon provider={provider} /> : null}
              <div className="tray-provider-copy">
                <div>
                  <strong>{provider?.displayName ?? credential.name}</strong>
                  <span className="tray-chip" data-tone="warning">
                    {t("tray.expiringSoon")}
                  </span>
                  <span>{credential.name}</span>
                </div>
                <small>
                  {credential.planEndsAt ? formatCompactDateTime(credential.planEndsAt, locale) : ""}
                </small>
              </div>
              <span className="tray-value-pill" data-tone="warning">
                {remainingText(credential, t)}
              </span>
            </button>
          );
        })}

        <h3>{t("tray.needsAttention").toUpperCase()}</h3>
        {needsAttention.map((credential) => {
          const provider = providerFor(credential);
          return (
            <button
              key={credential.id}
              type="button"
              className="tray-provider-row"
              data-testid="needs-attention-item"
              onClick={() => {
                void onOpenCredential?.(credential);
              }}
            >
              {provider ? <ProviderIcon provider={provider} /> : null}
              <div className="tray-provider-copy">
                <div>
                  <strong>{provider?.displayName ?? credential.name}</strong>
                  <span className="tray-chip" data-tone="attention">
                    {attentionReason(credential, t)}
                  </span>
                  <span>{credential.name}</span>
                </div>
                <small>
                  {formatSystemDisplayText(credential.diagnosticMessage ?? credential.remainingBadgeText, t)}
                </small>
              </div>
              <span className="tray-value-pill" data-tone="attention">
                {remainingText(credential, t)}
              </span>
            </button>
          );
        })}
      </section>
    </div>
  );
}
