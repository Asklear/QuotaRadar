# Provider Quota Contract Repairs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repair AnySearch, SerpAPI, and LongCat provider contracts while making verified exhausted Key Quota wording consistent across every provider without misclassifying unavailable or unknown quota.

**Architecture:** Add persisted structured quota availability evidence at the parser/model boundary, then let `ProviderStats` use only that evidence for provider-wide exhausted presentation and mixed-pool selection. Keep provider-specific HTTP, numeric, reset, expiry, and diagnostic evidence in credential details. Update AnySearch, SerpAPI, and LongCat parsers and request builders against the live contracts documented in the approved design.

**Tech Stack:** Swift 5.9, SwiftUI, Foundation `URLSession`/`JSONDecoder`/`JSONSerialization`, WebKit dashboard capture, UserDefaults metadata plus file-backed secrets, the shell-driven Swift behavior harness, SwiftPM macOS build, and sanitized live acceptance.

---

## File Map

- `QuotaRadar/Models/APIKey.swift`: persisted `QuotaAvailabilityState`, provider-wide Key Quota presentation, percentage mixed-pool selection, and dashboard URLs.
- `QuotaRadar/Services/QuotaService.swift`: `QuotaResult` evidence, parser audit, AnySearch/SerpAPI request contracts, provider HTTP errors, and LongCat date parsing.
- `QuotaRadar/Services/APIKeyStore.swift`: optional availability-state persistence for backward-compatible metadata decoding.
- `QuotaRadar/Models/QuotaMonitor.swift`: successful-result application and failure-path state clearing/preservation.
- `QuotaRadar/Views/DashboardReauthView.swift`: immediate generic and LongCat dashboard-save result copies, structured availability, and current AnySearch storage-key extraction on the `www` origin.
- `QuotaRadar/Models/AppLanguage.swift`: AnySearch plan-period usage descriptor if the existing daily descriptor cannot represent the returned reset period accurately.
- `QuotaRadar/Services/DashboardReauth.swift`: AnySearch captured-field normalization contract.
- `QuotaRadar/Services/CredentialMetadataExporter.swift`: sanitized availability evidence in exported diagnostics.
- `Tests/run_behavior_tests.sh`: RED/GREEN coverage for all new contracts, persistence, presentation, and regressions.
- `docs/providers.md`, `docs/providers.zh-Hans.md`, `docs/provider-calibration.md`, `docs/provider-calibration.zh-Hans.md`: verified contract documentation.
- `scripts/live_acceptance.sh`, `scripts/live_acceptance_main.swift`: reuse for sanitized live provider checks; modify only if current output cannot prove reset/expiry/availability fields without secrets.

The four repairs share `QuotaResult`, `APIKey`, persistence, and the same behavior harness, so one implementation plan is safer than independent plans that would race on the shared model.

### Task 1: Persist structured provider quota availability

**Files:**
- Modify: `Tests/run_behavior_tests.sh`
- Modify: `QuotaRadar/Models/APIKey.swift`
- Modify: `QuotaRadar/Services/QuotaService.swift`
- Modify: `QuotaRadar/Services/APIKeyStore.swift`
- Modify: `QuotaRadar/Models/QuotaMonitor.swift`
- Modify: `QuotaRadar/Views/DashboardReauthView.swift`
- Modify: `QuotaRadar/Services/CredentialMetadataExporter.swift`

- [ ] **Step 1: Write failing model, persistence, and successful-merge tests**

Add table-driven assertions equivalent to:

```swift
let states: [QuotaAvailabilityState] = [.available, .exhausted, .unavailable, .unknown]
for state in states {
    let key = APIKey(
        name: "STATE_\(state.rawValue)",
        key: "redacted",
        provider: .tavily,
        remaining: state == .available ? 1 : 0,
        limit: 1,
        quotaAvailability: state
    )
    require(key.quotaAvailability == state, "APIKey should retain structured availability")
}

let legacy = APIKey(name: "LEGACY_ZERO", key: "redacted", provider: .tavily, remaining: 0, limit: 1000)
require(legacy.quotaAvailability == nil, "Legacy metadata should decode without invented evidence")

let successful = QuotaResult(
    remaining: 0,
    limit: 1000,
    resetAt: nil,
    quotaAvailability: .exhausted
)
let merged = QuotaMonitor.applyingSuccessfulQuotaResult(successful, to: legacy, now: Date())
require(merged.quotaAvailability == .exhausted, "Successful refresh should apply availability evidence")
```

