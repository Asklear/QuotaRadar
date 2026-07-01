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

  it("localizes common credential and provider error messages", () => {
    const t = (key: keyof typeof en) => translate(key, "zh-Hans");

    expect(formatSystemDisplayText("Credential was not found", t)).toBe("未找到凭据");
    expect(formatSystemDisplayText("Credential value was not found", t)).toBe(
      "未找到凭据值",
    );
    expect(formatSystemDisplayText("Credential value is not copyable", t)).toBe(
      "凭据值不可复制",
    );
    expect(formatSystemDisplayText("API key saved", t)).toBe("API Key 已保存");
    expect(
      formatSystemDisplayText(
        "Provider authorization failed: Claude web login authorization is required",
        t,
      ),
    ).toBe("服务商授权失败：Claude 需要网页登录授权");
  });
});
