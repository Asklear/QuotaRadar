import { describe, expect, it } from "vitest";
import { formatSystemDisplayText, translate } from "../../src/i18n";
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

  it("does not expose early mock-stage About copy in any locale", () => {
    const disallowedCopy = [
      "Mock UI first, backend contracts next",
      "Mock desktop shell ready for quota pages.",
      "No real provider secrets in preview data",
    ];

    for (const [locale, messages] of Object.entries({ en, ...locales })) {
      const values = Object.values(messages);
      for (const copy of disallowedCopy) {
        expect(values, `${locale} should not contain stale About copy`).not.toContain(copy);
      }
    }
  });

  it("localizes desktop web authorization status messages", () => {
    const t = (key: keyof typeof en) => translate(key, "zh-Hans");

    expect(formatSystemDisplayText("Ready to update Claude Pro Login", t)).toBe(
      "准备更新 Claude Pro Login",
    );
    expect(
      formatSystemDisplayText(
        "Ready to update selected authorization; waiting for dashboard login",
        t,
      ),
    ).toBe("准备更新已选择的授权；等待网页登录");
    expect(
      formatSystemDisplayText(
        "Waiting for dashboard login; Quota Radar will save the authorization after login",
        t,
      ),
    ).toBe("等待网页登录；登录后 Quota Radar 会保存授权");
    expect(formatSystemDisplayText("Claude web login saved", t)).toBe(
      "Claude 网页登录已保存",
    );
  });
});
