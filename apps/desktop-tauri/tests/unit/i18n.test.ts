import { describe, expect, it } from "vitest";
import { formatSystemDisplayText, translate } from "../../src/i18n";
import en from "../../src/i18n/locales/en.json";
import zhHans from "../../src/i18n/locales/zh-Hans.json";
import zhHant from "../../src/i18n/locales/zh-Hant.json";
import ja from "../../src/i18n/locales/ja.json";
import ko from "../../src/i18n/locales/ko.json";
import enSource from "../../src/i18n/locales/en.json?raw";
import zhHansSource from "../../src/i18n/locales/zh-Hans.json?raw";
import zhHantSource from "../../src/i18n/locales/zh-Hant.json?raw";
import jaSource from "../../src/i18n/locales/ja.json?raw";
import koSource from "../../src/i18n/locales/ko.json?raw";

const locales = { zhHans, zhHant, ja, ko };
const localeSources = {
  en: enSource,
  "zh-Hans": zhHansSource,
  "zh-Hant": zhHantSource,
  ja: jaSource,
  ko: koSource,
};

describe("i18n", () => {
  it("keeps all non-English locales structurally complete", () => {
    const englishKeys = Object.keys(en).sort();
    for (const [locale, messages] of Object.entries(locales)) {
      expect(Object.keys(messages).sort(), locale).toEqual(englishKeys);
    }
  });

  it("does not hide duplicate locale keys in JSON files", () => {
    for (const [locale, source] of Object.entries(localeSources)) {
      const keys = [...source.matchAll(/^\s+"([^"]+)":/gm)].map((match) => match[1]);
      const duplicates = keys.filter((key, index) => keys.indexOf(key) !== index);

      expect([...new Set(duplicates)], locale).toEqual([]);
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

  it("keeps non-English release status copy fully localized", () => {
    const disallowedFragments = [
      "parity QA",
      "Provider login QA",
      "provider login QA",
      "cross-platform packaging",
    ];

    for (const [locale, messages] of Object.entries(locales)) {
      const statusCopy = [
        messages["about.implementationStageValue"],
        messages["about.dataPolicyValue"],
        messages["app.previewReady"],
      ].join("\n");

      for (const fragment of disallowedFragments) {
        expect(statusCopy, `${locale} should not contain ${fragment}`).not.toContain(fragment);
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
    expect(formatSystemDisplayText("API key saved", t)).toBe("API 密钥已保存");
    expect(
      formatSystemDisplayText(
        "Provider authorization failed: Claude web login authorization is required",
        t,
      ),
    ).toBe("服务商授权失败：Claude 需要网页登录授权");
    expect(
      formatSystemDisplayText(
        "Saved authorization, but quota refresh failed: Provider network failed: timeout",
        t,
      ),
    ).toBe("授权已保存，但额度刷新失败：服务商网络请求失败：timeout");
  });

  it("localizes desktop command errors with dynamic details", () => {
    const t = (key: keyof typeof en) => translate(key, "zh-Hans");

    expect(formatSystemDisplayText("Provider does not have a web authorization URL", t)).toBe(
      "服务商没有网页登录 URL",
    );
    expect(formatSystemDisplayText("Web authorization URL must be http or https", t)).toBe(
      "网页登录 URL 必须使用 http 或 https",
    );
    expect(formatSystemDisplayText("Provider client is not registered: kimi", t)).toBe(
      "服务商暂不支持：kimi",
    );
    expect(formatSystemDisplayText("Provider fixture parse failed", t)).toBe(
      "服务商 fixture 解析失败",
    );
    expect(formatSystemDisplayText("Could not parse Claude settings: invalid JSON", t)).toBe(
      "无法解析 Claude 设置：invalid JSON",
    );
    expect(
      formatSystemDisplayText(
        "Could not read Claude settings file C:\\Users\\qrtest\\.claude\\settings.json: os error 2",
        t,
      ),
    ).toBe(
      "无法读取 Claude 设置文件 C:\\Users\\qrtest\\.claude\\settings.json：os error 2",
    );
  });

  it("localizes backend command errors that can surface in alerts", () => {
    const t = (key: keyof typeof en) => translate(key, "zh-Hans");

    expect(
      formatSystemDisplayText("Codex reset credits are only supported for Codex credentials", t),
    ).toBe("Codex 重置次数仅支持 Codex 凭据");
    expect(
      formatSystemDisplayText("Codex reset credits require web login authorization", t),
    ).toBe("Codex 重置次数需要网页登录授权");
    expect(formatSystemDisplayText("external URL must use http or https", t)).toBe(
      "外部链接必须使用 http 或 https",
    );
    expect(
      formatSystemDisplayText(
        "failed to open external URL: 系统找不到指定的文件。 (os error 2)",
        t,
      ),
    ).toBe("无法打开外部链接：系统找不到指定的文件。 (os error 2)");
    expect(
      formatSystemDisplayText(
        "Could not open the web login window: 系统找不到指定的文件。 (os error 2)",
        t,
      ),
    ).toBe("无法打开网页登录窗口：系统找不到指定的文件。 (os error 2)");
    expect(
      formatSystemDisplayText("kimi does not support automatic web authorization capture", t),
    ).toBe("kimi 不支持自动网页登录授权捕获");
    expect(
      formatSystemDisplayText("Could not save web login authorization: keyring unavailable", t),
    ).toBe("无法保存网页登录授权：keyring unavailable");
  });

  it("localizes provider-specific refresh diagnostics that surface in alerts", () => {
    const t = (key: keyof typeof en) => translate(key, "zh-Hans");

    expect(formatSystemDisplayText("Tavily usage endpoint returned HTTP 401", t)).toBe(
      "Tavily 用量接口返回 HTTP 401",
    );
    expect(formatSystemDisplayText("Brave API key is unauthorized", t)).toBe(
      "Brave API 密钥未授权",
    );
    expect(formatSystemDisplayText("Kimi subscription was not found", t)).toBe(
      "未找到 Kimi 订阅",
    );
    expect(formatSystemDisplayText("Aliyun quota is unavailable", t)).toBe(
      "Aliyun 额度不可用",
    );
    expect(formatSystemDisplayText("Tencent Cloud coding plan was not found", t)).toBe(
      "未找到 Tencent Cloud 编程套餐",
    );
    expect(formatSystemDisplayText("Volcengine web login authorization is required", t)).toBe(
      "Volcengine 需要网页登录授权",
    );
    expect(formatSystemDisplayText("OpenCode Go usage is unavailable", t)).toBe(
      "OpenCode Go 用量不可用",
    );
  });

  it("localizes web authorization timeout capture errors", () => {
    const t = (key: keyof typeof en) => translate(key, "zh-Hans");

    expect(
      formatSystemDisplayText(
        "Could not capture a usable web login authorization before the auth window timed out. Please finish login and try again.",
        t,
      ),
    ).toBe("网页登录授权超时前未捕获到可用授权。请完成登录后重试。");
    expect(
      formatSystemDisplayText(
        "Could not capture required login data (login_aliyunid_ticket, aliyun_lang) before the auth window timed out. Please finish login and try again.",
        t,
      ),
    ).toBe(
      "网页登录授权超时前未捕获到必需登录数据（login_aliyunid_ticket, aliyun_lang）。请完成登录后重试。",
    );
    expect(
      formatSystemDisplayText(
        "Could not inspect the auth window before the web login timed out (webview unavailable). Please finish login and try again.",
        t,
      ),
    ).toBe(
      "网页登录超时前无法检查授权窗口（webview unavailable）。请完成登录后重试。",
    );
  });

  it("localizes structured quota labels returned by providers", () => {
    const t = (key: keyof typeof en) => translate(key, "zh-Hans");

    expect(formatSystemDisplayText("42.5 credits", t)).toBe("42.5 点数");
    expect(formatSystemDisplayText("42 credits left", t)).toBe("剩余 42 点数");
    expect(formatSystemDisplayText("100 / 200 monthly credits", t)).toBe(
      "100 / 200 月度点数",
    );
    expect(formatSystemDisplayText("88 / 100 monthly requests", t)).toBe(
      "88 / 100 月度请求",
    );
    expect(formatSystemDisplayText("81 monthly requests used", t)).toBe(
      "已用 81 次月度请求",
    );
    expect(formatSystemDisplayText("3 searches left", t)).toBe("剩余 3 次搜索");
    expect(formatSystemDisplayText("200 / 1000 tokens", t)).toBe("200 / 1000 个 token");
  });
});
