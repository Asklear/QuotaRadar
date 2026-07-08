import { createContext, useContext } from "react";
import en from "./locales/en.json";
import ja from "./locales/ja.json";
import ko from "./locales/ko.json";
import zhHans from "./locales/zh-Hans.json";
import zhHant from "./locales/zh-Hant.json";
import type { CredentialKind, CredentialStatus, QuotaWindow } from "../shared/types";

export type LocaleCode = "en" | "zh-Hans" | "zh-Hant" | "ja" | "ko";
export type MessageKey = keyof typeof en;

export const locales: Record<LocaleCode, Record<MessageKey, string>> = {
  en,
  "zh-Hans": zhHans,
  "zh-Hant": zhHant,
  ja,
  ko,
};

export const LocaleContext = createContext<LocaleCode>("en");

const intlLocales: Record<LocaleCode, string> = {
  en: "en",
  "zh-Hans": "zh-CN",
  "zh-Hant": "zh-TW",
  ja: "ja-JP",
  ko: "ko-KR",
};

const credentialStatusKeys: Record<CredentialStatus, MessageKey> = {
  healthy: "status.healthy",
  failed: "status.failed",
  expired: "status.expired",
  usageLimitExceeded: "status.usageLimitExceeded",
  disabled: "status.disabled",
  unknownQuotaUsable: "status.unknownQuotaUsable",
  notChecked: "status.notChecked",
  unsupported: "status.unsupported",
  noSubscribedPlan: "status.noSubscribedPlan",
  manualRefreshOnly: "status.manualRefreshOnly",
};

const credentialKindKeys: Record<CredentialKind, MessageKey> = {
  apiKey: "credentialKind.apiKey",
  dashboardCookie: "credentialKind.webAuthorization",
  adminCredential: "credentialKind.managementCredential",
  storedAPIKeyOnly: "credentialKind.companionApiKey",
};

const quotaWindowKeys: Record<string, MessageKey> = {
  "5h": "quotaWindow.5h",
  week: "quotaWindow.week",
  month: "quotaWindow.month",
};

const providerPlanTypeKeys: Record<string, MessageKey> = {
  Balance: "providerPlan.balance",
  Pro: "providerPlan.pro",
  Credits: "providerPlan.credits",
  Membership: "providerPlan.membership",
  Subscription: "providerPlan.subscription",
  "Coding Plan": "providerPlan.codingPlan",
};

const systemDisplayTextKeys: Record<string, MessageKey> = {
  Saved: "credentialDisplay.saved",
  "Authorization saved": "credentialDisplay.authorizationSaved",
  "Web login saved": "credentialDisplay.webLoginSaved",
  "Web login expired": "credentialDisplay.webLoginExpired",
  "Web login authorization saved": "credentialDisplay.webAuthorizationSaved",
  "Web login authorization expired.": "credentialDisplay.webAuthorizationExpired",
  "Login expired": "credentialDisplay.loginExpired",
  "Check failed": "credentialDisplay.checkFailed",
  OK: "credentialDisplay.ok",
  Unlimited: "credentialDisplay.unlimited",
  Unavailable: "credentialDisplay.unavailable",
  "API key saved": "credentialDisplay.apiKeySaved",
  "Credential saved": "credentialDisplay.credentialSaved",
  "Credential was not found": "credentialError.notFound",
  "Credential value was not found": "credentialError.valueNotFound",
  "Credential value is not copyable": "credentialError.valueNotCopyable",
  "Changing provider or credential type requires a replacement secret":
    "credentialError.replacementSecretRequired",
  "Codex reset credits are only supported for Codex credentials":
    "credentialError.codexResetProviderOnly",
  "Codex reset credits require web login authorization":
    "credentialError.codexResetRequiresWebLogin",
  "external URL is empty": "externalUrl.empty",
  "external URL contains whitespace": "externalUrl.containsWhitespace",
  "external URL must use http or https": "externalUrl.invalidScheme",
  "Choose an authorization target": "webAuth.chooseAuthorizationTarget",
  "Provider does not have a web authorization URL": "webAuth.providerUrlMissing",
  "Web authorization URL must be http or https": "webAuth.invalidUrlScheme",
  "Could not capture a usable web login authorization before the auth window timed out. Please finish login and try again.":
    "webAuth.captureUsableTimedOut",
  "Tauri desktop signed update artifacts are not configured yet.":
    "update.signedArtifactsNotConfigured",
};

