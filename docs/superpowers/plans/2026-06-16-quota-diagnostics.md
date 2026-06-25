# Quota Diagnostics And Connection Testing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add explicit credential states, provider-level connection tests, and richer diagnostics so users can quickly understand whether each Quota Radar credential is usable, untested, expired, unsupported, costly to check, or failing.

**Architecture:** Reuse the existing provider-first model. `APIKey.swift` owns computed state and diagnostic presentation, `QuotaMonitor.swift` owns test/refresh execution, and `SettingsView.swift` renders compact labels/actions in existing credential, provider, and diagnostics rows. Persist only fields that describe actual check output; keep UI state derived.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit confirmation dialogs, local `UserDefaults` metadata, local secret store, existing bash behavior tests.

---

## File Structure

- Modify `QuotaRadar/Models/APIKey.swift`
  - Add `CredentialConfigurationState`.
  - Add computed state/diagnostic properties on `APIKey` and `CredentialDiagnosticItem`.
  - Add provider test-mode helpers if they are pure presentation.
- Modify `QuotaRadar/Models/QuotaMonitor.swift`
  - Add provider test entry points that reuse `refreshProvider` for quota checks.
  - Add local validation helper if `No-Cost Ping` is exposed.
- Modify `QuotaRadar/Views/SettingsView.swift`
  - Show explicit state labels in credential rows.
  - Add provider-level `Test Connection` action near refresh/reauthenticate.
  - Expand diagnostics rows with compact detail pills.
  - Add confirmation dialog for costly checks.
- Modify `QuotaRadar/Models/AppLanguage.swift`
  - Add localized labels for credential states, test connection, test modes, proxy mode, skipped refresh, and reset explanation.
- Modify `Tests/run_behavior_tests.sh`
  - Add structural behavior guards for the new state model, UI surfaces, costly confirmation, and diagnostics metadata.
- Optionally modify `TODO.md` and `TODO.en.md` after verification
  - Mark completed items and split follow-ups.

## Task 1: Add Credential State Presentation

**Files:**
- Modify: `QuotaRadar/Models/APIKey.swift`
- Modify: `QuotaRadar/Models/AppLanguage.swift`
- Test: `Tests/run_behavior_tests.sh`

- [ ] **Step 1: Write failing behavior assertions**

Add assertions to `Tests/run_behavior_tests.sh`:

```bash
assert_match 'enum CredentialConfigurationState' \
  "QuotaRadar/Models/APIKey.swift" \
  "Credential configuration state should be modeled explicitly"
assert_match 'var credentialConfigurationState: CredentialConfigurationState' \
  "QuotaRadar/Models/APIKey.swift" \
  "APIKey should expose a computed credential configuration state"
assert_match 'case configuredUntested' \
  "QuotaRadar/Models/APIKey.swift" \
  "Credential states should distinguish configured but untested credentials"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./Tests/run_behavior_tests.sh`

Expected: FAIL on the new assertions.

- [ ] **Step 3: Implement the state model**

Add near `KeyStatus` in `APIKey.swift`:

```swift
enum CredentialConfigurationState: String {
    case notConfigured
    case configuredUntested
    case usable
    case credentialExpired
    case quotaUnavailable
    case checkConsumesQuota
    case checkFailed

    var displayText: String {
        switch self {
        case .notConfigured: return L10n.t(.credentialStateNotConfigured)
        case .configuredUntested: return L10n.t(.credentialStateConfiguredUntested)
        case .usable: return L10n.t(.credentialStateUsable)
        case .credentialExpired: return L10n.t(.credentialStateCredentialExpired)
        case .quotaUnavailable: return L10n.t(.credentialStateQuotaUnavailable)
        case .checkConsumesQuota: return L10n.t(.credentialStateCheckConsumesQuota)
        case .checkFailed: return L10n.t(.credentialStateCheckFailed)
        }
    }

    var color: Color {
        switch self {
        case .usable: return .green
        case .configuredUntested, .checkConsumesQuota, .quotaUnavailable: return .orange
        case .credentialExpired, .checkFailed: return .red
        case .notConfigured: return .gray
        }
    }
}
```

