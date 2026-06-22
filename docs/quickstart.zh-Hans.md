# Quota Radar 快速启动

<p align="right">
  语言：
  <strong>简体中文</strong> |
  <a href="./quickstart.md">English</a>
</p>

## 1. 构建

在项目根目录运行：

```bash
./install.sh --bundle-only --rebuild
open 'build/Quota Radar.app'
```

安装到 `/Applications`：

```bash
./install.sh
```

## 2. 打开界面

点击 macOS 状态栏里的 Quota Radar 余量雷达图标。

Dock 图标会打开主窗口；状态栏弹窗用于快速查看额度。

## 3. 配置凭据

打开主窗口左侧的 `配置凭据`。

普通 provider 使用 API 密钥；Exa 使用用量查询专用 API key，不等同于搜索调用 key。Querit、Claude、Codex、Kimi、讯飞星火 coding plan、火山引擎 coding plan、OpenCode Go、阿里云/腾讯云 coding plan 可同时保存 API Key 和网页登录授权：API Key 用于管理和复制，网页登录授权用于额度监控。

配置页会区分 `API 密钥` 和 `额度监控授权`：复制按钮只会出现在 API 密钥行；网页登录授权只供 Quota Radar 查询额度，不会作为 API key 展示或复制。

`配置凭据` 页面只显示已经保存过凭据的 provider；还没配置的 provider 通过页面顶部的 `添加凭据` 新增。

各 provider 能查到哪些额度、重置时间和套餐结束时间，见 [Providers](./providers.zh-Hans.md)。

## 4. 从 `.env` 导入

点击页面内 `从 .env 导入`，选择包含变量的文件。

示例：

```env
TAVILY_API_KEY=...
BRAVE_API_KEY=...
DEEPSEEK_API_KEY=...
QUERIT_API_KEY=...
QUERIT_COOKIE=...
XFYUN_CODING_PLAN_COOKIE=...
VOLCENGINE_CODING_PLAN_COOKIE=...
OPENCODE_GO_COOKIE=...
ALIYUN_CODING_PLAN_API_KEY=...
TENCENT_CLOUD_CODING_PLAN_API_KEY=...
```

上面的 `...` 是占位符。不要提交真实 `.env`、Cookie 或 API Key。

网页登录授权类 provider 推荐使用应用内重新认证，或在添加凭据时粘贴浏览器复制的 cURL 自动解析。阿里云/腾讯云 coding plan 的业务 API Key 不是额度查询凭据。

## 5. 观察额度

左侧 `额度监控` 页面展示已配置 provider 的额度概览；没有保存凭据的 provider 不会在 `额度监控`、`配置凭据` 或 `诊断` 页面占位。

Provider 行按 `关键额度`、`凭据池`、`关键时间` 和 `状态` 组织。近期额度变化只显示在它描述的额度下方；展开账号行里的 `上次更新` 只显示刷新状态，例如已更新、无变化、失败或已跳过。

状态栏弹窗优先显示今日额度风险、即将到期和需要关注的凭据，并支持对单个 provider 快速刷新。

## 6. 设置

在 `设置` 页面切换简体中文、繁体中文、英文、日语、韩语，调整状态栏透明度，配置开机自启动、自动检查更新、网络代理和自动刷新间隔。也可以把自动刷新设为关闭。

网络代理支持跟随系统、直连和自定义代理。自定义代理可填写 `http://127.0.0.1:7890` 或 `socks5://127.0.0.1:7890`。

如果想让常用 provider 排在前面，可以开启 `自定义 Provider 顺序`，点击 `调整顺序` 后拖动 provider 行。这个顺序会同步到额度监控、配置凭据、诊断和状态栏弹窗。

主窗口左下角会显示当前版本和更新状态。开启自动检查更新后，应用只会检查 GitHub Release；发现新版时会先显示更新说明，不会静默下载。只有点击 `下载并安装` 后，才会下载 DMG 并覆盖安装。

## 7. 本地数据位置

真实凭据文件：

```text
~/Library/Application Support/QuotaRadar/secrets.json
```

该文件不属于代码仓库，不应该推送到 GitHub。

## 8. 测试

```bash
bash Tests/run_behavior_tests.sh
```

如果只是安装已有 bundle，不需要重新构建：

```bash
./install.sh
```

如果源码改了，需要显式重建：

```bash
./install.sh --rebuild
```
