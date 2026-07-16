# Dual-DMG GitHub Release Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every tagged GitHub Release build, verify, and upload both the standard and WhiteLabel macOS DMGs, then push the prepared `release/v0.4.6` branch without publishing it.

**Architecture:** Keep one macOS release job and build both variants sequentially so they share one tested commit and one release action. Use order-aware source tests to protect the standard-app scan before the white-label build replaces the scratch app, then verify both final DMGs and upload them through one multiline `files` input.

**Tech Stack:** GitHub Actions YAML, Bash, Python source assertions, Swift behavior-test harness, `hdiutil`, `strings`, `ripgrep`, Git.

---

### Task 1: Add failing dual-release workflow assertions

**Files:**
- Modify: `Tests/run_behavior_tests.sh` near the existing `.github/workflows/release.yml` assertions
- Reference: `.github/workflows/release.yml`

- [ ] **Step 1: Add structure-aware red tests**

Add a Python source check that reads `.github/workflows/release.yml`, requires exactly one `softprops/action-gh-release@v2` invocation, and verifies these tokens occur in this order:

```text
scripts/package_dmg.sh --rebuild
https://api.github.com/repos/Asklear/QuotaRadar/releases/latest
https://github.com/Asklear/QuotaRadar/releases/latest
scripts/package_dmg.sh --rebuild --white-label
White-label app leaked an updater URL
White-label DMG leaked an updater URL
hdiutil verify build/QuotaRadar.dmg
hdiutil verify build/QuotaRadar-WhiteLabel.dmg
uses: softprops/action-gh-release@v2
```

Within the single action block, require a multiline `files: |` input containing exactly the two release artifact paths before `body: |`:

```yaml
files: |
  build/QuotaRadar.dmg
  build/QuotaRadar-WhiteLabel.dmg
```

Also assert both `README.md` and `README.zh-Hans.md` manual `gh release create v0.4.6` command blocks contain both paths, and reject the old workflow wording that only one Swift macOS DMG is published.

- [ ] **Step 2: Run the behavior suite and confirm the expected red failure**

Run:

```bash
bash Tests/run_behavior_tests.sh
```

Expected: non-zero exit from the new workflow check because the white-label build, scans, second upload path, and dual-release wording do not exist yet.

### Task 2: Build, verify, and upload both DMGs

**Files:**
- Modify: `.github/workflows/release.yml`
- Modify: `README.md`
- Modify: `README.zh-Hans.md`
- Test: `Tests/run_behavior_tests.sh`

- [ ] **Step 1: Add the standard artifact check before the scratch app is replaced**

Rename the existing standard build step clearly, then add a shell step that requires both standard updater URLs in `build/Quota Radar.app/Contents/MacOS/QuotaRadar` and requires `build/QuotaRadar.dmg` to be non-empty.

- [ ] **Step 2: Add the white-label build and exclusion scans**

Run:

```bash
scripts/package_dmg.sh --rebuild --white-label
```

Then fail when either the current white-label app binary or `build/QuotaRadar-WhiteLabel.dmg` contains an `Asklear/QuotaRadar` updater URL. Require both DMGs to be non-empty and run:

```bash
hdiutil verify build/QuotaRadar.dmg
hdiutil verify build/QuotaRadar-WhiteLabel.dmg
```

- [ ] **Step 3: Configure one release action with two assets**

Set:

```yaml
files: |
  build/QuotaRadar.dmg
  build/QuotaRadar-WhiteLabel.dmg
```

Update the English and Chinese workflow body to distinguish the standard updater-enabled DMG from the WhiteLabel DMG without upstream updater endpoints.

- [ ] **Step 4: Align both manual release commands**

Change each README command to:

```bash
gh release create v0.4.6 \
  build/QuotaRadar.dmg \
  build/QuotaRadar-WhiteLabel.dmg \
  --title "Quota Radar v0.4.6" \
  --notes "..."
```

- [ ] **Step 5: Run the full behavior suite**

Run:

```bash
bash Tests/run_behavior_tests.sh
```

Expected: exit 0 with Debug/Release builds, valid app signature, and `All behavior tests passed`.

- [ ] **Step 6: Commit the implementation**

```bash
git add .github/workflows/release.yml README.md README.zh-Hans.md Tests/run_behavior_tests.sh
git commit -m "release: upload standard and white-label DMGs"
```

### Task 3: Final verification and branch push

**Files:**
- Verify: `.github/workflows/release.yml`
- Verify: `README.md`
- Verify: `README.zh-Hans.md`
- Verify: `Tests/run_behavior_tests.sh`

- [ ] **Step 1: Run final source gates**

```bash
git diff --check v0.4.5..HEAD
git status --short --branch
bash Tests/run_behavior_tests.sh
bash scripts/check_tauri_sources.sh
```

Expected: clean diff, clean worktree, behavior suite exit 0, and Tauri source safety passed.

- [ ] **Step 2: Independently review the workflow diff**

Use @requesting-code-review with base `d9d952f` and the implementation HEAD. Require review of build order, scan timing, action inputs, README parity, tag-only trigger, and the no-publish boundary. Resolve every Critical or Important finding before push.

- [ ] **Step 3: Rename the historical local branch**

```bash
git branch -m release/v0.4.6
```

Verify `git status --short --branch` reports `release/v0.4.6`.

- [ ] **Step 4: Push only the release branch**

```bash
git push -u origin release/v0.4.6
```

Do not push to `main`, create `v0.4.6`, or run a release command.

- [ ] **Step 5: Verify remote branch identity and release inactivity**

```bash
test "$(git rev-parse HEAD)" = "$(git ls-remote origin refs/heads/release/v0.4.6 | cut -f1)"
git ls-remote --tags origin refs/tags/v0.4.6
```

Expected: local and remote release branch SHAs match; the tag query is empty, so the tag-triggered workflow has not started.
