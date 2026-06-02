# QuotaBar 快速启动

<p align="right">
  语言：
  <strong>简体中文</strong> |
  <a href="./QUICKSTART.en.md">English</a>
</p>

## 1. 构建

在项目根目录运行：

```bash
./install.sh --bundle-only --rebuild
open build/QuotaBar.app
```

安装到 `/Applications`：

```bash
./install.sh
```

## 2. 打开界面

点击 macOS 状态栏里的 QuotaBar 电池图标。

Dock 图标会打开主窗口；状态栏弹窗用于快速查看额度。

## 3. 配置凭据

打开主窗口左侧的 `配置凭据`。

普通 provider 使用 API Key；讯飞星火、火山引擎、OpenCode Go 使用控制台会话 Cookie，不是模型调用 API key。

## 4. 从 `.env` 导入

点击页面内 `从 .env 导入`，选择包含变量的文件。

示例：

```env
TAVILY_API_KEY=...
BRAVE_API_KEY=...
DEEPSEEK_API_KEY=...
XFYUN_CODING_PLAN_COOKIE=...
VOLCENGINE_CODING_PLAN_COOKIE=...
OPENCODE_GO_COOKIE=...
```

上面的 `...` 是占位符。不要提交真实 `.env`、Cookie 或 API Key。

## 5. 观察额度

左侧 `观察额度` 页面展示各 provider 的额度概览。

状态栏弹窗按 `AI Search` 和 `LLM` 分组，可折叠 provider，并支持单个 provider 刷新。

## 6. 语言与外观

在 `语言与外观` 页面切换英文/简体中文，并调整状态栏透明度。

## 7. 本地数据位置

真实凭据文件：

```text
~/Library/Application Support/QuotaBar/secrets.json
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
