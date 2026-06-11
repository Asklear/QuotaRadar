# Quota Radar Tauri Desktop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a cross-platform Tauri + Rust + TypeScript Quota Radar desktop client for macOS, Windows, and Linux while keeping the UI and interaction model consistent with the current macOS app.

**Architecture:** Add a new side-by-side app under `apps/desktop-tauri` instead of replacing the existing SwiftUI macOS app. React/TypeScript owns the UI and mirrors `docs/desktop-tauri-ui-spec.md`; Rust owns platform shell behavior, tray/window integration, storage, refresh scheduling, provider commands, and release/update integration. Implementation proceeds in three strict layers: UI with mock data first, then backend/storage contracts, then real provider migration.

**Tech Stack:** Tauri v2, Rust, React, TypeScript, Vite, Vitest, Testing Library, Playwright, CSS variables, lucide-react, Tauri Store/Stronghold/Updater/Autostart/Positioner plugins as needed.

---

## Source Documents And Official References

- UI source of truth: `docs/desktop-tauri-ui-spec.md`
- Existing macOS app reference:
  - `QuotaRadar/Views/MenuContentView.swift`
  - `QuotaRadar/Views/SettingsView.swift`
  - `QuotaRadar/Views/Components.swift`
  - `QuotaRadar/Models/APIKey.swift`
  - `QuotaRadar/Models/QuotaMonitor.swift`
  - `QuotaRadar/Models/AppLanguage.swift`
- Tauri official references:
  - Create project: https://v2.tauri.app/start/create-project/
  - System tray: https://v2.tauri.app/learn/system-tray/
  - Positioner plugin: https://v2.tauri.app/plugin/positioner/
  - Store plugin: https://v2.tauri.app/plugin/store/
  - Stronghold plugin: https://v2.tauri.app/plugin/stronghold/
  - Updater plugin: https://v2.tauri.app/plugin/updater/
  - Autostart plugin: https://v2.tauri.app/plugin/autostart/
  - HTTP client plugin: https://v2.tauri.app/plugin/http-client/
  - Windows installer: https://v2.tauri.app/distribute/windows-installer/

## Scope Discipline

This plan intentionally avoids a big-bang migration.

1. **UI mock first:** create a Tauri app that visually matches current Quota Radar using deterministic mock data. No real provider calls. No real secrets.
2. **Backend contracts second:** add typed Rust commands, metadata storage, secret storage, proxy settings, update state, and scheduler boundaries behind the UI.
3. **Provider migration last:** migrate provider logic incrementally, starting with API-key providers, then costly-check providers, then web-login/OAuth providers.

The existing SwiftUI macOS app remains the stable production app until the Tauri version reaches feature parity.

## Target File Structure

```text
apps/desktop-tauri/
├─ package.json
├─ index.html
├─ tsconfig.json
├─ tsconfig.node.json
├─ vite.config.ts
├─ vitest.config.ts
├─ playwright.config.ts
├─ src/
│  ├─ main.tsx
│  ├─ App.tsx
│  ├─ styles/
│  │  ├─ tokens.css
│  │  ├─ global.css
│  │  ├─ shell.css
│  │  ├─ tray.css
│  │  └─ tables.css
│  ├─ assets/
│  │  ├─ app-icon.svg
│  │  └─ providers/
│  ├─ i18n/
│  │  ├─ index.ts
│  │  └─ locales/
│  │     ├─ en.json
│  │     ├─ zh-Hans.json
│  │     ├─ zh-Hant.json
│  │     ├─ ja.json
│  │     └─ ko.json
│  ├─ shared/
│  │  ├─ types.ts
│  │  ├─ providerRegistry.ts
│  │  ├─ mockData.ts
│  │  ├─ selectors.ts
│  │  └─ status.ts
│  ├─ lib/
│  │  ├─ tauriClient.ts
│  │  ├─ clipboard.ts
│  │  └─ platform.ts
│  ├─ components/
│  │  ├─ MaterialPanel.tsx
│  │  ├─ ProviderIcon.tsx
│  │  ├─ StatusPill.tsx
│  │  ├─ IconButton.tsx
│  │  ├─ QuotaWindowDetails.tsx
│  │  └─ EmptyState.tsx
│  ├─ shell/
│  │  ├─ AppShell.tsx
│  │  ├─ Sidebar.tsx
│  │  ├─ SidebarNavItem.tsx
│  │  └─ SidebarUpdateFooter.tsx
│  ├─ tray/
│  │  ├─ TrayPopover.tsx
│  │  ├─ TrayHeader.tsx
│  │  ├─ RiskSummaryCard.tsx
│  │  └─ AttentionList.tsx
│  ├─ pages/
│  │  ├─ QuotaMonitoringPage.tsx
│  │  ├─ CredentialsPage.tsx
│  │  ├─ DiagnosticsPage.tsx
│  │  ├─ SettingsPage.tsx
│  │  └─ AboutPage.tsx
│  ├─ quota/
│  │  ├─ ProviderCategorySection.tsx
│  │  ├─ ProviderQuotaTable.tsx
│  │  ├─ ProviderQuotaRow.tsx
│  │  └─ CredentialDetailTable.tsx
│  ├─ credentials/
│  │  ├─ ProviderCredentialGroup.tsx
│  │  ├─ CredentialRow.tsx
│  │  └─ CredentialEditorDialog.tsx
│  ├─ diagnostics/
│  │  ├─ DiagnosticProviderSection.tsx
│  │  └─ DiagnosticRow.tsx
│  └─ settings/
│     ├─ SettingsSection.tsx
│     ├─ ProviderOrderDialog.tsx
│     └─ PreferenceRow.tsx
├─ tests/
│  ├─ unit/
│  ├─ integration/
│  └─ e2e/
└─ src-tauri/
   ├─ Cargo.toml
   ├─ tauri.conf.json
   ├─ capabilities/
   │  └─ default.json
   ├─ icons/
   └─ src/
      ├─ main.rs
      ├─ lib.rs
      ├─ commands/
      │  ├─ mod.rs
      │  ├─ app_state.rs
      │  ├─ credentials.rs
      │  ├─ providers.rs
      │  ├─ settings.rs
      │  └─ updates.rs
      ├─ domain/
      │  ├─ mod.rs
      │  ├─ provider.rs
      │  ├─ credential.rs
      │  ├─ quota.rs
      │  ├─ diagnostics.rs
      │  └─ settings.rs
      ├─ storage/
      │  ├─ mod.rs
      │  ├─ metadata_store.rs
      │  └─ secret_store.rs
      ├─ providers/
      │  ├─ mod.rs
      │  ├─ registry.rs
      │  ├─ tavily.rs
      │  ├─ brave.rs
      │  └─ deepseek.rs
      ├─ platform/
      │  ├─ mod.rs
      │  ├─ tray.rs
      │  ├─ windows.rs
      │  ├─ macos.rs
      │  └─ linux.rs
      └─ scheduler/
         ├─ mod.rs
         └─ refresh_scheduler.rs
```

Root-level files may be added only when they help workspace execution:

```text
pnpm-workspace.yaml
package.json
.github/workflows/desktop-tauri.yml
scripts/check_tauri_sources.sh
```

