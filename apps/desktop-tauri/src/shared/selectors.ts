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

function formatCompactDateTime(value: string) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }

  const currentYear = new Date().getFullYear();
  const includeYear = date.getFullYear() !== currentYear;

  return new Intl.DateTimeFormat("en", {
    month: "short",
    day: "numeric",
    year: includeYear ? "numeric" : undefined,
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(date);
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

function keyQuotaText(credentials: CredentialView[]) {
  const tightest = tightestCredential(activeCredentials(credentials));
  if (tightest) {
    return formatPercent(tightest.percent);
  }

  const usableUnknown = credentials.find((credential) => credential.status === "unknownQuotaUsable");
  if (usableUnknown) {
    return "OK";
  }

  return "N/A";
}

function credentialPoolText(credentials: CredentialView[]) {
  const active = activeCredentials(credentials);
  const healthyCount = active.filter((credential) => !credentialNeedsAttention(credential)).length;
  return `${healthyCount}/${active.length}`;
}

function criticalTimeText(credentials: CredentialView[]) {
  const window = tightestWindow(activeCredentials(credentials));
  if (window?.resetAt) {
    return formatCompactDateTime(window.resetAt);
  }

  const planEnd = activeCredentials(credentials)
    .map((credential) => credential.planEndsAt)
    .filter((value): value is string => Boolean(value))
    .sort()[0];

  return planEnd ? formatCompactDateTime(planEnd) : "N/A";
}

function statusText(credentials: CredentialView[]) {
  return credentials.some(credentialNeedsAttention) ? "Attention" : "Available";
}

export function buildProviderStats(
  registry: ProviderDefinition[],
  credentials: CredentialView[],
): ProviderStats[] {
  return registry
    .filter((provider) => !provider.hidden)
    .map((provider) => {
      const providerCredentials = credentials.filter((credential) => credential.providerId === provider.id);
      return {
        provider,
        credentials: providerCredentials,
        keyQuotaText: keyQuotaText(providerCredentials),
        credentialPoolText: credentialPoolText(providerCredentials),
        criticalTimeText: criticalTimeText(providerCredentials),
        statusText: statusText(providerCredentials),
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
