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
  "Choose an authorization target": "webAuth.chooseAuthorizationTarget",
  "Tauri desktop signed update artifacts are not configured yet.":
    "update.signedArtifactsNotConfigured",
};

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

export function formatSystemDisplayText(
  text: string,
  t: (key: MessageKey) => string = (key) => translate(key),
) {
  const exactKey = systemDisplayTextKeys[text];
  if (exactKey) {
    return t(exactKey);
  }

  return text
    .replace(/\b5h\b/g, t("quotaWindow.5h"))
    .replace(/\bweek\b/gi, t("quotaWindow.week"))
    .replace(/\bmonth\b/gi, t("quotaWindow.month"));
}

export function useLocale() {
  return useContext(LocaleContext);
}

export function useTranslate() {
  const locale = useContext(LocaleContext);
  return (key: MessageKey) => translate(key, locale);
}