Do not move or rewrite the existing SwiftUI app during this plan.

## Shared Data Contracts

The first UI mock phase should define these TypeScript contracts. Rust should later mirror them with Serde structs instead of inventing different shapes.

```ts
export type ProviderCategory = "AI Search" | "LLM";

export type CredentialKind =
  | "apiKey"
  | "dashboardCookie"
  | "adminCredential"
  | "storedAPIKeyOnly";

export type CredentialStatus =
  | "healthy"
  | "failed"
  | "expired"
  | "usageLimitExceeded"
  | "disabled"
  | "unknownQuotaUsable"
  | "notChecked"
  | "unsupported"
  | "noSubscribedPlan"
  | "manualRefreshOnly";

export interface ProviderDefinition {
  id: string;
  displayName: string;
  familyName: string;
  category: ProviderCategory;
  planType?: string;
  icon: string;
  dashboardUrl?: string;
  supportsReauth: boolean;
  supportsRefresh: boolean;
  quotaCheckConsumesSearchQuota: boolean;
}

export interface QuotaWindow {
  name: "5h" | "week" | "month" | string;
  percentRemaining?: number;
  remainingText?: string;
  resetAt?: string;
}

export interface CredentialView {
  id: string;
  providerId: string;
  name: string;
  kind: CredentialKind;
  maskedValue: string;
  copyable: boolean;
  active: boolean;
  status: CredentialStatus;
  remaining?: number;
  limit?: number;
  remainingBadgeText: string;
  quotaLabel?: string;
  quotaWindows: QuotaWindow[];
  resetAt?: string;
  planEndsAt?: string;
  lastUpdated?: string;
  lastHttpStatus?: number;
  diagnosticMessage?: string;
  note?: string;
  linkedAuthorizationId?: string;
}

export interface ProviderStats {
  provider: ProviderDefinition;
  credentials: CredentialView[];
  keyQuotaText: string;
  credentialPoolText: string;
  criticalTimeText: string;
  statusText: string;
  needsAttention: boolean;
}
```

## Test Strategy

Use three layers of tests:

```text
Unit tests:
- provider registry
- selectors and provider summary logic
- i18n completeness
- credential masking/copyability

Component tests:
- sidebar navigation order
- tray popover summary
- quota monitoring table
- credentials rows/action order
- diagnostics rows
- settings controls

End-to-end tests:
- app starts
- tray window opens
- main window navigation
- provider order drag flow
- add credential mock flow
- language switch updates visible text
```

Recommended commands:

```bash
cd apps/desktop-tauri
pnpm test
pnpm test:e2e
pnpm lint
pnpm typecheck
pnpm tauri dev
pnpm tauri build
cargo test --manifest-path src-tauri/Cargo.toml
```

## Phase 0: Baseline And Workspace Guard

### Task 0.1: Confirm Worktree Baseline

**Files:**
- Read: `docs/desktop-tauri-ui-spec.md`
- Read: `Package.swift`
- Read: `Tests/run_behavior_tests.sh`

- [ ] **Step 1: Confirm the worktree is clean**

Run:

```bash
git status --short
git branch --show-current
```

Expected:

```text
feat/tauri-multiplatform
```

No tracked or untracked files except the intentional plan work.

- [ ] **Step 2: Run existing macOS baseline tests**

Run:

```bash
bash Tests/run_behavior_tests.sh
```

Expected: `All behavior tests passed`.

- [ ] **Step 3: Commit only if a baseline guard file is added**

Usually no commit is needed for this task.

## Phase 1: UI Mock MVP

This phase creates a visually useful cross-platform shell without real provider calls. It should be safe to run anywhere and should not require credentials.

### Task 1: Scaffold Tauri React App

**Files:**
- Create: `apps/desktop-tauri/package.json`
- Create: `apps/desktop-tauri/index.html`
- Create: `apps/desktop-tauri/src/main.tsx`
- Create: `apps/desktop-tauri/src/App.tsx`
- Create: `apps/desktop-tauri/src-tauri/Cargo.toml`
- Create: `apps/desktop-tauri/src-tauri/tauri.conf.json`
- Create: `apps/desktop-tauri/src-tauri/src/main.rs`
- Create: `apps/desktop-tauri/src-tauri/src/lib.rs`
- Create: `apps/desktop-tauri/vite.config.ts`
- Create: `apps/desktop-tauri/tsconfig.json`
- Create: `apps/desktop-tauri/vitest.config.ts`
- Test: `apps/desktop-tauri/tests/unit/smoke.test.tsx`

- [ ] **Step 1: Scaffold with Tauri v2 + React + TypeScript**

Use the official Tauri project flow as reference, but keep generated files under `apps/desktop-tauri`.

Run:

```bash
mkdir -p apps/desktop-tauri
cd apps/desktop-tauri
pnpm create vite . --template react-ts
pnpm add @tauri-apps/api lucide-react
pnpm add -D @tauri-apps/cli vitest @testing-library/react @testing-library/jest-dom jsdom typescript
pnpm tauri init
```

Expected:

- `apps/desktop-tauri/src-tauri` exists.
- `apps/desktop-tauri/package.json` has `tauri`, `dev`, `build`, `test`, and `typecheck` scripts.

- [ ] **Step 2: Configure app metadata**

Set in `apps/desktop-tauri/src-tauri/tauri.conf.json`:

```json
{
  "productName": "Quota Radar",
  "identifier": "ai.asklear.quotaradar.desktop",
  "app": {
    "windows": [
      {
        "label": "main",
        "title": "Quota Radar",
        "width": 1120,
        "height": 640,
        "minWidth": 900,
        "minHeight": 600
      }
    ]
  }
}
```

- [ ] **Step 3: Add a failing smoke test**

Create `apps/desktop-tauri/tests/unit/smoke.test.tsx`:

```tsx
import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import App from "../../src/App";

describe("App", () => {
  it("renders Quota Radar shell", () => {
    render(<App />);
    expect(screen.getByText("Quota Radar")).toBeInTheDocument();
  });
});
```

Run:

```bash
cd apps/desktop-tauri
pnpm test -- --run
```

Expected: FAIL until `App.tsx` renders the title.

- [ ] **Step 4: Implement minimal shell**

`apps/desktop-tauri/src/App.tsx`:

```tsx
export default function App() {
  return <main>Quota Radar</main>;
}
```

- [ ] **Step 5: Verify**

Run:

```bash
cd apps/desktop-tauri
pnpm test -- --run
pnpm typecheck
pnpm tauri dev
```

Expected:

- tests pass.
- typecheck passes.
- Tauri opens a window titled `Quota Radar`.

- [ ] **Step 6: Commit**

```bash
git add apps/desktop-tauri
git commit -m "feat: scaffold Tauri desktop app"
```

### Task 2: Add UI Tokens, Layout Foundation, And i18n

