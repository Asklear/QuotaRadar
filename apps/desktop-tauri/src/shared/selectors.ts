import {
  formatCompactDateTime,
  translate,
  type LocaleCode,
  type MessageKey,
} from "../i18n";
import {
  credentialNeedsAttention,
  credentialPercentRemaining,
  isAttentionStatus,
  isLowCredential,
} from "./status";
import type {
  CredentialView,
  MenuSummary,
  ProviderDefinition,
  ProviderStats,
  QuotaWindow,
} from "./types";

function activeCredentials(credentials: CredentialView[]) {
  return credentials.filter((credential) => credential.active);
}

function formatPercent(value: number) {
  return `${Math.round(value * 10) / 10}%`;
}

function translator(locale: LocaleCode) {
  return (key: MessageKey) => translate(key, locale);
}

function tightestWindow(credentials: CredentialView[]): QuotaWindow | undefined {
  return credentials
    .flatMap((credential) => credential.quotaWindows)
    .filter((window) => typeof window.percentRemaining === "number")
    .sort((left, right) => left.percentRemaining! - right.percentRemaining!)[0];
}

function tightestCredential(credentials: CredentialView[]) {
  return credentials
    .map((credential) => ({ credential, percent: credentialPercentRemaining(credential) }))
    .filter((entry): entry is { credential: CredentialView; percent: number } => typeof entry.percent === "number")
    .sort((left, right) => left.percent - right.percent)[0];
}

function keyQuotaText(credentials: CredentialView[], locale: LocaleCode) {
  const t = translator(locale);
  const active = activeCredentials(credentials);
  const tightest = tightestCredential(active);
  if (tightest) {
    return formatPercent(tightest.percent);
  }

  const usableUnknown = active.find((credential) => credential.status === "unknownQuotaUsable");
  if (usableUnknown) {
    return t("status.available");
  }

  const badgeFallback = active
    .map((credential) => credential.remainingBadgeText.trim())
    .find((text) => text.length > 0 && text !== t("common.notAvailable"));
  if (badgeFallback) {
    return badgeFallback;
  }

  return t("common.notAvailable");
}

function credentialPoolText(credentials: CredentialView[]) {
  const active = activeCredentials(credentials);
  const healthyCount = active.filter((credential) => !credentialNeedsAttention(credential)).length;
  return `${healthyCount}/${active.length}`;
}

function criticalTimeText(credentials: CredentialView[], locale: LocaleCode) {
  const t = translator(locale);
  const window = tightestWindow(activeCredentials(credentials));
  if (window?.resetAt) {
    return formatCompactDateTime(window.resetAt, locale);
  }

  const planEnd = activeCredentials(credentials)
    .map((credential) => credential.planEndsAt)
    .filter((value): value is string => Boolean(value))
    .sort()[0];

  return planEnd ? formatCompactDateTime(planEnd, locale) : t("common.notAvailable");
}

function statusText(credentials: CredentialView[], locale: LocaleCode) {
  const t = translator(locale);
  return credentials.some(credentialNeedsAttention) ? t("tray.needsAttention") : t("tray.available");
}

export function buildProviderStats(
  registry: ProviderDefinition[],
  credentials: CredentialView[],
  locale: LocaleCode = "en",
): ProviderStats[] {
  return registry
    .filter((provider) => !provider.hidden)
    .map((provider) => {
      const providerCredentials = credentials.filter((credential) => credential.providerId === provider.id);
      return {
        provider,
        credentials: providerCredentials,
        keyQuotaText: keyQuotaText(providerCredentials, locale),
        credentialPoolText: credentialPoolText(providerCredentials),
        criticalTimeText: criticalTimeText(providerCredentials, locale),
        statusText: statusText(providerCredentials, locale),
        needsAttention: providerCredentials.some(credentialNeedsAttention),
      };
    })
    .filter((stat) => stat.credentials.length > 0);
}

export function buildMenuSummary(credentials: CredentialView[]): MenuSummary {
  const active = activeCredentials(credentials);
  const failedCount = active.filter((credential) => isAttentionStatus(credential.status)).length;
  const lowCount = active.filter((credential) => !isAttentionStatus(credential.status) && isLowCredential(credential)).length;
  const availableCount = active.length - failedCount - lowCount;

  return {
    availableCount,
    lowCount,
    failedCount,
    totalActiveCount: active.length,
  };
}
