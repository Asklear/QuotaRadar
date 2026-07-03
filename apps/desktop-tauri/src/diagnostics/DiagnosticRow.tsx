import { Fragment } from "react";
import { StatusPill } from "../components/StatusPill";
import {
  formatCompactDateTime,
  formatCredentialStatus,
  formatSystemDisplayText,
  type MessageKey,
  useLocale,
  useTranslate,
} from "../i18n";
import { credentialNeedsAttention } from "../shared/status";
import type { AppSettings, CredentialView, ProviderDefinition, RefreshInterval } from "../shared/types";

interface DiagnosticRowProps {
  credential: CredentialView;
  provider: ProviderDefinition;
  settings: AppSettings;
}

const proxyModeKeys: Record<AppSettings["proxy"]["mode"], MessageKey> = {
  system: "proxy.system",
  direct: "proxy.direct",
  custom: "proxy.custom",
};

const refreshIntervalKeys: Record<RefreshInterval, MessageKey> = {
  off: "interval.off",
  "30m": "interval.30m",
  "1h": "interval.1h",
  "6h": "interval.6h",
};

function httpStatusLabel(status: number | undefined, t: ReturnType<typeof useTranslate>) {
  return typeof status === "number" ? `HTTP ${status}` : t("diagnostics.noRequest");
}

function httpStatusDetailLabel(status: number | undefined, t: ReturnType<typeof useTranslate>) {
  return typeof status === "number" ? String(status) : t("diagnostics.noRequest");
}

function formatDate(value: string | undefined, locale: ReturnType<typeof useLocale>, t: ReturnType<typeof useTranslate>) {
  if (!value) {
    return t("common.notUpdated");
  }

  return formatCompactDateTime(value, locale);
}

function proxyModeLabel(settings: AppSettings, t: ReturnType<typeof useTranslate>) {
  if (settings.proxy.mode === "custom") {
    const customUrl = settings.proxy.customUrl?.trim();
    return customUrl
      ? `${t("proxy.custom")} · ${customUrl}`
      : t("proxy.custom");
  }

  return t(proxyModeKeys[settings.proxy.mode]);
}

function intervalLabel(interval: RefreshInterval, t: ReturnType<typeof useTranslate>) {
  return t(refreshIntervalKeys[interval]);
}

function automaticRefreshText(
  provider: ProviderDefinition,
  settings: AppSettings,
  t: ReturnType<typeof useTranslate>,
) {
  if (!provider.supportsRefresh) {
    return t("diagnostics.autoRefreshUnsupported");
  }

  const interval = provider.quotaCheckConsumesSearchQuota
    ? settings.costlyRefreshInterval
    : settings.autoRefreshInterval;
  if (provider.quotaCheckConsumesSearchQuota && interval === "off") {
    return t("diagnostics.autoRefreshCostlySkipped");
  }
  if (interval === "off") {
    return t("diagnostics.autoRefreshOff");
  }

  return intervalLabel(interval, t);
}

export function DiagnosticRow({ credential, provider, settings }: DiagnosticRowProps) {
  const locale = useLocale();
  const t = useTranslate();
  const tone = credentialNeedsAttention(credential) ? "attention" : "healthy";

  return (
    <Fragment>
      <tr className="diagnostic-row">
        <td>
          <div className="credential-name">{credential.name}</div>
          <div className="credential-subtitle">{formatSystemDisplayText(credential.maskedValue, t)}</div>
        </td>
        <td>
          <StatusPill tone={tone} label={formatCredentialStatus(credential.status, t)} />
        </td>
        <td className="numeric-cell">{httpStatusLabel(credential.lastHttpStatus, t)}</td>
        <td className="numeric-cell">{formatDate(credential.lastUpdated, locale, t)}</td>
        <td>
          {credential.diagnosticMessage
            ? formatSystemDisplayText(credential.diagnosticMessage, t)
            : t("common.ready")}
        </td>
      </tr>
      <tr className="diagnostic-detail-row">
        <td colSpan={5}>
          <details className="diagnostic-detail-disclosure" open>
            <summary>{t("diagnostics.details")}</summary>
            <dl>
              <div>
                <dt>{t("diagnostics.lastHttpStatus")}</dt>
                <dd>{httpStatusDetailLabel(credential.lastHttpStatus, t)}</dd>
              </div>
              <div>
                <dt>{t("diagnostics.requestProxyMode")}</dt>
                <dd>{proxyModeLabel(settings, t)}</dd>
              </div>
              <div>
                <dt>{t("diagnostics.reset")}</dt>
                <dd>{formatDate(credential.resetAt, locale, t)}</dd>
              </div>
              <div>
                <dt>{t("diagnostics.lastChecked")}</dt>
                <dd>{formatDate(credential.lastUpdated, locale, t)}</dd>
              </div>
              <div>
                <dt>{t("diagnostics.automaticRefresh")}</dt>
                <dd>{automaticRefreshText(provider, settings, t)}</dd>
              </div>
            </dl>
          </details>
        </td>
      </tr>
    </Fragment>
  );
}