**Files:**
- Create: `apps/desktop-tauri/src/styles/tokens.css`
- Create: `apps/desktop-tauri/src/styles/global.css`
- Create: `apps/desktop-tauri/src/styles/shell.css`
- Create: `apps/desktop-tauri/src/i18n/index.ts`
- Create: `apps/desktop-tauri/src/i18n/locales/en.json`
- Create: `apps/desktop-tauri/src/i18n/locales/zh-Hans.json`
- Create: `apps/desktop-tauri/src/i18n/locales/zh-Hant.json`
- Create: `apps/desktop-tauri/src/i18n/locales/ja.json`
- Create: `apps/desktop-tauri/src/i18n/locales/ko.json`
- Modify: `apps/desktop-tauri/src/main.tsx`
- Test: `apps/desktop-tauri/tests/unit/i18n.test.ts`

- [ ] **Step 1: Write failing i18n completeness test**

Create `apps/desktop-tauri/tests/unit/i18n.test.ts`:

```ts
import { describe, expect, it } from "vitest";
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
});
```

Run:

```bash
cd apps/desktop-tauri
pnpm test -- --run tests/unit/i18n.test.ts
```

Expected: FAIL because locale files are missing.

- [ ] **Step 2: Add initial locale keys**

Minimum keys:

```json
{
  "app.name": "Quota Radar",
  "app.subtitle": "API Quota",
  "nav.quotaMonitoring": "Quota Monitoring",
  "nav.credentials": "Credentials",
  "nav.diagnostics": "Diagnostics",
  "nav.settings": "Settings",
  "status.available": "Available",
  "status.low": "Low",
  "status.failed": "Failed",
  "status.healthy": "Healthy",
  "quota.keyQuota": "Key Quota",
  "quota.credentialPool": "Credential Pool",
  "quota.criticalTime": "Critical Time",
  "quota.status": "Status"
}
```

Translate the same keys in all locales. Do not leave English fallback text in non-English files.

- [ ] **Step 3: Add design tokens**

`tokens.css` must include:

```css
:root {
  --qr-sidebar-width: 220px;
  --qr-main-min-width: 900px;
  --qr-main-min-height: 600px;
  --qr-tray-width: 560px;
  --qr-tray-height: 500px;
  --qr-radius-panel: 12px;
  --qr-radius-popover: 20px;
  --qr-color-healthy: #34c759;
  --qr-color-attention: #ff3b30;
  --qr-color-warning: #ff9f0a;
}
```

- [ ] **Step 4: Verify**

Run:

```bash
cd apps/desktop-tauri
pnpm test -- --run
pnpm typecheck
```

Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add apps/desktop-tauri/src apps/desktop-tauri/tests
git commit -m "feat: add desktop UI tokens and i18n"
```

### Task 3: Add Mock DTOs, Provider Registry, And Selectors

**Files:**
- Create: `apps/desktop-tauri/src/shared/types.ts`
- Create: `apps/desktop-tauri/src/shared/providerRegistry.ts`
- Create: `apps/desktop-tauri/src/shared/mockData.ts`
- Create: `apps/desktop-tauri/src/shared/status.ts`
- Create: `apps/desktop-tauri/src/shared/selectors.ts`
- Test: `apps/desktop-tauri/tests/unit/selectors.test.ts`

- [ ] **Step 1: Write failing provider summary tests**

Create `apps/desktop-tauri/tests/unit/selectors.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { buildProviderStats, buildMenuSummary } from "../../src/shared/selectors";
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
    expect(summary.availableCount).toBeGreaterThanOrEqual(1);
  });
});
```

Run:

```bash
cd apps/desktop-tauri
pnpm test -- --run tests/unit/selectors.test.ts
```

Expected: FAIL because selectors do not exist.

- [ ] **Step 2: Implement DTOs and mock data**

Use the `Shared Data Contracts` section above. Mock data must include:

- Tavily healthy.
- Brave low or costly-check example.
- SerpAPI healthy.
- Bocha money balance.
- Claude subscription with 5h/week windows.
- Codex subscription with one failed/expired example.
- Kimi subscription with percent-only month balance.
- At least one provider with companion API key and web login authorization.

- [ ] **Step 3: Implement selectors**

Selectors must mirror current Swift behavior:

- unconfigured providers hidden.
- provider summary uses tightest credential/window.
- `needsAttention` true if any active credential is expired, exhausted, failed, usage-limited, or low.
- unlimited credential does not hide a failed finite credential.
- provider order follows registry order until custom order is introduced.

- [ ] **Step 4: Verify**

Run:

```bash
cd apps/desktop-tauri
pnpm test -- --run tests/unit/selectors.test.ts
pnpm typecheck
```

Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add apps/desktop-tauri/src/shared apps/desktop-tauri/tests/unit/selectors.test.ts
git commit -m "feat: add mock provider quota selectors"
```

### Task 4: Build Main Window Shell And Sidebar

**Files:**
- Create: `apps/desktop-tauri/src/shell/AppShell.tsx`
- Create: `apps/desktop-tauri/src/shell/Sidebar.tsx`
- Create: `apps/desktop-tauri/src/shell/SidebarNavItem.tsx`
- Create: `apps/desktop-tauri/src/shell/SidebarUpdateFooter.tsx`
- Modify: `apps/desktop-tauri/src/App.tsx`
- Modify: `apps/desktop-tauri/src/styles/shell.css`
- Test: `apps/desktop-tauri/tests/unit/sidebar.test.tsx`

- [ ] **Step 1: Write failing sidebar test**

Test:

```tsx
import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { AppShell } from "../../src/shell/AppShell";

describe("AppShell", () => {
  it("renders navigation in the product order", () => {
    render(<AppShell />);
    const labels = screen.getAllByRole("button").map((button) => button.textContent);
    expect(labels.join("|")).toContain("Quota Monitoring|Credentials|Diagnostics|Settings");
  });
});
```

Run:

```bash
cd apps/desktop-tauri
pnpm test -- --run tests/unit/sidebar.test.tsx
```

Expected: FAIL.

- [ ] **Step 2: Implement shell**

Requirements:

- sidebar fixed at `220px`.
- content min size follows spec.
- header shows app icon, `Quota Radar`, and localized subtitle.
- metrics show credentials, providers, low count.
- footer shows version/update status and manual update icon.

- [ ] **Step 3: Verify**

Run:

```bash
cd apps/desktop-tauri
pnpm test -- --run tests/unit/sidebar.test.tsx
pnpm typecheck
```

Expected: pass.

- [ ] **Step 4: Commit**

```bash
git add apps/desktop-tauri/src/shell apps/desktop-tauri/src/App.tsx apps/desktop-tauri/src/styles apps/desktop-tauri/tests
git commit -m "feat: add desktop shell and sidebar"
```

### Task 5: Build Quota Monitoring Mock Page

**Files:**
- Create: `apps/desktop-tauri/src/pages/QuotaMonitoringPage.tsx`
- Create: `apps/desktop-tauri/src/quota/ProviderCategorySection.tsx`
- Create: `apps/desktop-tauri/src/quota/ProviderQuotaTable.tsx`
- Create: `apps/desktop-tauri/src/quota/ProviderQuotaRow.tsx`
- Create: `apps/desktop-tauri/src/quota/CredentialDetailTable.tsx`
- Create: `apps/desktop-tauri/src/components/QuotaWindowDetails.tsx`
- Create: `apps/desktop-tauri/src/components/StatusPill.tsx`
- Create: `apps/desktop-tauri/src/components/ProviderIcon.tsx`
- Test: `apps/desktop-tauri/tests/unit/quota-monitoring.test.tsx`