Add on `APIKey`:

```swift
var credentialConfigurationState: CredentialConfigurationState {
    guard isActive else { return .configuredUntested }
    guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .notConfigured }
    if provider.quotaCheckConsumesSearchQuota, lastUpdated == nil { return .checkConsumesQuota }
    if isCredentialExpired { return .credentialExpired }
    if status == .failed { return .checkFailed }
    if isUsableWithUnknownQuota || isUnsupportedQuotaCheckState { return .quotaUnavailable }
    if remaining != nil || lastHTTPStatus == 200 { return .usable }
    if lastUpdated == nil, lastHTTPStatus == nil, lastDiagnosticMessage == nil, quotaText == nil, quotaLabel == nil {
        return .configuredUntested
    }
    return .checkFailed
}
```

Add localized keys in `L10n.Key` and English/Simplified Chinese values first, then mirror concise values in Traditional Chinese, Japanese, and Korean to preserve current app language coverage.

- [ ] **Step 4: Run behavior script**

Run: `./Tests/run_behavior_tests.sh`

Expected: PASS for the new structural assertions.

- [ ] **Step 5: Commit**

```bash
git add QuotaRadar/Models/APIKey.swift QuotaRadar/Models/AppLanguage.swift Tests/run_behavior_tests.sh
git commit -m "feat: model credential diagnostic states"
```

## Task 2: Enrich Diagnostics Rows

**Files:**
- Modify: `QuotaRadar/Models/APIKey.swift`
- Modify: `QuotaRadar/Views/SettingsView.swift`
- Modify: `QuotaRadar/Models/AppLanguage.swift`
- Test: `Tests/run_behavior_tests.sh`

- [ ] **Step 1: Write failing behavior assertions**

```bash
assert_match 'DiagnosticMetadataGrid' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Diagnostics should show compact metadata beyond status and HTTP"
assert_match 'requestProxyModeText' \
  "QuotaRadar/Models/APIKey.swift" \
  "Diagnostics should expose configured proxy mode text"
assert_match 'autoRefreshSkipText' \
  "QuotaRadar/Models/APIKey.swift" \
  "Diagnostics should expose auto-refresh skip state for costly providers"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./Tests/run_behavior_tests.sh`

Expected: FAIL on `DiagnosticMetadataGrid`.

- [ ] **Step 3: Add diagnostic presentation properties**

In `CredentialDiagnosticItem`, add computed values:

```swift
var stateText: String { statusKey.credentialConfigurationState.displayText }
var stateColor: Color { statusKey.credentialConfigurationState.color }

var lastCheckedText: String {
    statusKey.lastUpdated.map(L10n.shortDateTime) ?? L10n.t(.notChecked)
}

var resetDiagnosticText: String {
    let reset = statusKey.visibleQuotaResetSummary
    return reset.isEmpty ? L10n.t(.resetNotExposed) : reset
}

var autoRefreshSkipText: String? {
    guard statusKey.provider.quotaCheckConsumesSearchQuota else { return nil }
    guard statusKey.lastDiagnosticText?.key == .quotaConsumingRefreshWarning
        || statusKey.lastDiagnosticMessage == L10n.t(.quotaConsumingRefreshWarning)
        || statusKey.quotaText?.key == .manualRefreshOnly else {
        return nil
    }
    return L10n.t(.automaticRefreshSkipped)
}

var requestProxyModeText: String {
    AppAppearanceStore.shared.networkProxyMode.displayName
}
```

- [ ] **Step 4: Render metadata compactly**

In `CredentialDiagnosticRow`, replace the second-line-only diagnostic summary with:

```swift
DiagnosticMetadataGrid(item: item)

if let connectionDiagnosticSummary = item.connectionDiagnosticSummary {
    DiagnosticMessageRow(text: connectionDiagnosticSummary)
}
```