In the API-key store fixture, save/load all four states and separately decode a pre-change JSON fixture with no availability field. Assert `CredentialMetadataExporter` exports only the enum value, never credentials.

Add focused merge/save-path coverage proving that:

```swift
let reconciled = QuotaMonitor.applyingRefreshMetadata(from: refreshed, to: existing)
require(reconciled.quotaAvailability == refreshed.quotaAvailability, "Refresh reconciliation should retain availability evidence")
```

Source or extracted-helper assertions must also cover both result-copy paths in `DashboardReauthView`: the generic dashboard validation save and the LongCat dashboard validation save must assign `result.quotaAvailability` before persisting the verified key.

- [ ] **Step 2: Run the behavior suite and verify RED**

Run:

```bash
bash Tests/run_behavior_tests.sh
```

Expected: compilation fails because `QuotaAvailabilityState`, `quotaAvailability`, and the new required `QuotaResult` argument do not exist.

- [ ] **Step 3: Add the persisted state model**

In `APIKey.swift`, add:

```swift
enum QuotaAvailabilityState: String, Codable, Equatable {
    case available
    case exhausted
    case unavailable
    case unknown
}
```

Add `var quotaAvailability: QuotaAvailabilityState? = nil` to `APIKey`. Keep it optional so older metadata remains decodable.

In `QuotaService.swift`, add a nonoptional `quotaAvailability` property and required initializer parameter to `QuotaResult`. Do not give it a default: every parser result must state its evidence deliberately.

- [ ] **Step 4: Wire success, persistence, export, and non-success semantics**

Add the optional field to `APIKeyStore.StoredAPIKey`, copy it in both directions, and add it to sanitized metadata export.

In `QuotaMonitor.applyingSuccessfulQuotaResult`, assign:

```swift
updated.quotaAvailability = result.quotaAvailability
```

In `QuotaMonitor.applyingRefreshMetadata`, copy `refreshedKey.quotaAvailability` with the other refreshed quota metadata. In both `DashboardReauthView` result-copy paths—the generic dashboard validator and `validateAndPersistLongCatCredential`—assign `verifiedKey.quotaAvailability = result.quotaAvailability` before saving. These paths bypass `applyingSuccessfulQuotaResult`, so they must be covered explicitly rather than relying on compilation.

On `.notSupported`, `.noSubscription`, unauthorized, invalid-key, and explicit schema-recalibration paths, clear `quotaAvailability` with the other current quota fields. On transient network/server failure, preserve the last successful value exactly as existing quota values are preserved.

- [ ] **Step 5: Compile to enumerate every parser result that still lacks evidence**

Run:

```bash
swift build
```

Expected: FAIL at every remaining `QuotaResult(...)` call until Task 2 audits it. Save the compiler locations as the complete parser audit checklist; do not add a default merely to make the build pass.

- [ ] **Step 6: Commit the model skeleton and RED tests**

```bash
git add QuotaRadar/Models/APIKey.swift QuotaRadar/Services/QuotaService.swift QuotaRadar/Services/APIKeyStore.swift QuotaRadar/Models/QuotaMonitor.swift QuotaRadar/Views/DashboardReauthView.swift QuotaRadar/Services/CredentialMetadataExporter.swift Tests/run_behavior_tests.sh
git commit -m "test: define verified provider quota availability"
```

### Task 2: Audit every provider parser into available, exhausted, unavailable, or unknown

**Files:**
- Modify: `Tests/run_behavior_tests.sh`
- Modify: `QuotaRadar/Services/QuotaService.swift`
- Modify: `QuotaRadar/Models/APIKey.swift`

- [ ] **Step 1: Add failing parser-shape fixtures**

For each response shape, assert both numeric data and `quotaAvailability`:

```swift
require(tavily.remaining > 0 && tavily.quotaAvailability == .available, "Positive request quota is available")
require(tavilyAccount.remaining == 0 && tavilyAccount.quotaAvailability == .exhausted, "Validated zero request quota is exhausted")
require(brave429Exhausted.quotaAvailability == .exhausted, "Verified Brave long-window 429 is exhausted")
require(exhaustedSerper.quotaAvailability == .exhausted, "Zero prepaid credits are exhausted")
require(emptyAnthropicPrepaidCredits.quotaAvailability == .exhausted, "Zero Anthropic credits are exhausted")
require(longCatTokenPack.quotaAvailability == .available, "Positive Token Pack is available")
require(longCatPaygo.remaining > 0 && longCatPaygo.quotaAvailability == .available, "Positive money balance is available")
require(exaUsage.quotaAvailability == .unknown, "Usage without a limit is unknown")
require(queritUsage.quotaAvailability == .unknown, "Usage without a plan limit is unknown")
```

Add the required DeepSeek negative control:

```swift
let unavailableDeepSeek = try! QuotaParsers.parseDeepSeekBalance(Data(#"{"is_available":false,"balance_infos":[]}"#.utf8))
require(unavailableDeepSeek.remaining == 0, "Unavailable DeepSeek keeps its current numeric compatibility")
require(unavailableDeepSeek.quotaAvailability == .unavailable, "Unavailable DeepSeek must not become exhausted")
```

Add positive/zero fixtures for request/count, percentage window, token, credit, and money helpers. Add source guards or direct tests for every visible quota-monitoring provider family listed in the design matrix so no `QuotaResult` is left unaudited.

- [ ] **Step 2: Run tests and verify RED**

Run:

```bash
bash Tests/run_behavior_tests.sh
```

Expected: FAIL because parsers have not yet supplied structured evidence.

- [ ] **Step 3: Implement small validated-result helpers**

Inside `QuotaParsers`, add narrowly named helpers only after the provider parser has validated its contract:

```swift
private static func availability(forValidatedRemaining remaining: Int) -> QuotaAvailabilityState {
    remaining > 0 ? .available : .exhausted
}

private static func availability(forValidatedPercent percent: Double) -> QuotaAvailabilityState {
    percent > 0 ? .available : .exhausted
}
```

Do not call these helpers for sentinel values, missing limits, service-unavailable responses, or usage-only responses.

- [ ] **Step 4: Complete the parser audit forced by Task 1**

Assign evidence by contract:

- validated request/token/count and credit results: positive `.available`, zero `.exhausted`;
- validated monetary balances: positive `.available`, zero `.exhausted`;
- percentage/coding/subscription projections: positive tightest effective percentage `.available`, zero `.exhausted`;
- Exa/Querit/Brave-without-monthly-quota: `.unknown`;
- DeepSeek `is_available == false`: `.unavailable`;
- Brave HTTP 402 and verified long-window 429: `.exhausted`;
- unlimited or local-policy results: `.available` only when the provider contract genuinely proves usability, otherwise `.unknown`;
- explicit missing subscription continues to throw `noSubscription` and never creates exhaustion evidence.

For combined LongCat, use Token Pack evidence when a pack exists; otherwise use Pay-as-you-go evidence.

- [ ] **Step 5: Run the full behavior suite and build**

Run:

```bash
bash Tests/run_behavior_tests.sh
swift build
```

Expected: all parser-shape assertions pass and no `QuotaResult` initializer remains without explicit evidence.

- [ ] **Step 6: Commit**

```bash
git add QuotaRadar/Services/QuotaService.swift QuotaRadar/Models/APIKey.swift Tests/run_behavior_tests.sh
git commit -m "feat: classify quota availability for every provider"
```

### Task 3: Unify provider-wide Key Quota exhaustion without losing mixed-pool data

**Files:**
- Modify: `Tests/run_behavior_tests.sh`
- Modify: `QuotaRadar/Models/APIKey.swift`

- [ ] **Step 1: Add failing provider-wide presentation tests**

Create representative `ProviderStats` fixtures for request, token, percentage-window, credit, and monetary providers. Every verified exhausted fixture must satisfy:

```swift
require(stats.keyQuotaDisplayText == L10n.t(.usageLimitExceeded), "Verified exhaustion should use shared Key Quota copy")
```

Also assert:

- Tavily, Brave 402, Brave verified 429, SerpAPI, LongCat, a coding/subscription percentage provider, Anthropic Credits/Serper, DeepSeek/Bocha/WeChat zero balance all share the same Key Quota copy;
- `APIKey.quotaDisplayText`, `lastHTTPStatus`, `lastDiagnosticText`, currency/credit units, numeric detail, and reset/expiry remain unchanged;
- unavailable DeepSeek, Exa/Querit unknown quota, no-subscription, unlimited, failed, expired, copy-only, business-only, and legacy zero-with-nil-state do not show exhaustion;
- a pool with `.available` and `.exhausted` credentials shows the usable credential;
- a percentage provider with one 0% exhausted credential and one positive available credential derives its window from the available credential only.

- [ ] **Step 2: Run tests and verify RED**

Run:

```bash
bash Tests/run_behavior_tests.sh
```

Expected: FAIL because Key Quota still uses provider-specific paths and percentage windows include exhausted siblings.

- [ ] **Step 3: Implement one shared evidence predicate**

In `ProviderStats`, add focused helpers:

```swift
private var activeAvailableMonitoringKeys: [APIKey] {
    activeCredentialKeys.filter { $0.quotaAvailability == .available }
}

private var hasVerifiedExhaustedQuota: Bool {
    !activeAvailableMonitoringKeys.isEmpty == false
        && activeCredentialKeys.contains { $0.quotaAvailability == .exhausted }
}
```

Implement the boolean without clever negation in production code if a clearer expression reads better. At the start of `keyQuotaDisplayText`, after the no-key and unlimited guards but before money/credit/percentage special cases, return `L10n.t(.usageLimitExceeded)` when `hasVerifiedExhaustedQuota` is true.

- [ ] **Step 4: Filter mixed pools consistently**

When any `.available` key exists, use only available keys for:

- `tightestActiveUsableMonitoringKey`;
- percentage quota-window aggregation used by `keyQuotaDisplayText`;
- provider percentage fallback in the Key Quota column.

Do not globally remove exhausted keys from attention counts, status colors, credential diagnostics, or detail rows.

- [ ] **Step 5: Run behavior tests and verify GREEN**

Run:

```bash
bash Tests/run_behavior_tests.sh
```

Expected: all provider-shape, false-positive, diagnostic-preservation, and mixed-pool assertions pass.

- [ ] **Step 6: Commit**

```bash
git add QuotaRadar/Models/APIKey.swift Tests/run_behavior_tests.sh
git commit -m "fix: unify exhausted Key Quota across providers"
```

### Task 4: Replace the stale AnySearch origin and usage contract

**Files:**
- Modify: `Tests/run_behavior_tests.sh`
- Modify: `QuotaRadar/Models/APIKey.swift`
- Modify: `QuotaRadar/Services/DashboardReauth.swift`
- Modify: `QuotaRadar/Views/DashboardReauthView.swift`
- Modify: `QuotaRadar/Services/QuotaService.swift`
- Modify: `QuotaRadar/Models/AppLanguage.swift` only if a period-aware usage descriptor is required

- [ ] **Step 1: Add failing origin, capture, URL, and parser tests**

Assert:

```swift
require(Provider.anysearch.dashboardURL == "https://www.anysearch.com/console/overview", "AnySearch should open the www console origin")
require(Provider.anysearch.cookieDomains.contains("anysearch.com"), "Capture should accept apex and subdomains")
require(AnySearchBillingOverviewRequest.url.absoluteString == "https://www.anysearch.com/api/api/user/billing/overview", "Overview URL must match the current frontend helper contract")
require(AnySearchRefreshRequest.url.absoluteString == "https://www.anysearch.com/api/ssuser/auth/refresh", "Refresh URL must use the www origin")
```

Keep source assertions proving Web Storage reads only `search-template-auth-state` and extracts only `state.accessToken`, `state.refreshToken`, and `state.expiresAt` for apex or subdomain hosts.