- [ ] **Step 1: Write failing quota page tests**

Assertions:

- AI Search section appears before LLM.
- table headers are Provider, Key Quota, Credential Pool, Critical Time, Status.
- unconfigured provider is not rendered.
- provider row can expand to credential detail.

- [ ] **Step 2: Implement page using mock selectors**

Requirements:

- row click toggles expand/collapse.
- no triangle-only collapse control.
- summary status uses green/red only.
- action reserve area exists for dashboard/reauth/refresh.
- expanded detail shows credential rows and quota window details once.

- [ ] **Step 3: Verify**

Run:

```bash
cd apps/desktop-tauri
pnpm test -- --run tests/unit/quota-monitoring.test.tsx
pnpm typecheck
```

- [ ] **Step 4: Commit**

```bash
git add apps/desktop-tauri/src/pages/QuotaMonitoringPage.tsx apps/desktop-tauri/src/quota apps/desktop-tauri/src/components apps/desktop-tauri/tests
git commit -m "feat: add mock quota monitoring page"
```

### Task 6: Build Tray Popover Mock UI

**Files:**
- Create: `apps/desktop-tauri/src/tray/TrayPopover.tsx`
- Create: `apps/desktop-tauri/src/tray/TrayHeader.tsx`
- Create: `apps/desktop-tauri/src/tray/RiskSummaryCard.tsx`
- Create: `apps/desktop-tauri/src/tray/AttentionList.tsx`
- Create: `apps/desktop-tauri/src/styles/tray.css`
- Test: `apps/desktop-tauri/tests/unit/tray-popover.test.tsx`

- [ ] **Step 1: Write failing tray tests**

Assertions:

- popover has fixed root size tokens `560 x 500`.
- header shows app mark, localized title, quote, and settings action.
- risk summary shows Low, Failed, Available.
- low quota list is limited to 3.
- expiring list is limited to 3.
- needs-attention list is limited to 2.

- [ ] **Step 2: Implement tray UI from mock data**

The tray popover should not render the full provider grid by default. It renders risk summary and top attention lists only.

- [ ] **Step 3: Verify**

Run:

```bash
cd apps/desktop-tauri
pnpm test -- --run tests/unit/tray-popover.test.tsx
pnpm typecheck
```

- [ ] **Step 4: Commit**

```bash
git add apps/desktop-tauri/src/tray apps/desktop-tauri/src/styles/tray.css apps/desktop-tauri/tests
git commit -m "feat: add mock tray quota popover"
```

### Task 7: Build Credentials Mock Page And Editor Dialog

**Files:**
- Create: `apps/desktop-tauri/src/pages/CredentialsPage.tsx`
- Create: `apps/desktop-tauri/src/credentials/ProviderCredentialGroup.tsx`
- Create: `apps/desktop-tauri/src/credentials/CredentialRow.tsx`
- Create: `apps/desktop-tauri/src/credentials/CredentialEditorDialog.tsx`
- Test: `apps/desktop-tauri/tests/unit/credentials.test.tsx`

- [ ] **Step 1: Write failing credentials tests**

Assertions:

- unconfigured providers are hidden.
- provider banner toggles collapse.
- credential action order is Status, Enabled, Copy, Edit.
- copy is hidden for web login authorization.
- companion API key is visually distinct from web login authorization.

- [ ] **Step 2: Implement credentials page**

Requirements:

- top action panel: Add Credential, Import `.env`.
- groups by provider.
- status pill width stable.
- enabled switch.
- copy only safe copyable credential.
- edit opens mock dialog.

- [ ] **Step 3: Implement editor dialog shell**

Requirements:

- `760 x 540`.
- provider list width `220`.
- header fixed.
- footer fixed.
- detail form scrolls.
- secret fields hidden by default with eye toggle.
- dashboard login authorization is labelled as web login authorization, not API key.

- [ ] **Step 4: Verify**

Run:

```bash
cd apps/desktop-tauri
pnpm test -- --run tests/unit/credentials.test.tsx
pnpm typecheck
```

- [ ] **Step 5: Commit**

```bash
git add apps/desktop-tauri/src/pages/CredentialsPage.tsx apps/desktop-tauri/src/credentials apps/desktop-tauri/tests
git commit -m "feat: add mock credential management UI"
```

### Task 8: Build Diagnostics, Settings, Provider Order, And About Mock Pages

**Files:**
- Create: `apps/desktop-tauri/src/pages/DiagnosticsPage.tsx`
- Create: `apps/desktop-tauri/src/pages/SettingsPage.tsx`
- Create: `apps/desktop-tauri/src/pages/AboutPage.tsx`
- Create: `apps/desktop-tauri/src/diagnostics/DiagnosticProviderSection.tsx`
- Create: `apps/desktop-tauri/src/diagnostics/DiagnosticRow.tsx`
- Create: `apps/desktop-tauri/src/settings/SettingsSection.tsx`
- Create: `apps/desktop-tauri/src/settings/PreferenceRow.tsx`
- Create: `apps/desktop-tauri/src/settings/ProviderOrderDialog.tsx`
- Test: `apps/desktop-tauri/tests/unit/settings-diagnostics.test.tsx`

- [ ] **Step 1: Write failing tests**

Assertions:

- diagnostics does not duplicate quota values.
- diagnostics shows health and HTTP status.
- settings includes language, custom provider order, launch at login, update check, refresh, costly refresh, proxy, and transparency.
- provider order dialog separates AI Search and LLM.

- [ ] **Step 2: Implement mock pages**

All controls may update local React state only in this phase.

- [ ] **Step 3: Verify**

Run:

```bash
cd apps/desktop-tauri
pnpm test -- --run tests/unit/settings-diagnostics.test.tsx
pnpm typecheck
```

- [ ] **Step 4: Commit**

```bash
git add apps/desktop-tauri/src/pages apps/desktop-tauri/src/diagnostics apps/desktop-tauri/src/settings apps/desktop-tauri/tests
git commit -m "feat: add mock diagnostics and settings UI"
```

### Task 9: Add Mock UI End-To-End Screenshot QA

**Files:**
- Create: `apps/desktop-tauri/playwright.config.ts`
- Create: `apps/desktop-tauri/tests/e2e/main-window.spec.ts`
- Create: `apps/desktop-tauri/tests/e2e/tray-popover.spec.ts`
- Create: `apps/desktop-tauri/tests/e2e/screenshots/.gitkeep`
- Modify: `apps/desktop-tauri/package.json`

- [ ] **Step 1: Add Playwright scripts**

`package.json` scripts:

```json
{
  "test:e2e": "playwright test",
  "test:e2e:update": "playwright test --update-snapshots"
}
```

- [ ] **Step 2: Write e2e checks**

Cover:

- main window renders sidebar and quota page.
- switching nav updates content.
- tray route renders fixed-size popover.
- no text overlaps obvious controls at desktop viewport.

- [ ] **Step 3: Verify**

Run:

```bash
cd apps/desktop-tauri
pnpm test:e2e
```

Expected: pass locally with generated artifacts in ignored output directories.

- [ ] **Step 4: Commit**