Add small reusable views:

```swift
struct DiagnosticMetadataGrid: View {
    let item: CredentialDiagnosticItem

    var body: some View {
        HStack(spacing: 6) {
            DiagnosticPill(title: L10n.t(.credentialState), value: item.stateText, tint: item.stateColor)
            DiagnosticPill(title: L10n.t(.lastUpdated), value: item.lastCheckedText, tint: .secondary)
            DiagnosticPill(title: L10n.t(.requestProxyMode), value: item.requestProxyModeText, tint: .secondary)
            DiagnosticPill(title: L10n.t(.reset), value: item.resetDiagnosticText, tint: .secondary)
            if let skip = item.autoRefreshSkipText {
                DiagnosticPill(title: L10n.t(.automaticRefresh), value: skip, tint: .orange)
            }
        }
    }
}
```

- [ ] **Step 5: Run tests and build**

Run:

```bash
./Tests/run_behavior_tests.sh
swift build
```

Expected: behavior script passes; Swift build succeeds.

- [ ] **Step 6: Commit**

```bash
git add QuotaRadar/Models/APIKey.swift QuotaRadar/Views/SettingsView.swift QuotaRadar/Models/AppLanguage.swift Tests/run_behavior_tests.sh
git commit -m "feat: enrich credential diagnostics"
```

## Task 3: Show State Labels In Credential Configuration

**Files:**
- Modify: `QuotaRadar/Views/SettingsView.swift`
- Test: `Tests/run_behavior_tests.sh`

- [ ] **Step 1: Write failing behavior assertions**

```bash
assert_match 'key\.credentialConfigurationState\.displayText' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential rows should render explicit configuration state labels"
assert_match 'key\.credentialConfigurationState\.color' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Credential state labels should use the state color"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./Tests/run_behavior_tests.sh`

Expected: FAIL on state label assertions.

- [ ] **Step 3: Update credential action/status pill**

In `APIKeyManagementRow.statusText`, prefer:

```swift
private var statusText: String {
    if key.isBusinessInvocationCredential {
        return L10n.t(.useDashboardCookie)
    }
    return key.credentialConfigurationState.displayText
}
```

In `CredentialRowActionGroup`, change state color usage:

```swift
let stateColor = key.credentialConfigurationState.color
```

Use `stateColor` for the pill foreground/background while leaving the leading dot as `key.status.color` if that better preserves existing quota-health semantics.

- [ ] **Step 4: Run tests and build**

Run:

```bash
./Tests/run_behavior_tests.sh
swift build
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add QuotaRadar/Views/SettingsView.swift Tests/run_behavior_tests.sh
git commit -m "feat: show credential configuration states"
```

## Task 4: Add Provider-Level Test Connection

**Files:**
- Modify: `QuotaRadar/Models/APIKey.swift`
- Modify: `QuotaRadar/Models/QuotaMonitor.swift`
- Modify: `QuotaRadar/Views/SettingsView.swift`
- Modify: `QuotaRadar/Models/AppLanguage.swift`
- Test: `Tests/run_behavior_tests.sh`

- [ ] **Step 1: Write failing behavior assertions**

```bash
assert_match 'testConnectionForProvider' \
  "QuotaRadar/Models/QuotaMonitor.swift" \
  "QuotaMonitor should expose provider-level connection testing"
assert_match 'TestConnectionButton' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Provider rows should expose a Test Connection action"
assert_match 'showingCostlyTestConfirmation' \
  "QuotaRadar/Views/SettingsView.swift" \
  "Costly provider tests should require explicit confirmation"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./Tests/run_behavior_tests.sh`

Expected: FAIL on test connection symbols.

- [ ] **Step 3: Add monitor entry point**

In `QuotaMonitor`:

```swift
func testConnectionForProvider(_ provider: Provider) {
    refreshProvider(provider, mode: .manual)
}
```

