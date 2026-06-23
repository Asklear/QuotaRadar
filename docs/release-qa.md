# Release QA Checklist

Use this checklist before publishing a DMG. Run the standard updater build and the white-label no-updater build as separate artifacts; their GitHub Release URL expectations are intentionally different.

## Shared Preflight

- [ ] Confirm the version, release notes, README links, and screenshots are ready.
- [ ] Run behavior tests:

```bash
bash Tests/run_behavior_tests.sh
```

- [ ] Run visual screenshot QA and inspect `build/visual-qa/summary.txt` plus the generated screenshots:

```bash
Tests/run_visual_qa.sh
```

- [ ] Run source secret scans before packaging. These scans should report no high-confidence API keys, cookies, tokens, authorization headers, or raw provider responses. Redacted fixtures such as `sk-...-redacted` are allowed in tests, but real values are not:

```bash
rg -n --hidden \
  --glob '!.git/**' \
  --glob '!build/**' \
  --glob '!.build/**' \
  --glob '!.build-white-label/**' \
  'sk-(live|proj|ant|or|svcacct|admin)-[A-Za-z0-9_-]{16,}|sk-[A-Za-z0-9_-]{32,}|AIza[0-9A-Za-z_-]{30,}|AKIA[0-9A-Z]{16}|xox[baprs]-[0-9A-Za-z-]{20,}|gh[pousr]_[0-9A-Za-z_]{30,}' .

rg -n --hidden \
  --glob '!.git/**' \
  --glob '!build/**' \
  --glob '!.build/**' \
  --glob '!.build-white-label/**' \
  --glob '!Tests/run_behavior_tests.sh' \
  --glob '!docs/release-qa.md' \
  --glob '!docs/release-qa.zh-Hans.md' \
  "(authorization: *bearer +[A-Za-z0-9._-]{20,}|cookie: *[\"']?[^\"'<[:space:]]+=[^\"'<]{20,}|sessionKeyLC=[^;[:space:]]{20,}|__Secure-next-auth[^=]*=[^;[:space:]]{20,}|secretAccessKey[\"=: ]+[A-Za-z0-9/+]{20,}|secretKey[\"=: ]+[A-Za-z0-9/+]{20,})" .
```

## Standard Updater Build

This artifact is allowed to embed the upstream GitHub Release updater URLs and should be uploaded as `build/QuotaRadar.dmg`.

- [ ] Build the standard DMG:

```bash
scripts/package_dmg.sh --rebuild
```

- [ ] Verify the expected GitHub Release URL scan against the standard app bundle. Both updater endpoints should be present:

```bash
strings 'build/Quota Radar.app/Contents/MacOS/QuotaRadar' | rg \
  'https://api\.github\.com/repos/Asklear/QuotaRadar/releases/latest|https://github\.com/Asklear/QuotaRadar/releases/latest'
```

Expected URLs:

- `https://api.github.com/repos/Asklear/QuotaRadar/releases/latest`
- `https://github.com/Asklear/QuotaRadar/releases/latest`

- [ ] Verify the standard DMG exists and is readable:

```bash
test -s build/QuotaRadar.dmg
hdiutil verify build/QuotaRadar.dmg
```

- [ ] Verify the packaged app signature:

```bash
codesign --verify --deep --strict --verbose=2 'build/Quota Radar.app'
```

- [ ] Mount the DMG, confirm `Quota Radar.app` and the `/Applications` symlink are present, then detach it:

```bash
MOUNT_DIR="$(mktemp -d)"
hdiutil attach build/QuotaRadar.dmg -mountpoint "$MOUNT_DIR" -nobrowse -quiet
test -d "$MOUNT_DIR/Quota Radar.app"
test -L "$MOUNT_DIR/Applications"
hdiutil detach "$MOUNT_DIR" -quiet
rmdir "$MOUNT_DIR"
```

- [ ] Publish the standard artifact only as `QuotaRadar.dmg`; this is the only build that should participate in GitHub Release updater checks.

## White-Label No-Updater Build

This artifact is for distribution where the app bundle must not embed upstream GitHub Release URLs. It should be uploaded or shared as `build/QuotaRadar-WhiteLabel.dmg`, not as the updater artifact.

- [ ] Build the white-label DMG:

```bash
scripts/package_dmg.sh --rebuild --white-label
```

- [ ] Confirm the compile-time updater boundary is documented in the build log or command path:

```bash
rg -n 'QUOTARADAR_DISABLE_GITHUB_UPDATER|-DQUOTARADAR_DISABLE_GITHUB_UPDATER' install.sh scripts/package_dmg.sh QuotaRadar/Services/GitHubReleaseUpdater.swift
```

- [ ] Run a white-label GitHub Release URL scan against the app bundle. This must print no matches:

```bash
if strings 'build/Quota Radar.app/Contents/MacOS/QuotaRadar' | rg 'Asklear/QuotaRadar|api\.github\.com/repos/Asklear/QuotaRadar|github\.com/Asklear/QuotaRadar/releases/latest'; then
  echo 'White-label app leaked an updater URL' >&2
  exit 1
fi
```

- [ ] Run a white-label GitHub Release URL scan against the DMG bytes. This is a coarse guard; if it reports a match, treat it as a release blocker:

```bash
if strings build/QuotaRadar-WhiteLabel.dmg | rg 'Asklear/QuotaRadar|api\.github\.com/repos/Asklear/QuotaRadar|github\.com/Asklear/QuotaRadar/releases/latest'; then
  echo 'White-label DMG leaked an updater URL' >&2
  exit 1
fi
```

- [ ] Verify the white-label DMG exists and is readable:

```bash
test -s build/QuotaRadar-WhiteLabel.dmg
hdiutil verify build/QuotaRadar-WhiteLabel.dmg
```

- [ ] Verify the packaged app signature:

```bash
codesign --verify --deep --strict --verbose=2 'build/Quota Radar.app'
```

- [ ] Mount the white-label DMG, confirm `Quota Radar.app` and the `/Applications` symlink are present, then detach it:

```bash
MOUNT_DIR="$(mktemp -d)"
hdiutil attach build/QuotaRadar-WhiteLabel.dmg -mountpoint "$MOUNT_DIR" -nobrowse -quiet
test -d "$MOUNT_DIR/Quota Radar.app"
test -L "$MOUNT_DIR/Applications"
hdiutil detach "$MOUNT_DIR" -quiet
rmdir "$MOUNT_DIR"
```

- [ ] Do not upload the white-label artifact as `QuotaRadar.dmg` unless the release intentionally disables in-app updates for that channel.

## Screenshot Rules

- [ ] README screenshots must come from window-level captures, not full-desktop screenshots.
- [ ] Transparent menu-bar popovers must not reveal the user's desktop background.
- [ ] English README screenshots live under `docs/assets/screenshots/en/`.
- [ ] Simplified Chinese README screenshots live under `docs/assets/screenshots/zh-Hans/`.
- [ ] Provider names, account labels, and credential-like text in screenshots must be masked or fixture-generated.