```bash
git add apps/desktop-tauri/playwright.config.ts apps/desktop-tauri/tests/e2e apps/desktop-tauri/package.json
git commit -m "test: add desktop UI screenshot QA"
```

## Phase 2: Rust Backend Contracts And Platform Shell

### Task 10: Add Tauri Commands With Mock Backend State

**Files:**
- Create: `apps/desktop-tauri/src/lib/tauriClient.ts`
- Create: `apps/desktop-tauri/src-tauri/src/domain/mod.rs`
- Create: `apps/desktop-tauri/src-tauri/src/domain/provider.rs`
- Create: `apps/desktop-tauri/src-tauri/src/domain/credential.rs`
- Create: `apps/desktop-tauri/src-tauri/src/domain/quota.rs`
- Create: `apps/desktop-tauri/src-tauri/src/domain/diagnostics.rs`
- Create: `apps/desktop-tauri/src-tauri/src/commands/mod.rs`
- Create: `apps/desktop-tauri/src-tauri/src/commands/app_state.rs`
- Modify: `apps/desktop-tauri/src-tauri/src/lib.rs`
- Test: `apps/desktop-tauri/src-tauri/src/domain/tests.rs`
- Test: `apps/desktop-tauri/tests/integration/tauri-client.test.ts`

- [ ] **Step 1: Write Rust DTO tests**

Test serde serialization for provider stats and credential views.

- [ ] **Step 2: Write frontend integration test**

Mock `@tauri-apps/api/core.invoke` and assert `getAppState()` returns typed state.

- [ ] **Step 3: Implement `get_app_state` command**

Return the same mock data shape used by the UI.

- [ ] **Step 4: Swap UI data source**

Use Tauri command when available; fall back to local mock data in browser test mode.

- [ ] **Step 5: Verify**

Run:

```bash
cd apps/desktop-tauri
pnpm test -- --run
cargo test --manifest-path src-tauri/Cargo.toml
pnpm tauri dev
```

- [ ] **Step 6: Commit**

```bash
git add apps/desktop-tauri/src apps/desktop-tauri/src-tauri apps/desktop-tauri/tests
git commit -m "feat: add typed Tauri app state commands"
```

### Task 11: Add Tray Window And Platform Window Behavior

**Files:**
- Create: `apps/desktop-tauri/src-tauri/src/platform/tray.rs`
- Create: `apps/desktop-tauri/src-tauri/src/platform/mod.rs`
- Modify: `apps/desktop-tauri/src-tauri/src/lib.rs`
- Modify: `apps/desktop-tauri/src/App.tsx`
- Modify: `apps/desktop-tauri/src/lib/platform.ts`
- Test: `apps/desktop-tauri/src-tauri/src/platform/tests.rs`

- [ ] **Step 1: Add plugin dependencies**

Use Tauri tray support and `tauri-plugin-positioner` for tray-relative positioning where supported.

Run:

```bash
cd apps/desktop-tauri
pnpm tauri add positioner
```

- [ ] **Step 2: Create two window modes**

Routes or labels:

```text
main: full app shell
tray: compact tray popover
```

The tray window should be undecorated, fixed around `560 x 500`, and hidden by default.

- [ ] **Step 3: Wire tray click behavior**

Tray click toggles tray window:

- show near tray icon if available.
- fallback to current monitor work area.
- hide on blur or pointer leave.

- [ ] **Step 4: Verify**

Run:

```bash
cd apps/desktop-tauri
pnpm tauri dev
```

Manual expected:

- tray icon appears.
- click opens compact popover.
- main window remains accessible.

- [ ] **Step 5: Commit**

```bash
git add apps/desktop-tauri/src apps/desktop-tauri/src-tauri apps/desktop-tauri/package.json apps/desktop-tauri/pnpm-lock.yaml
git commit -m "feat: add cross-platform tray popover shell"
```

### Task 12: Add Settings Persistence And Provider Order Persistence

**Files:**
- Create: `apps/desktop-tauri/src-tauri/src/domain/settings.rs`
- Create: `apps/desktop-tauri/src-tauri/src/commands/settings.rs`
- Create: `apps/desktop-tauri/src-tauri/src/storage/metadata_store.rs`
- Create: `apps/desktop-tauri/src-tauri/src/storage/mod.rs`
- Modify: `apps/desktop-tauri/src/pages/SettingsPage.tsx`
- Modify: `apps/desktop-tauri/src/settings/ProviderOrderDialog.tsx`
- Test: `apps/desktop-tauri/src-tauri/src/storage/metadata_store_tests.rs`
- Test: `apps/desktop-tauri/tests/integration/settings.test.ts`

- [ ] **Step 1: Add store plugin**

Use the Tauri Store plugin for non-secret settings.

Run:

```bash
cd apps/desktop-tauri
pnpm tauri add store
```

- [ ] **Step 2: Write failing tests**

Cover:

- provider order round trips.
- language setting round trips.
- proxy mode round trips.
- refresh intervals round trip.

- [ ] **Step 3: Implement settings commands**

Commands:

```text
get_settings
update_settings
reset_provider_order
move_provider
```

- [ ] **Step 4: Verify**

Run:

```bash
cd apps/desktop-tauri
pnpm test -- --run tests/integration/settings.test.ts
cargo test --manifest-path src-tauri/Cargo.toml
```

- [ ] **Step 5: Commit**

```bash
git add apps/desktop-tauri/src apps/desktop-tauri/src-tauri apps/desktop-tauri/package.json apps/desktop-tauri/pnpm-lock.yaml
git commit -m "feat: persist desktop settings and provider order"
```

### Task 13: Add Credential Metadata And Secret Storage

**Files:**
- Create: `apps/desktop-tauri/src-tauri/src/storage/secret_store.rs`
- Create: `apps/desktop-tauri/src-tauri/src/commands/credentials.rs`
- Modify: `apps/desktop-tauri/src/credentials/CredentialEditorDialog.tsx`
- Modify: `apps/desktop-tauri/src/pages/CredentialsPage.tsx`
- Test: `apps/desktop-tauri/src-tauri/src/storage/secret_store_tests.rs`
- Test: `apps/desktop-tauri/tests/integration/credentials.test.ts`

- [ ] **Step 1: Add secret storage dependency**

Prefer Tauri Stronghold for cross-platform encrypted local secrets. If Stronghold UX is too heavy for the first MVP, keep a feature-gated fallback that stores secrets in an OS-protected app data file and document the tradeoff.

Run:

```bash
cd apps/desktop-tauri
pnpm tauri add stronghold
```

- [ ] **Step 2: Write failing secret tests**

Cover:

- metadata does not contain raw secret.
- API key can be saved and loaded by id.
- dashboard authorization is not copyable.
- companion API key links to authorization id.

- [ ] **Step 3: Implement commands**

Commands:

```text
list_credentials
create_credential
update_credential
delete_credential
set_credential_active
copy_credential_value
```

Only `copy_credential_value` returns secret material, and only for copyable credential kinds.

- [ ] **Step 4: Wire UI**

Replace mock edit/add behavior with command calls. Keep optimistic UI small; reload state after save.

- [ ] **Step 5: Verify**

Run:

```bash
cd apps/desktop-tauri
pnpm test -- --run tests/integration/credentials.test.ts
cargo test --manifest-path src-tauri/Cargo.toml
```