Keep the first version intentionally thin: it reuses the provider quota check and all existing persistence/error handling. Do not invent another network path unless a provider has a verified no-cost endpoint.

- [ ] **Step 4: Add provider action button**

Extend `ProviderQuotaActionGroup`:

```swift
let onTestConnection: () -> Void
```

Add:

```swift
actionSlot {
    if canRefresh {
        TestConnectionButton(size: size, action: onTestConnection)
    }
}
```

Add the button:

```swift
struct TestConnectionButton: View {
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "network")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: size, height: size)
                .background(.thinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .help(L10n.t(.testConnection))
        .accessibilityLabel(L10n.t(.testConnection))
    }
}
```

- [ ] **Step 5: Add costly confirmation**

In `ProviderQuotaMonitorRow`:

```swift
@State private var showingCostlyTestConfirmation = false

private func testConnection() {
    if provider.quotaCheckConsumesSearchQuota {
        showingCostlyTestConfirmation = true
    } else {
        monitor.testConnectionForProvider(provider)
    }
}
```

Pass `onTestConnection: testConnection` into `ProviderQuotaActionGroup`.

Add `.confirmationDialog` or `.alert` on the row:

```swift
.confirmationDialog(
    L10n.t(.costlyConnectionTestTitle),
    isPresented: $showingCostlyTestConfirmation,
    titleVisibility: .visible
) {
    Button(L10n.t(.testConnectionConsumesQuota), role: .destructive) {
        monitor.testConnectionForProvider(provider)
    }
    Button(L10n.t(.cancel), role: .cancel) {}
} message: {
    Text(L10n.t(.costlyConnectionTestMessage))
}
```

- [ ] **Step 6: Run tests and build**

Run:

```bash
./Tests/run_behavior_tests.sh
swift build
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add QuotaRadar/Models/APIKey.swift QuotaRadar/Models/QuotaMonitor.swift QuotaRadar/Views/SettingsView.swift QuotaRadar/Models/AppLanguage.swift Tests/run_behavior_tests.sh
git commit -m "feat: add provider connection tests"
```

## Task 5: Manual QA And Documentation Cleanup

**Files:**
- Modify: `TODO.md`
- Modify: `TODO.en.md`
- Optional screenshot updates only if the UI visibly changes enough to make README screenshots stale.

- [ ] **Step 1: Build app bundle**

Run:

```bash
./install.sh --bundle-only --rebuild
open 'build/Quota Radar.app'
```

Expected: app launches.

- [ ] **Step 2: Manual QA matrix**

Check these states with local test credentials or redacted fixtures:

- Configured but untested credential shows `Configured, Untested`.
- Healthy checked credential shows `Usable`.
- Dashboard auth failure shows `Credential Expired`.
- Unsupported/unknown quota shows `Quota API Unavailable`.
- Brave or another costly provider opens confirmation before testing.
- Canceling costly confirmation leaves existing quota fields unchanged.
- Diagnostics show state, HTTP, last checked, proxy mode, reset, and diagnostic summary.
- Switching proxy mode in Settings changes diagnostics proxy mode text.

- [ ] **Step 3: Run release behavior checks**

Run:

```bash
./Tests/run_behavior_tests.sh
swift build
```

Expected: PASS.

- [ ] **Step 4: Update roadmap**

In `TODO.md` and `TODO.en.md`, mark completed items:

- Credential state labels.
- Provider-level test connection.
- Rich diagnostics fields.

Leave threshold notifications and provider expansion as open follow-ups.

- [ ] **Step 5: Commit**

```bash
git add TODO.md TODO.en.md
git commit -m "docs: update diagnostics roadmap"
```

## Follow-Up Slice

Do after the diagnostics/test slice is stable:

- Threshold notifications for low quota, exhausted quota, expired cookie, repeated connection failures.
- `planDisplayName` parsing and display for subscription/coding-plan providers.
- Optional no-cost provider-specific ping endpoints only when a provider has a verified endpoint that does not consume quota.
