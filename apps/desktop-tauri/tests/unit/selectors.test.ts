import { describe, expect, it } from "vitest";
import { buildMenuSummary, buildProviderStats } from "../../src/shared/selectors";
import { mockCredentials, providerRegistry } from "../../src/shared/mockData";

describe("provider selectors", () => {
  it("hides unconfigured providers", () => {
    const stats = buildProviderStats(providerRegistry, mockCredentials);
    expect(stats.every((stat) => stat.credentials.length > 0)).toBe(true);
  });

  it("marks provider red when any active credential needs attention", () => {
    const stats = buildProviderStats(providerRegistry, mockCredentials);
    const brave = stats.find((stat) => stat.provider.id === "brave");
    expect(brave?.needsAttention).toBe(true);
  });

  it("builds tray risk summary from credential states", () => {
    const summary = buildMenuSummary(mockCredentials);
    expect(summary.failedCount).toBeGreaterThanOrEqual(1);
    expect(summary.lowCount).toBeGreaterThanOrEqual(1);
    expect(summary.availableCount).toBeGreaterThanOrEqual(1);
  });

  it("formats provider critical time for compact table display", () => {
    const stats = buildProviderStats(providerRegistry, mockCredentials);
    const tavily = stats.find((stat) => stat.provider.id === "tavily");
    expect(tavily?.criticalTimeText).not.toContain("T");
  });

  it("includes Anthropic Credits as a separate Claude-backed provider", () => {
    const provider = providerRegistry.find((entry) => entry.id === "anthropic_credits");

    expect(provider).toMatchObject({
      displayName: "Anthropic Credits",
      familyName: "Anthropic",
      category: "LLM",
      planType: "Credits",
      icon: "anthropic",
      supportsReauth: true,
      supportsRefresh: true,
      quotaCheckConsumesSearchQuota: false,
    });
  });

  it("keeps the frontend visible provider surface aligned with the Tauri backend", () => {
    expect(providerRegistry.map((provider) => provider.id)).toEqual([
      "tavily",
      "brave",
      "serpapi",
      "serper",
      "exa",
      "bocha",
      "anysearch",
      "wxmp",
      "querit",
      "deepseek",
      "claude",
      "anthropic_credits",
      "codex",
      "kimi",
      "opencode_go",
      "xfyun_coding_plan",
      "volcengine_coding_plan",
      "aliyun_coding_plan",
      "tencent_cloud_coding_plan",
    ]);
  });
});