- [ ] **Step 6: Commit**

```bash
git add apps/desktop-tauri/src apps/desktop-tauri/src-tauri apps/desktop-tauri/package.json apps/desktop-tauri/pnpm-lock.yaml
git commit -m "feat: add desktop credential storage"
```

### Task 14: Add Refresh Scheduler, Proxy Settings, And Update State

**Files:**
- Create: `apps/desktop-tauri/src-tauri/src/scheduler/refresh_scheduler.rs`
- Create: `apps/desktop-tauri/src-tauri/src/scheduler/mod.rs`
- Create: `apps/desktop-tauri/src-tauri/src/commands/updates.rs`
- Modify: `apps/desktop-tauri/src-tauri/src/domain/settings.rs`
- Modify: `apps/desktop-tauri/src/pages/SettingsPage.tsx`
- Modify: `apps/desktop-tauri/src/shell/SidebarUpdateFooter.tsx`
- Test: `apps/desktop-tauri/src-tauri/src/scheduler/tests.rs`
- Test: `apps/desktop-tauri/tests/integration/update-refresh-settings.test.ts`

- [ ] **Step 1: Add updater and autostart plugins**

Run:

```bash
cd apps/desktop-tauri
pnpm tauri add updater
pnpm tauri add autostart
pnpm tauri add http
```

- [ ] **Step 2: Write failing tests**

Cover:

- normal automatic refresh skips costly providers.
- costly automatic refresh defaults to off.
- update check state appears in sidebar footer.
- proxy mode accepts system/direct/custom.

- [ ] **Step 3: Implement scheduler policy**

Do not call real providers yet. The scheduler should produce planned refresh jobs against mock providers.

- [ ] **Step 4: Implement update-state commands**

Commands:

```text
check_for_updates
download_and_install_update
get_update_state
```

In this task, `download_and_install_update` may be a placeholder returning `notImplemented` until packaging is ready.

- [ ] **Step 5: Verify**

Run:

```bash
cd apps/desktop-tauri
pnpm test -- --run tests/integration/update-refresh-settings.test.ts
cargo test --manifest-path src-tauri/Cargo.toml
```

- [ ] **Step 6: Commit**

```bash
git add apps/desktop-tauri/src apps/desktop-tauri/src-tauri apps/desktop-tauri/package.json apps/desktop-tauri/pnpm-lock.yaml
git commit -m "feat: add refresh and update settings backend"
```

## Phase 3: Provider Migration

### Task 15: Add Provider Trait And API-Key Provider Registry

**Files:**
- Create: `apps/desktop-tauri/src-tauri/src/providers/mod.rs`
- Create: `apps/desktop-tauri/src-tauri/src/providers/registry.rs`
- Create: `apps/desktop-tauri/src-tauri/src/providers/tavily.rs`
- Create: `apps/desktop-tauri/src-tauri/src/providers/deepseek.rs`
- Create: `apps/desktop-tauri/src-tauri/src/commands/providers.rs`
- Test: `apps/desktop-tauri/src-tauri/src/providers/tests.rs`

- [ ] **Step 1: Define provider trait**

Rust shape:

```rust
#[async_trait::async_trait]
pub trait ProviderClient: Send + Sync {
    fn provider_id(&self) -> &'static str;
    fn consumes_quota_on_check(&self) -> bool;
    async fn check_quota(&self, credential: ProviderCredential) -> Result<QuotaSnapshot, ProviderError>;
}
```

- [ ] **Step 2: Write failing provider registry tests**

Cover:

- visible provider registry excludes pending providers.
- `tavily` and `deepseek` are registered.
- `consumes_quota_on_check` is false for normal usage endpoints.

- [ ] **Step 3: Implement first no-cost providers**

Start with two easier providers:

- Tavily monthly credits.
- DeepSeek RMB balance.

Use fixtures first. Do not use real keys in tests.

- [ ] **Step 4: Verify**

Run:

```bash
cd apps/desktop-tauri
cargo test --manifest-path src-tauri/Cargo.toml providers
```

- [ ] **Step 5: Commit**

```bash
git add apps/desktop-tauri/src-tauri/src/providers apps/desktop-tauri/src-tauri/src/commands
git commit -m "feat: add first Tauri provider clients"
```

### Task 16: Wire Real Refresh Command For No-Cost Providers

**Files:**
- Modify: `apps/desktop-tauri/src-tauri/src/commands/providers.rs`
- Modify: `apps/desktop-tauri/src-tauri/src/commands/app_state.rs`
- Modify: `apps/desktop-tauri/src/pages/QuotaMonitoringPage.tsx`
- Modify: `apps/desktop-tauri/src/quota/ProviderQuotaRow.tsx`
- Test: `apps/desktop-tauri/tests/integration/refresh-provider.test.ts`

- [ ] **Step 1: Write failing integration test**

Mock invoke should assert:

- clicking refresh calls `refresh_provider`.
- refreshed provider updates last updated.
- failed refresh updates diagnostics.

- [ ] **Step 2: Implement `refresh_provider` command**

Command receives provider id and refresh mode:

```text
refresh_provider(provider_id, mode)
```

It should:

- load active credentials.
- skip stored-API-key-only credentials.
- call provider client.
- update metadata snapshot.
- return updated app state.

- [ ] **Step 3: Verify**

Run:

```bash
cd apps/desktop-tauri
pnpm test -- --run tests/integration/refresh-provider.test.ts
cargo test --manifest-path src-tauri/Cargo.toml
```

- [ ] **Step 4: Commit**

```bash
git add apps/desktop-tauri/src apps/desktop-tauri/src-tauri apps/desktop-tauri/tests
git commit -m "feat: refresh real no-cost provider quotas"
```

### Task 17: Add Costly-Check Providers And Confirmation Policy

**Files:**
- Create: `apps/desktop-tauri/src-tauri/src/providers/brave.rs`
- Modify: `apps/desktop-tauri/src-tauri/src/providers/registry.rs`
- Modify: `apps/desktop-tauri/src/shared/providerRegistry.ts`
- Modify: `apps/desktop-tauri/src/pages/SettingsPage.tsx`
- Test: `apps/desktop-tauri/src-tauri/src/providers/brave_tests.rs`
- Test: `apps/desktop-tauri/tests/integration/costly-refresh.test.ts`

- [ ] **Step 1: Write failing tests**

Cover:

- Brave reports `consumes_quota_on_check = true`.
- normal automatic refresh skips Brave.
- manual refresh requires user-visible costly warning.
- costly automatic refresh only runs when explicitly enabled.

- [ ] **Step 2: Implement Brave provider with fixtures**

Use Brave response/header fixtures. Do not run live Brave search in automated tests.

- [ ] **Step 3: Implement UI warning**

Provider row and settings should clearly show that this refresh spends a real search request.

- [ ] **Step 4: Verify**

Run:

```bash
cd apps/desktop-tauri
pnpm test -- --run tests/integration/costly-refresh.test.ts
cargo test --manifest-path src-tauri/Cargo.toml brave
```

- [ ] **Step 5: Commit**

```bash
git add apps/desktop-tauri/src apps/desktop-tauri/src-tauri apps/desktop-tauri/tests
git commit -m "feat: add costly provider refresh policy"
```

