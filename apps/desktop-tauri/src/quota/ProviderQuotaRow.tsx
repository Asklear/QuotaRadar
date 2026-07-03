import type { KeyboardEvent } from "react";
import { ExternalLink, RefreshCw, RotateCcw } from "lucide-react";
import { ProviderIcon } from "../components/ProviderIcon";
import { StatusPill } from "../components/StatusPill";
import { formatProviderPlanType, useTranslate } from "../i18n";
import { openExternalUrl } from "../lib/tauriClient";
import type { ProviderStats, StartWebAuthorizationHandler } from "../shared/types";
import { CredentialDetailTable } from "./CredentialDetailTable";

interface ProviderQuotaRowProps {
  stat: ProviderStats;
  expanded: boolean;
  onToggle: () => void;
  onRefreshProvider?: (providerId: string) => void | Promise<void>;
  onResetCodexQuota?: (credentialId: string) => void | Promise<void>;
  onStartWebAuthorization?: StartWebAuthorizationHandler;
}

export function ProviderQuotaRow({
  stat,
  expanded,
  onToggle,
  onRefreshProvider,
  onResetCodexQuota,
  onStartWebAuthorization,
}: ProviderQuotaRowProps) {
  const t = useTranslate();
  const tone = stat.needsAttention ? "attention" : "healthy";
  const authorizationCredentials = stat.credentials.filter(
    (credential) => credential.kind === "dashboardCookie",
  );
  const reauthorizationTarget =
    authorizationCredentials.length === 1 ? authorizationCredentials[0] : undefined;
  const reauthorizationLabel = reauthorizationTarget?.name ?? (
    authorizationCredentials.length > 1 ? t("action.chooseAccount") : undefined
  );
  const subtitle = [
    stat.provider.familyName !== stat.provider.displayName ? stat.provider.familyName : undefined,
    formatProviderPlanType(stat.provider.planType, t),
  ]
    .filter(Boolean)
    .join(" · ");
  const rowLabel = [
    stat.provider.displayName,
    stat.keyQuotaText,
    stat.credentialPoolText,
    stat.criticalTimeText,
    stat.statusText,
  ].join(" ");

  function handleKeyboardToggle(event: KeyboardEvent<HTMLDivElement>) {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      onToggle();
    }
  }

  return (
    <div className="provider-row-shell" data-expanded={expanded} role="row">
      <div
        className="provider-row-card"
        data-tone={tone}
        role="button"
        tabIndex={0}
        aria-expanded={expanded}
        aria-label={rowLabel}
        onClick={onToggle}
        onKeyDown={handleKeyboardToggle}
      >
        <div className="provider-cell">
          <ProviderIcon provider={stat.provider} />
          <div className="provider-title-block">
            <div className="provider-name">{stat.provider.displayName}</div>
            {subtitle ? <div className="provider-subtitle">{subtitle}</div> : null}
            {stat.provider.quotaCheckConsumesSearchQuota ? (
              <div className="provider-warning">{t("quota.refreshConsumesSearchQuota")}</div>
            ) : null}
          </div>
        </div>

        <div className="provider-metric numeric-cell" data-priority="primary">
          <small>{t("quota.keyQuota")}</small>
          <strong>{stat.keyQuotaText}</strong>
        </div>
        <div className="provider-metric numeric-cell">
          <small>{t("quota.credentialPool")}</small>
          <strong>{stat.credentialPoolText}</strong>
        </div>
        <div className="provider-metric numeric-cell">
          <small>{t("quota.criticalTime")}</small>
          <strong>{stat.criticalTimeText}</strong>
        </div>
        <div className="provider-status-slot">
          <StatusPill tone={tone} label={stat.statusText} />
        </div>
        <div className="quota-actions" onClick={(event) => event.stopPropagation()}>
          {stat.provider.dashboardUrl ? (
            <button
              aria-label={`${stat.provider.displayName} ${t("action.openDashboard")}`}
              onClick={() => {
                void openExternalUrl(stat.provider.dashboardUrl);
              }}
            >
              <ExternalLink size={14} />
            </button>
          ) : null}
          {stat.provider.supportsReauth ? (
            <button
              aria-label={[
                stat.provider.displayName,
                t("action.reauthorize"),
                reauthorizationLabel,
              ].filter(Boolean).join(" ")}
              onClick={() => {
                void onStartWebAuthorization?.(stat.provider.id, reauthorizationTarget?.id);
              }}
            >
              <RotateCcw size={14} />
            </button>
          ) : null}
          {stat.provider.supportsRefresh ? (
            <button
              aria-label={`${stat.provider.displayName} ${t("action.refresh")}`}
              onClick={() => {
                void onRefreshProvider?.(stat.provider.id);
              }}
            >
              <RefreshCw size={14} />
            </button>
          ) : null}
        </div>
      </div>
      {expanded ? (
        <div className="provider-detail-panel" data-testid={`provider-detail-${stat.provider.id}`}>
          <CredentialDetailTable
            credentials={stat.credentials}
            onResetCodexQuota={onResetCodexQuota}
          />
        </div>
      ) : null}
    </div>
  );
}