Add current response fixtures:

```swift
let overview = try! QuotaParsers.parseAnySearchBillingOverview(Data(#"{"tier_code":"free","tier_name":"Free Plan","remaining":638,"used":362,"total":1000,"rate_limit_unlimited":false,"reset_period":"daily","next_reset_at":null}"#.utf8))
require(overview.remaining == 638 && overview.limit == 1000, "AnySearch should use official remaining and total")
require(overview.planDisplayName == "Free Plan", "AnySearch should preserve tier name")
require(overview.resetAt == nil, "Daily without next_reset_at must not invent UTC reset")
require(overview.quotaAvailability == .available, "Positive AnySearch quota is available")
```

Add fixtures for daily/monthly/none, valid ISO reset, absent/invalid reset, exact exhaustion, valid overage (`used > total`, `remaining == 0`), negative values, `total == 0`, unsupported reset period, inconsistent sums, and the retired usage-summary schema.

- [ ] **Step 2: Add failing HTTP-status tests**

Test refresh 400/401/403 and overview 401/403/404. Test HTTP 200 with an invalid schema. Assert the eventual error exposes the exact status so `QuotaMonitor` persists 400/401/403/404/200 rather than `nil`.

- [ ] **Step 3: Run tests and verify RED**

Run:

```bash
bash Tests/run_behavior_tests.sh
```

Expected: FAIL on the `www` URLs, new response parser, and status-bearing error semantics.

- [ ] **Step 4: Implement status-bearing provider errors**

Extend `QuotaError` with narrowly scoped associated-status cases, for example:

```swift
case unauthorizedStatus(Int)
case schemaDriftStatus(Int)
```

Map them to the existing credential-invalid and schema-drift localized descriptors and return the associated value from `httpStatus`. Update `QuotaMonitor` to route `.unauthorizedStatus` through the same credential-expired behavior as `.unauthorized`; schema-drift status retains schema-recalibration diagnostics. Do not change unrelated provider status mappings.

- [ ] **Step 5: Implement current AnySearch requests and schema**

Replace the legacy bounded-summary request with fixed `www` request builders. Parse the direct overview object with these invariants:

```text
total > 0
used >= 0
0 <= remaining <= total
used <= total  => used + remaining == total
used > total   => remaining == 0
reset_period in {daily, monthly, none}
```

Parse valid ISO `next_reset_at`; otherwise keep reset unknown. Never infer a timezone boundary. Set plan name and availability evidence. Preserve rotated credentials when the following quota call fails.

If the existing `dailyRequestsUsageFormat` would mislabel monthly/none plans, add one period-aware localized descriptor in all five language tables rather than persisting English-only copy.

- [ ] **Step 6: Run behavior tests and build**

Run:

```bash
bash Tests/run_behavior_tests.sh
swift build
```

Expected: AnySearch contract, status, capture, parser, localization, and provider-isolation tests pass.

- [ ] **Step 7: Commit**

```bash
git add QuotaRadar/Models/APIKey.swift QuotaRadar/Services/DashboardReauth.swift QuotaRadar/Views/DashboardReauthView.swift QuotaRadar/Services/QuotaService.swift QuotaRadar/Models/AppLanguage.swift QuotaRadar/Models/QuotaMonitor.swift Tests/run_behavior_tests.sh
git commit -m "fix: update AnySearch dashboard quota contract"
```

### Task 5: Use SerpAPI's official renewal and account metadata

**Files:**
- Modify: `Tests/run_behavior_tests.sh`
- Modify: `QuotaRadar/Services/QuotaService.swift`
- Modify: `docs/providers.md`
- Modify: `docs/providers.zh-Hans.md`

- [ ] **Step 1: Add failing account parser and URL tests**

Use the observed exhausted fixture:

```swift
let serp = try! QuotaParsers.parseSerpApiAccount(Data(#"{"plan_name":"Free Plan","searches_per_month":250,"this_month_usage":250,"plan_searches_left":0,"extra_credits":0,"total_searches_left":0,"plan_renewal_date":"2026-08-10","status":"Your account has run out of searches."}"#.utf8))
require(serp.remaining == 0 && serp.limit == 250, "SerpAPI should preserve 250 / 250 exhaustion")
require(serp.planDisplayName == "Free Plan", "SerpAPI should preserve plan name")
require(serp.quotaAvailability == .exhausted, "SerpAPI zero is verified exhaustion")
require(serp.resetAt?.timeIntervalSince1970 == 1786320000, "Renewal must be 2026-08-10 00:00:00 UTC")
require(serp.diagnosticMessage == "Your account has run out of searches.", "Status remains diagnostic evidence")
```

Add missing/invalid renewal fixtures that return `resetAt == nil`, extra-credit fixtures, remaining-field precedence, and a request URL test using a key such as `key+with&reserved=value` to prove `URLQueryItem` encoding.

- [ ] **Step 2: Run tests and verify RED**

Run:

```bash
bash Tests/run_behavior_tests.sh
```

Expected: FAIL because the parser still invents next-month reset and request construction interpolates the key.

- [ ] **Step 3: Implement parser and request builder**

Decode optional `plan_renewal_date`, `plan_name`, and `status`. Parse the day with a POSIX Gregorian UTC `DateFormatter("yyyy-MM-dd")`. Remove `nextMonthStartUTC()` from SerpAPI. Keep total/plan/derived remaining precedence and extra-credit total.

Construct `https://serpapi.com/account.json` with `URLComponents` and `URLQueryItem(name: "api_key", value: key.key)`.

- [ ] **Step 4: Run tests and commit**

```bash
bash Tests/run_behavior_tests.sh
git add QuotaRadar/Services/QuotaService.swift Tests/run_behavior_tests.sh docs/providers.md docs/providers.zh-Hans.md
git commit -m "fix: use SerpAPI official renewal date"
```

Expected: parser, encoding, official-renewal, availability, and existing SerpAPI tests pass.

### Task 6: Parse LongCat Token Pack expiry in the provider timezone

**Files:**
- Modify: `Tests/run_behavior_tests.sh`
- Modify: `QuotaRadar/Services/QuotaService.swift`
- Modify: `docs/providers.md`
- Modify: `docs/providers.zh-Hans.md`

- [ ] **Step 1: Add failing live-format and malformed-format tests**

Use the observed value:

```swift
let liveLongCat = try! QuotaParsers.parseLongCatTokenPackSummary(Data(#"{"code":0,"data":{"currentLot":{"remainingToken":14494119,"totalToken":50000000,"consumedToken":35505881,"expireTime":"2026-08-08 12:07:16","remainSeconds":586503,"grantCategory":"PURCHASE"},"estimate":{"exhaustedAfterDays":12},"otherLots":[]}}"#.utf8))
var shanghai = Calendar(identifier: .gregorian)
shanghai.timeZone = TimeZone(identifier: "Asia/Shanghai")!
let parts = shanghai.dateComponents([.year, .month, .day, .hour, .minute, .second], from: liveLongCat.planEndsAt!)
require(parts.year == 2026 && parts.month == 8 && parts.day == 8 && parts.hour == 12 && parts.minute == 7 && parts.second == 16, "LongCat local expiry should use Asia/Shanghai")
```

Add fixtures for numeric, ISO, absent, empty, and present malformed expiry. Absent/empty stays clean unknown expiry; malformed preserves quota and sets schema-drift diagnostic text with HTTP success. Assert combined LongCat carries Token Pack expiry and Pay-as-you-go alone remains non-expiring.

- [ ] **Step 2: Run tests and verify RED**

Run:

```bash
bash Tests/run_behavior_tests.sh
```

Expected: FAIL because the timezone-less live value does not parse.

- [ ] **Step 3: Implement a LongCat-only local date parser**

Add:

```swift
private static func parseLongCatLocalDateTime(_ value: String) -> Date? {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter.date(from: value)
}
```

For LongCat expiry only, try numeric/ISO existing forms first, then this parser. Track whether a nonempty expiry field was present; if parsing fails, return the valid quota with `diagnosticText = .localized(.quotaErrorSchemaDrift)` and matching diagnostic message. Do not broaden the generic date parser.

