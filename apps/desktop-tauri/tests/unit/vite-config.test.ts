import { describe, expect, it } from "vitest";
import { viteWatchIgnored } from "../../src/config/viteWatchIgnores";

describe("vite dev watcher", () => {
  it("ignores generated build and screenshot artifacts", () => {
    for (const pattern of [
        "**/src-tauri/target/**",
        "**/dist/**",
        "**/node_modules/**",
        "**/tests/e2e/artifacts/**",
        "**/tests/e2e/screenshots/**",
        "**/.playwright-mcp/**",
      ]) {
      expect(viteWatchIgnored).toContain(pattern);
    }
  });
});