const providerErrorPrefixKeys: Array<[prefix: string, key: MessageKey]> = [
  ["Provider client is not registered: ", "providerError.unsupported"],
  ["Provider fixture parse failed: ", "providerError.fixtureParseFailed"],
  ["Provider unsupported: ", "providerError.unsupported"],
  ["Provider authorization failed: ", "providerError.authorizationFailed"],
  ["Provider quota unavailable: ", "providerError.quotaUnavailable"],
  ["Provider has no subscribed plan: ", "providerError.noSubscribedPlan"],
  ["Provider network failed: ", "providerError.networkFailed"],
];

const providerErrorExactKeys: Record<string, MessageKey> = Object.fromEntries(
  providerErrorPrefixKeys.map(([prefix, key]) => [prefix.trimEnd().replace(/:$/, ""), key]),
) as Record<string, MessageKey>;

const providerDiagnosticServiceKeys: Record<string, MessageKey> = {
  account: "providerDiagnostic.service.account",
  "account id": "providerDiagnostic.service.accountId",
  "account quota": "providerDiagnostic.service.accountQuota",
  balance: "providerDiagnostic.service.balance",
  "billing usage": "providerDiagnostic.service.billingUsage",
  "coding plan": "providerDiagnostic.service.codingPlan",
  "management usage": "providerDiagnostic.service.managementUsage",
  organization: "providerDiagnostic.service.organization",
  organizations: "providerDiagnostic.service.organizations",
  quota: "providerDiagnostic.service.quota",
  "reset credits": "providerDiagnostic.service.resetCredits",
  Search: "providerDiagnostic.service.search",
  "server function": "providerDiagnostic.service.serverFunction",
  session: "providerDiagnostic.service.session",
  subscription: "providerDiagnostic.service.subscription",
  usage: "providerDiagnostic.service.usage",
  "usage quota": "providerDiagnostic.service.usageQuota",
  "user-info": "providerDiagnostic.service.userInfo",
};

const decimalNumberPattern = String.raw`([0-9]+(?:\.[0-9]+)?)`;

const structuredQuotaLabelPatterns: Array<{
  pattern: RegExp;
  key: MessageKey;
  fields: string[];
}> = [
  {
    pattern: new RegExp(`^${decimalNumberPattern} credits$`),
    key: "quotaLabel.credits",
    fields: ["count"],
  },
  {
    pattern: new RegExp(`^${decimalNumberPattern} credits left$`),
    key: "quotaLabel.creditsLeft",
    fields: ["count"],
  },
  {
    pattern: new RegExp(`^${decimalNumberPattern} / ${decimalNumberPattern} monthly credits$`),
    key: "quotaLabel.monthlyCredits",
    fields: ["remaining", "limit"],
  },
  {
    pattern: new RegExp(`^${decimalNumberPattern} / ${decimalNumberPattern} monthly requests$`),
    key: "quotaLabel.monthlyRequests",
    fields: ["remaining", "limit"],
  },
  {
    pattern: new RegExp(`^${decimalNumberPattern} monthly requests used$`),
    key: "quotaLabel.monthlyRequestsUsed",
    fields: ["used"],
  },
  {
    pattern: new RegExp(`^${decimalNumberPattern} searches left$`),
    key: "quotaLabel.searchesLeft",
    fields: ["count"],
  },
  {
    pattern: new RegExp(`^${decimalNumberPattern} / ${decimalNumberPattern} tokens$`),
    key: "quotaLabel.tokenQuota",
    fields: ["used", "limit"],
  },
];

