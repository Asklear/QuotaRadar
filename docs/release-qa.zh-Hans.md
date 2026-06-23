# Release QA Checklist

发布 DMG 前使用这份 checklist。标准 updater 版本和白牌 no-updater 版本必须作为两套产物分别验收；它们对 GitHub Release URL 的预期刻意不同。

## 通用预检

- [ ] 确认版本号、release notes、README 链接和截图都已更新。
- [ ] 运行行为测试：

```bash
bash Tests/run_behavior_tests.sh
```

- [ ] 运行视觉截图 QA，并检查 `build/visual-qa/summary.txt` 和生成的截图：

```bash
Tests/run_visual_qa.sh
```

- [ ] 打包前运行源码 secret 扫描。下面两段扫描应该没有高置信 API key、cookie、token、authorization header 或 provider 原始响应命中。测试里的 `sk-...-redacted` 这类脱敏 fixture 允许存在，但真实值不允许出现：

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

## 标准 Updater 构建

这个产物允许内嵌上游 GitHub Release updater URL，发布文件应为 `build/QuotaRadar.dmg`。

- [ ] 构建标准 DMG：

```bash
scripts/package_dmg.sh --rebuild
```

- [ ] 对标准 app bundle 执行 GitHub Release URL 扫描。以下两个 updater endpoint 都应该存在：

```bash
strings 'build/Quota Radar.app/Contents/MacOS/QuotaRadar' | rg \
  'https://api\.github\.com/repos/Asklear/QuotaRadar/releases/latest|https://github\.com/Asklear/QuotaRadar/releases/latest'
```

预期 URL：

- `https://api.github.com/repos/Asklear/QuotaRadar/releases/latest`
- `https://github.com/Asklear/QuotaRadar/releases/latest`

- [ ] 验证标准 DMG 存在且可读：

```bash
test -s build/QuotaRadar.dmg
hdiutil verify build/QuotaRadar.dmg
```

- [ ] 验证 app 签名：

```bash
codesign --verify --deep --strict --verbose=2 'build/Quota Radar.app'
```

- [ ] 挂载 DMG，确认包含 `Quota Radar.app` 和 `/Applications` 软链接，然后卸载：

```bash
MOUNT_DIR="$(mktemp -d)"
hdiutil attach build/QuotaRadar.dmg -mountpoint "$MOUNT_DIR" -nobrowse -quiet
test -d "$MOUNT_DIR/Quota Radar.app"
test -L "$MOUNT_DIR/Applications"
hdiutil detach "$MOUNT_DIR" -quiet
rmdir "$MOUNT_DIR"
```

- [ ] 标准版只能以 `QuotaRadar.dmg` 发布；只有这个构建应该参与 GitHub Release updater 检查。

## 白牌 No-Updater 构建

这个产物用于不希望 app bundle 内嵌上游 GitHub Release URL 的分发场景。发布或分享文件应为 `build/QuotaRadar-WhiteLabel.dmg`，不要作为 updater 产物使用。

- [ ] 构建白牌 DMG：

```bash
scripts/package_dmg.sh --rebuild --white-label
```

- [ ] 确认编译期 updater 边界存在：

```bash
rg -n 'QUOTARADAR_DISABLE_GITHUB_UPDATER|-DQUOTARADAR_DISABLE_GITHUB_UPDATER' install.sh scripts/package_dmg.sh QuotaRadar/Services/GitHubReleaseUpdater.swift
```

- [ ] 对白牌 app bundle 执行 GitHub Release URL 扫描。这个命令必须没有输出：

```bash
if strings 'build/Quota Radar.app/Contents/MacOS/QuotaRadar' | rg 'Asklear/QuotaRadar|api\.github\.com/repos/Asklear/QuotaRadar|github\.com/Asklear/QuotaRadar/releases/latest'; then
  echo 'White-label app leaked an updater URL' >&2
  exit 1
fi
```

- [ ] 对白牌 DMG 字节执行 GitHub Release URL 扫描。这是粗粒度防线；如果命中，应阻断发版：

```bash
if strings build/QuotaRadar-WhiteLabel.dmg | rg 'Asklear/QuotaRadar|api\.github\.com/repos/Asklear/QuotaRadar|github\.com/Asklear/QuotaRadar/releases/latest'; then
  echo 'White-label DMG leaked an updater URL' >&2
  exit 1
fi
```

- [ ] 验证白牌 DMG 存在且可读：

```bash
test -s build/QuotaRadar-WhiteLabel.dmg
hdiutil verify build/QuotaRadar-WhiteLabel.dmg
```

- [ ] 验证 app 签名：

```bash
codesign --verify --deep --strict --verbose=2 'build/Quota Radar.app'
```

- [ ] 挂载白牌 DMG，确认包含 `Quota Radar.app` 和 `/Applications` 软链接，然后卸载：

```bash
MOUNT_DIR="$(mktemp -d)"
hdiutil attach build/QuotaRadar-WhiteLabel.dmg -mountpoint "$MOUNT_DIR" -nobrowse -quiet
test -d "$MOUNT_DIR/Quota Radar.app"
test -L "$MOUNT_DIR/Applications"
hdiutil detach "$MOUNT_DIR" -quiet
rmdir "$MOUNT_DIR"
```

- [ ] 除非某个发布渠道明确不需要应用内更新，否则不要把白牌产物上传为 `QuotaRadar.dmg`。

## 截图规则

- [ ] README 截图必须来自窗口级捕获，不使用整屏桌面截图。
- [ ] 透明 menu bar 弹窗不能泄露用户桌面背景。
- [ ] 英文 README 截图保存在 `docs/assets/screenshots/en/`。
- [ ] 简体中文 README 截图保存在 `docs/assets/screenshots/zh-Hans/`。
- [ ] 截图中的 provider 名、账号标签和疑似凭据文本必须使用 fixture 或已遮罩内容。
