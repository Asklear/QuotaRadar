import { describe, expect, it } from "vitest";
import en from "../../src/i18n/locales/en.json";
import zhHans from "../../src/i18n/locales/zh-Hans.json";
import zhHant from "../../src/i18n/locales/zh-Hant.json";
import ja from "../../src/i18n/locales/ja.json";
import ko from "../../src/i18n/locales/ko.json";

const locales = { zhHans, zhHant, ja, ko };

describe("i18n", () => {
  it("keeps all non-English locales structurally complete", () => {
    const englishKeys = Object.keys(en).sort();
    for (const [locale, messages] of Object.entries(locales)) {
      expect(Object.keys(messages).sort(), locale).toEqual(englishKeys);
    }
  });
});