export function normalizeLocale(locale: string | undefined): LocaleCode {
  return locale && locale in locales ? (locale as LocaleCode) : "en";
}

export function translate(key: MessageKey, locale: LocaleCode = "en") {
  return locales[locale][key];
}

export function localeToIntlLocale(locale: LocaleCode) {
  return intlLocales[locale];
}

export function formatCompactDateTime(value: string, locale: LocaleCode = "en") {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }

  const includeYear = date.getFullYear() !== new Date().getFullYear();

  return new Intl.DateTimeFormat(localeToIntlLocale(locale), {
    month: "short",
    day: "numeric",
    year: includeYear ? "numeric" : undefined,
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(date);
}

export function formatCredentialStatus(
  status: CredentialStatus,
  t: (key: MessageKey) => string = (key) => translate(key),
) {
  return t(credentialStatusKeys[status]);
}

export function formatCredentialKind(
  kind: CredentialKind,
  t: (key: MessageKey) => string = (key) => translate(key),
) {
  return t(credentialKindKeys[kind]);
}

export function formatQuotaWindowName(
  window: Pick<QuotaWindow, "name">,
  t: (key: MessageKey) => string = (key) => translate(key),
) {
  const key = quotaWindowKeys[window.name];
  return key ? t(key) : window.name;
}

export function formatProviderPlanType(
  planType: string | undefined,
  t: (key: MessageKey) => string = (key) => translate(key),
) {
  if (!planType) {
    return undefined;
  }

  const key = providerPlanTypeKeys[planType];
  return key ? t(key) : planType;
}

function interpolateTemplate(template: string, values: Record<string, string>) {
  return Object.entries(values).reduce(
    (formatted, [field, value]) => formatted.split(`{${field}}`).join(value),
    template,
  );
}

function formatStructuredQuotaLabel(
  text: string,
  t: (key: MessageKey) => string,
): string | undefined {
  for (const { pattern, key, fields } of structuredQuotaLabelPatterns) {
    const match = text.match(pattern);
    if (!match) {
      continue;
    }

    const values = Object.fromEntries(
      fields.map((field, index) => [field, match[index + 1] ?? ""]),
    );
    return interpolateTemplate(t(key), values);
  }

  return undefined;
}

function escapeRegExp(text: string) {
  return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function providerDiagnosticServiceLabel(
  service: string,
  t: (key: MessageKey) => string,
) {
  const key = providerDiagnosticServiceKeys[service];
  return key ? t(key) : service;
}

function formatProviderServiceDiagnostic(
  text: string,
  patternForService: (service: string) => RegExp,
  formatter: (provider: string, service: string, match: RegExpMatchArray) => string,
) {
  const services = Object.keys(providerDiagnosticServiceKeys).sort(
    (left, right) => right.length - left.length,
  );
  for (const service of services) {
    const match = text.match(patternForService(service));
    if (match?.[1]) {
      return formatter(match[1], service, match);
    }
  }

  return undefined;
}

export function formatSystemDisplayText(
  text: string,
  t: (key: MessageKey) => string = (key) => translate(key),
): string {
  const exactKey = systemDisplayTextKeys[text];
  if (exactKey) {
    return t(exactKey);
  }

  const providerExactKey = providerErrorExactKeys[text];
  if (providerExactKey) {
    return t(providerExactKey).replace(/[:：]\s*\{message\}/, "");
  }

  for (const [prefix, key] of providerErrorPrefixKeys) {
    if (text.startsWith(prefix)) {
      return t(key).replace(
        "{message}",
        formatSystemDisplayText(text.slice(prefix.length), t),
      );
    }
  }

  const prefixedWebLoginSavedMatch = text.match(/^(.+) web login saved$/i);
  if (prefixedWebLoginSavedMatch?.[1]) {
    return `${prefixedWebLoginSavedMatch[1]} ${t("credentialDisplay.webLoginSaved")}`;
  }

  const prefixedWebLoginExpiredMatch = text.match(/^(.+) web login expired$/i);
  if (prefixedWebLoginExpiredMatch?.[1]) {
    return `${prefixedWebLoginExpiredMatch[1]} ${t("credentialDisplay.webLoginExpired")}`;
  }

  const refreshFailureMatch = text.match(/^Saved authorization, but quota refresh failed: (.+)$/);
  if (refreshFailureMatch?.[1]) {
    return t("app.webAuthorizationRefreshFailed").replace(
      "{message}",
      formatSystemDisplayText(refreshFailureMatch[1], t),
    );
  }

  if (text === "Ready to update selected authorization") {
    return t("webAuth.readyToUpdateSelected");
  }

  if (text === "Ready to update selected authorization; waiting for dashboard login") {
    return t("webAuth.readyToUpdateSelectedWaiting");
  }

  const readyToUpdateWaitingMatch = text.match(/^Ready to update (.+); waiting for dashboard login$/);
  if (readyToUpdateWaitingMatch?.[1]) {
    return t("webAuth.readyToUpdateWaiting").replace("{target}", readyToUpdateWaitingMatch[1]);
  }

  const readyToUpdateMatch = text.match(/^Ready to update (.+)$/);
  if (readyToUpdateMatch?.[1]) {
    return t("webAuth.readyToUpdate").replace("{target}", readyToUpdateMatch[1]);
  }

  if (text === "Waiting for dashboard login; Quota Radar will save the authorization after login") {
    return t("webAuth.waitingForDashboardLogin");
  }

  const captureRequiredTimedOutMatch = text.match(
    /^Could not capture required login data \((.+)\) before the auth window timed out\. Please finish login and try again\.$/,
  );
  if (captureRequiredTimedOutMatch?.[1]) {
    return t("webAuth.captureRequiredTimedOut").replace(
      "{fields}",
      captureRequiredTimedOutMatch[1],
    );
  }

  const inspectTimedOutMatch = text.match(
    /^Could not inspect the auth window before the web login timed out \((.+)\)\. Please finish login and try again\.$/,
  );
  if (inspectTimedOutMatch?.[1]) {
    return t("webAuth.inspectTimedOut").replace("{message}", inspectTimedOutMatch[1]);
  }

  const claudeSettingsReadMatch = text.match(/^Could not read Claude settings file (.+): (.+)$/);
  if (claudeSettingsReadMatch?.[1] && claudeSettingsReadMatch[2]) {
    return t("credentialImport.claudeSettingsReadFailed")
      .replace("{path}", claudeSettingsReadMatch[1])
      .replace("{message}", claudeSettingsReadMatch[2]);
  }

  const claudeSettingsParseMatch = text.match(/^Could not parse Claude settings: (.+)$/);
  if (claudeSettingsParseMatch?.[1]) {
    return t("credentialImport.claudeSettingsParseFailed").replace(
      "{message}",
      claudeSettingsParseMatch[1],
    );
  }

  const webLoginRequiredMatch = text.match(/^(.+) web login authorization is required$/);
  if (webLoginRequiredMatch?.[1]) {
    return t("webAuth.loginRequired").replace("{provider}", webLoginRequiredMatch[1]);
  }

  const endpointHttpDiagnostic = formatProviderServiceDiagnostic(
    text,
    (service) => new RegExp(`^(.+) ${escapeRegExp(service)} endpoint returned HTTP ([0-9]+)$`),
    (provider, service, match) =>
      t("providerDiagnostic.endpointHttp")
        .replace("{provider}", provider)
        .replace("{service}", providerDiagnosticServiceLabel(service, t))
        .replace("{status}", match[2] ?? ""),
  );
  if (endpointHttpDiagnostic) {
    return endpointHttpDiagnostic;
  }

  const unavailableDiagnostic = formatProviderServiceDiagnostic(
    text,
    (service) => new RegExp(`^(.+) ${escapeRegExp(service)} is unavailable$`),
    (provider, service) =>
      t("providerDiagnostic.unavailable")
        .replace("{provider}", provider)
        .replace("{service}", providerDiagnosticServiceLabel(service, t)),
  );
  if (unavailableDiagnostic) {
    return unavailableDiagnostic;
  }

  const notFoundDiagnostic = formatProviderServiceDiagnostic(
    text,
    (service) => new RegExp(`^(.+) ${escapeRegExp(service)} was not found$`),
    (provider, service) =>
      t("providerDiagnostic.notFound")
        .replace("{provider}", provider)
        .replace("{service}", providerDiagnosticServiceLabel(service, t)),
  );
  if (notFoundDiagnostic) {
    return notFoundDiagnostic;
  }

  const apiKeyUnauthorizedMatch = text.match(/^(.+) API key is unauthorized$/);
  if (apiKeyUnauthorizedMatch?.[1]) {
    return t("providerDiagnostic.apiKeyUnauthorized").replace(
      "{provider}",
      apiKeyUnauthorizedMatch[1],
    );
  }

  const apiKeyInvalidMatch = text.match(/^(.+) API key is invalid$/);
  if (apiKeyInvalidMatch?.[1]) {
    return t("providerDiagnostic.apiKeyInvalid").replace("{provider}", apiKeyInvalidMatch[1]);
  }

  const serviceKeyUnauthorizedMatch = text.match(/^(.+) service key is unauthorized$/);
  if (serviceKeyUnauthorizedMatch?.[1]) {
    return t("providerDiagnostic.serviceKeyUnauthorized").replace(
      "{provider}",
      serviceKeyUnauthorizedMatch[1],
    );
  }

  const loginAuthorizationUnauthorizedMatch = text.match(
    /^(.+) login authorization is unauthorized$/,
  );
  if (loginAuthorizationUnauthorizedMatch?.[1]) {
    return t("providerDiagnostic.loginAuthorizationUnauthorized").replace(
      "{provider}",
      loginAuthorizationUnauthorizedMatch[1],
    );
  }

  const externalUrlOpenFailedMatch = text.match(/^failed to open external URL: (.+)$/);
  if (externalUrlOpenFailedMatch?.[1]) {
    return t("externalUrl.openFailed").replace("{message}", externalUrlOpenFailedMatch[1]);
  }

  const webAuthUnsupportedCaptureMatch = text.match(
    /^(.+) does not support automatic web authorization capture$/,
  );
  if (webAuthUnsupportedCaptureMatch?.[1]) {
    return t("webAuth.unsupportedCapture").replace(
      "{provider}",
      webAuthUnsupportedCaptureMatch[1],
    );
  }

  const webAuthOpenWindowFailedMatch = text.match(/^Could not open the web login window: (.+)$/);
  if (webAuthOpenWindowFailedMatch?.[1]) {
    return t("webAuth.openWindowFailed").replace("{message}", webAuthOpenWindowFailedMatch[1]);
  }

  const webAuthSaveFailedMatch = text.match(/^Could not save web login authorization: (.+)$/);
  if (webAuthSaveFailedMatch?.[1]) {
    return t("webAuth.saveFailed").replace("{message}", webAuthSaveFailedMatch[1]);
  }

  const structuredQuotaLabel = formatStructuredQuotaLabel(text, t);
  if (structuredQuotaLabel) {
    return structuredQuotaLabel;
  }

  return text
    .replace(/\b5h\b/g, t("quotaWindow.5h"))
    .replace(/\bweek\b/gi, t("quotaWindow.week"))
    .replace(/\bmonth\b/gi, t("quotaWindow.month"));
}

export function formatSystemErrorMessage(
  prefix: string,
  error: unknown,
  t: (key: MessageKey) => string = (key) => translate(key),
): string {
  const detail = formatSystemDisplayText(error instanceof Error ? error.message : String(error), t);
  return `${prefix}${prefix.endsWith("：") ? "" : " "}${detail}`;
}

export function useLocale() {
  return useContext(LocaleContext);
}

export function useTranslate() {
  const locale = useContext(LocaleContext);
  return (key: MessageKey) => translate(key, locale);
}