### Task 18: Migrate Remaining API-Key Providers

**Files:**
- Create: `apps/desktop-tauri/src-tauri/src/providers/serpapi.rs`
- Create: `apps/desktop-tauri/src-tauri/src/providers/serper.rs`
- Create: `apps/desktop-tauri/src-tauri/src/providers/exa.rs`
- Create: `apps/desktop-tauri/src-tauri/src/providers/bocha.rs`
- Create: `apps/desktop-tauri/src-tauri/src/providers/anysearch.rs`
- Create: `apps/desktop-tauri/src-tauri/src/providers/wxmp.rs`
- Modify: `apps/desktop-tauri/src-tauri/src/providers/registry.rs`
- Test: provider fixture tests per file.

- [ ] **Step 1: Add one provider at a time**

Order:

1. SerpAPI.
2. Serper.
3. Bocha.
4. AnySearch.
5. WeChat Search.
6. Exa management key.

- [ ] **Step 2: Add fixture before implementation**

Each provider needs:

- success fixture.
- unauthorized fixture.
- quota unavailable/unknown fixture if applicable.
- network error mapping test.

- [ ] **Step 3: Verify after each provider**

Run:

```bash
cd apps/desktop-tauri
cargo test --manifest-path src-tauri/Cargo.toml providers::<provider_name>
pnpm test -- --run
```

- [ ] **Step 4: Commit per provider or small group**

Example:

```bash
git add apps/desktop-tauri/src-tauri/src/providers
git commit -m "feat: add SerpAPI desktop quota provider"
```

### Task 18B: Wire Real HTTP Transport For API-Key Providers

**Files:**
- Modify: `apps/desktop-tauri/src-tauri/src/providers/http.rs`
- Modify: API-key provider implementations under
  `apps/desktop-tauri/src-tauri/src/providers/`
- Test: provider transport tests per provider.

- [x] **Step 1: Add shared transport seam**

The Rust provider layer now accepts a `ProviderTransport` and production
refresh uses a proxy-aware Reqwest transport. Fixture paths remain available for
unit tests and deterministic parser coverage.

- [x] **Step 2: Add no-cost provider HTTP refresh**

Tavily, SerpAPI, Serper, Bocha, WeChat Search, and DeepSeek use real endpoint
requests in the production refresh path while tests use the mock transport.

- [x] **Step 3: Add managed and costly provider HTTP refresh**

Brave now parses monthly request quota from search-probe rate-limit headers and
remains marked as a quota-consuming refresh. Exa now calls the management usage
endpoint with a service key plus target API key id; plain search API keys remain
unsupported for quota monitoring.

- [x] **Step 4: Verify**

Run from repo root:

```bash
cargo test --manifest-path apps/desktop-tauri/src-tauri/Cargo.toml
git diff --check
```

### Task 19: Add Web Login Authorization Shell

**Files:**
- Create: `apps/desktop-tauri/src-tauri/src/platform/web_auth.rs`
- Create: `apps/desktop-tauri/src-tauri/src/commands/auth.rs`
- Modify: `apps/desktop-tauri/src/credentials/CredentialEditorDialog.tsx`
- Modify: `apps/desktop-tauri/src/quota/ProviderQuotaRow.tsx`
- Test: `apps/desktop-tauri/tests/integration/web-auth-ui.test.ts`

- [ ] **Step 1: Write failing UI tests**

Cover:

- providers that support reauth show reauth button.
- reauth dialog identifies target provider/account.
- if multiple authorizations exist, user must choose target.
- saved web authorization is not copyable.

- [ ] **Step 2: Implement web auth command shell**

Commands:

```text
start_web_authorization(provider_id, target_credential_id?)
save_web_authorization(provider_id, target_credential_id?, captured_fields)
```

At this task, the webview may use a mock captured payload. Real provider capture comes later.

- [ ] **Step 3: Verify**

Run:

```bash
cd apps/desktop-tauri
pnpm test -- --run tests/integration/web-auth-ui.test.ts
cargo test --manifest-path src-tauri/Cargo.toml
```

- [ ] **Step 4: Commit**

```bash
git add apps/desktop-tauri/src apps/desktop-tauri/src-tauri apps/desktop-tauri/tests
git commit -m "feat: add web authorization command shell"
```

### Task 20: Migrate Subscription And Coding Plan Providers

**Files:**
- Create provider files under `apps/desktop-tauri/src-tauri/src/providers/`:
  - `claude_subscription.rs`
  - `codex_subscription.rs`
  - `kimi_subscription.rs`
  - `xfyun_coding_plan.rs`
  - `volcengine_coding_plan.rs`
  - `opencode_go.rs`
  - `aliyun_coding_plan.rs`
  - `tencent_cloud_coding_plan.rs`
- Test: one fixture test file per provider.

- [ ] **Step 1: Keep this phase fixture-first**

For each provider:

- add fixture for successful quota response.
- add fixture for expired credential.
- add fixture for no subscribed plan if applicable.
- add fixture for quota unknown but usable if applicable.
- assert reset and plan end parsing separately.

- [ ] **Step 2: Migrate one provider at a time**

Recommended order:

1. Kimi subscription. Done in `feat: add Kimi subscription desktop provider`.
2. Codex subscription. Done in `feat: add Codex subscription desktop provider`.
3. Claude subscription. Done in `feat: add Claude subscription desktop provider`.
4. OpenCode Go. Done in `feat: add OpenCode Go desktop provider`.
5. XFYun Spark coding plan. Done in `feat: add XFYun coding plan desktop provider`.
6. Volcengine coding plan. Done in `feat: add Volcengine coding plan desktop provider`.
7. Aliyun coding plan. Done in `feat: add Aliyun coding plan desktop provider`.
8. Tencent Cloud coding plan. Done in `feat: add Tencent Cloud coding plan desktop provider`.

Production HTTP refresh status:

- Kimi Subscription: Done. The provider calls membership and billing usage
  endpoints with saved web-login authorization and merges subscription balance,
  5-hour quota, weekly quota, reset times, and plan expiry.
- Codex Subscription: Done. The provider resolves the ChatGPT web session,
  calls the WHAM usage endpoint, and reads subscription lifecycle expiry with
  the session account id.
- Claude Subscription, OpenCode Go, XFYun Spark Coding Plan, Volcengine Coding
  Plan, Aliyun Coding Plan, Tencent Cloud Coding Plan, and Querit: Pending
  production HTTP transport.

- [ ] **Step 3: Preserve credential semantics**

Every provider must support:

- web login authorization for quota checks.
- optional companion API key when existing macOS app supports it.
- no copying of cookie/web authorization.
- explicit target selection for multiple authorizations.

- [ ] **Step 4: Verify after each provider**

Run:

```bash
cd apps/desktop-tauri
cargo test --manifest-path src-tauri/Cargo.toml <provider_name>
pnpm test -- --run
```

- [ ] **Step 5: Commit per provider**

Example:

```bash
git add apps/desktop-tauri/src-tauri/src/providers apps/desktop-tauri/src/shared
git commit -m "feat: add Kimi subscription desktop provider"
```

### Task 20B: Add Swift Configuration And Legacy Migration

