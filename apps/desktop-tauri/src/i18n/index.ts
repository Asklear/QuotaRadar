import en from "./locales/en.json";
import ja from "./locales/ja.json";
import ko from "./locales/ko.json";
import zhHans from "./locales/zh-Hans.json";
import zhHant from "./locales/zh-Hant.json";

export type LocaleCode = "en" | "zh-Hans" | "zh-Hant" | "ja" | "ko";
export type MessageKey = keyof typeof en;

export const locales: Record<LocaleCode, Record<MessageKey, string>> = {
  en,
  "zh-Hans": zhHans,
  "zh-Hant": zhHant,
  ja,
  ko,
};

export function translate(key: MessageKey, locale: LocaleCode = "en") {
  return locales[locale][key];
}