- [ ] **Step 4: Run tests and commit**

```bash
bash Tests/run_behavior_tests.sh
git add QuotaRadar/Services/QuotaService.swift Tests/run_behavior_tests.sh docs/providers.md docs/providers.zh-Hans.md
git commit -m "fix: parse LongCat Token Pack expiry"
```

Expected: all LongCat expiry, availability, combined-result, and Pay-as-you-go isolation tests pass.

### Task 7: Synchronize provider documentation and run final QA

**Files:**
- Modify: `docs/providers.md`
- Modify: `docs/providers.zh-Hans.md`
- Modify: `docs/provider-calibration.md`
- Modify: `docs/provider-calibration.zh-Hans.md`
- Verify: `Tests/run_behavior_tests.sh`
- Verify: `scripts/live_acceptance.sh`
- Verify: `QuotaRadar/Info.plist`

- [ ] **Step 1: Update verified provider contracts**

Document:

- AnySearch `www` auth origin, storage key, refresh endpoint, current billing-overview endpoint, official used/remaining/total fields, and no invented reset when `next_reset_at` is absent;
- SerpAPI `plan_renewal_date`, plan name/status evidence, and removal of first-of-month fallback;
- provider-wide structured availability and shared Key Quota wording;
- LongCat `expireTime` China-local format and Token Pack versus Pay-as-you-go expiry separation.

Do not change version numbers, release notes, tag workflow, or `/Applications` in this task.

- [ ] **Step 2: Run static safety and full behavior verification**

Run:

```bash
git diff --check
bash Tests/run_behavior_tests.sh
swift build
```

Expected: exit 0, `All behavior tests passed`, and a successful SwiftPM build.

- [ ] **Step 3: Run sanitized live acceptance for saved providers**

Run one provider at a time, never printing credentials or raw bodies:

```bash
QUOTARADAR_LIVE_ACCEPTANCE=1 scripts/live_acceptance.sh --live --json --provider AnySearch
QUOTARADAR_LIVE_ACCEPTANCE=1 scripts/live_acceptance.sh --live --json --provider SerpAPI
QUOTARADAR_LIVE_ACCEPTANCE=1 scripts/live_acceptance.sh --live --json --provider LongCat
QUOTARADAR_LIVE_ACCEPTANCE=1 scripts/live_acceptance.sh --live --json --provider "Codex Subscription"
```

Expected:

- AnySearch: HTTP 200, current plan, used, remaining, total, and fresh update time; if the saved apex-origin token is stale, recapture from the already logged-in `www` console and rerun;
- SerpAPI: HTTP 200, `0 / 250`, Free Plan, and 2026-08-10 renewal;
- LongCat: HTTP 200, `14,494,119 / 50,000,000` subject to live drift, and expiry 2026-08-08 12:07:16 +08:00;
- Codex non-regression: HTTP 200, Pro 20x/week evidence remains readable, and an omitted fully recovered five-hour window is not exhaustion.

- [ ] **Step 4: Independently read back persisted local metadata**

Use a redacted `defaults export ... | plutil ... | jq` projection that prints only provider, remaining, limit, reset/expiry, plan, HTTP status, availability state, and last update. Confirm no token/cookie/key appears.

- [ ] **Step 5: Review the final diff and worktree**

Run:

```bash
git status --short --branch
git diff origin/main...HEAD --check
git diff --stat origin/main...HEAD
git log --oneline --decorate origin/main..HEAD
```

Expected: only the approved spec, plan, implementation, tests, and provider docs are present. The worktree is clean after final commits.

- [ ] **Step 6: Commit final docs/QA adjustments**

```bash
git add docs/providers.md docs/providers.zh-Hans.md docs/provider-calibration.md docs/provider-calibration.zh-Hans.md Tests/run_behavior_tests.sh scripts/live_acceptance.sh scripts/live_acceptance_main.swift
git commit -m "docs: record repaired provider quota contracts"
```

Only add live-acceptance files if they actually changed. Do not push, merge, tag, publish a release, or replace `/Applications` without a separate user request.
