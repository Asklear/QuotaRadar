import { describe, expect, it } from "vitest";
import { providerRegistry } from "../../src/shared/providerRegistry";

describe("providerRegistry", () => {
  it("uses the Swift OpenCode Go workspace page for dashboard and web auth entry", () => {
    const opencode = providerRegistry.find((provider) => provider.id === "opencode_go");

    expect(opencode?.dashboardUrl).toBe("https://opencode.ai/workspace/wrk_01KSKR4K4WDJY0JZSCJTMRZ5CV/go");
  });
});