**Files:**
- Create: `apps/desktop-tauri/src-tauri/src/storage/migration.rs`
- Test: `apps/desktop-tauri/src-tauri/src/storage/migration_tests.rs`
- Modify: `apps/desktop-tauri/src-tauri/src/storage/mod.rs`

- [x] **Step 1: Add fixture-first migration core**

The core accepts Swift-shaped JSON payloads rather than live local files. It
now covers:

- `apiKeyMetadata` credential metadata.
- `QuotaRadar/secrets.json` and `QuotaBar/secrets.json` secret maps.
- app language, tray transparency, automatic refresh, costly refresh, proxy
  mode/custom proxy URL, automatic update checks, and custom provider order.
- Swift `Date` numeric values encoded as seconds since `2001-01-01T00:00:00Z`.
- dashboard authorization credentials plus linked copyable companion API keys.
- the one-way QuotaBar migration marker.

- [x] **Step 2: Add macOS startup IO**

Read without logging secrets:

- `~/Library/Preferences/com.gaorongvc.quotaradar.plist`
- `~/Library/Preferences/com.gaorongvc.quotabar.plist`
- `~/Library/Application Support/QuotaRadar/secrets.json`
- `~/Library/Application Support/QuotaBar/secrets.json`

The Tauri setup path now invokes the migration core once during macOS startup
and writes a Tauri-side completion marker so later launches do not overwrite
user edits in the Tauri app.

- [ ] **Step 3: Verify**

Run:

```bash
cd apps/desktop-tauri
cargo test --manifest-path src-tauri/Cargo.toml storage::migration_tests
cargo test --manifest-path src-tauri/Cargo.toml
```

## Phase 4: Packaging, CI, And Documentation

### Task 21: Add Cross-Platform Build Scripts And CI

**Files:**
- Create: `.github/workflows/desktop-tauri.yml`
- Create: `scripts/check_tauri_sources.sh`
- Modify: `README.md`
- Modify: `README.en.md`
- Modify: `TODO.md`
- Modify: `TODO.en.md`
- Modify: `docs/provider-capabilities.md`
- Modify: `docs/provider-capabilities.en.md`

- [ ] **Step 1: Add source safety script**

Script must check:

- no real secrets.
- no hard-coded cookie/Bearer tokens.
- no skipped i18n keys.
- no dashboard cookie copy action.
- no configured provider placeholder leakage.

- [ ] **Step 2: Add CI workflow**

Matrix:

- macOS latest.
- windows latest.
- ubuntu latest.

Jobs:

```text
pnpm install
pnpm test -- --run
pnpm typecheck
cargo test
pnpm tauri build
```

- [ ] **Step 3: Update docs**

Explain:

- current Swift macOS app remains stable.
- Tauri desktop is cross-platform work-in-progress.
- Windows/Linux support status.
- no real secrets in screenshots/tests.

- [ ] **Step 4: Verify**

Run locally:

```bash
bash scripts/check_tauri_sources.sh
cd apps/desktop-tauri
pnpm test -- --run
pnpm typecheck
cargo test --manifest-path src-tauri/Cargo.toml
```

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/desktop-tauri.yml scripts/check_tauri_sources.sh README.md README.en.md TODO.md TODO.en.md docs apps/desktop-tauri
git commit -m "ci: add cross-platform Tauri desktop checks"
```

### Task 22: Add Packaging And Update Flow

**Files:**
- Modify: `apps/desktop-tauri/src-tauri/tauri.conf.json`
- Modify: `apps/desktop-tauri/src-tauri/capabilities/default.json`
- Modify: `apps/desktop-tauri/src-tauri/src/commands/updates.rs`
- Modify: `.github/workflows/desktop-tauri.yml`
- Create: `docs/desktop-tauri-release.md`

- [ ] **Step 1: Configure bundles**

Targets:

- macOS app/dmg.
- Windows NSIS or MSI.
- Linux AppImage/deb/rpm where feasible.

- [ ] **Step 2: Configure updater**

Use Tauri updater flow for signed update artifacts when ready. Until signing is solved, keep update checks informational and require explicit user confirmation.

- [ ] **Step 3: Add release docs**

Document:

- Windows signing status.
- macOS signing/notarization status.
- Linux package caveats.
- GitHub Release asset names.

- [ ] **Step 4: Verify**

Run:

```bash
cd apps/desktop-tauri
pnpm tauri build
```

Expected: platform-local bundle succeeds.

- [ ] **Step 5: Commit**

```bash
git add apps/desktop-tauri docs/desktop-tauri-release.md .github/workflows/desktop-tauri.yml
git commit -m "build: add Tauri desktop packaging plan"
```

## Phase 5: Parity Gate

### Task 23: Cross-Platform Parity Checklist

**Files:**
- Create: `docs/desktop-tauri-parity-checklist.md`
- Modify: `docs/desktop-tauri-ui-spec.md` if intentional divergence is discovered.
- Modify: `docs/desktop-tauri-implementation-plan.md` only if the implementation process changes.

- [ ] **Step 1: Create parity checklist**

Checklist sections:

- tray popover.
- main quota monitoring.
- credentials.
- diagnostics.
- settings.
- i18n.
- provider order.
- secret safety.
- costly refresh.
- update/install.
- platform-specific caveats.

- [ ] **Step 2: Run real screenshot QA**

For each platform:

- default language.
- Simplified Chinese.
- configured mock/fixture-heavy account.
- narrow minimum window.
- tray popover.

- [ ] **Step 3: Fix only parity defects**

Avoid provider expansion in this task.

- [ ] **Step 4: Commit**

```bash
git add docs/desktop-tauri-parity-checklist.md docs/desktop-tauri-ui-spec.md docs/desktop-tauri-implementation-plan.md apps/desktop-tauri
git commit -m "docs: add Tauri desktop parity checklist"
```

## Release Criteria For First Tauri Preview

First preview can ship when all are true:

- Tauri app builds locally on macOS.
- CI builds macOS, Windows, and Linux.
- UI mock pages match `docs/desktop-tauri-ui-spec.md`.
- At least five no-cost API-key providers work with fixtures and live manual checks.
- Credential metadata and secrets are separated.
- Dashboard/web login authorization values are not copyable.
- Normal automatic refresh does not call costly providers.
- i18n completeness tests pass.
- source safety scan passes.
- README clearly marks the Tauri app as preview if not feature-complete.

## Commit Policy

- Commit after each task or provider.
- Keep generated dependency lockfile changes with the task that introduced them.
- Do not mix SwiftUI macOS refactors into Tauri commits.
- Do not commit screenshots unless they are explicitly documentation assets and secrets are masked.
- Do not commit live API keys, cookies, OAuth tokens, Bearer tokens, or copied cURL with real credentials.

## Recommended First Implementation Session

Start with Phase 1 only:

1. Task 1: Scaffold Tauri React App.
2. Task 2: UI Tokens and i18n.
3. Task 3: Mock DTOs and selectors.
4. Task 4: Main Window Shell and Sidebar.
5. Task 5: Quota Monitoring Mock Page.
6. Task 6: Tray Popover Mock UI.

Stop after Task 6 for screenshot QA. Do not start real provider migration until the UI mock matches the current app closely enough.
