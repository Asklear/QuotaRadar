# Provider Calibration Backlog

This document tracks provider/package samples that should be calibrated before adding new parser mappings. It complements the provider matrix in [Providers](./providers.md): the provider matrix states what Quota Radar currently trusts, while this backlog states what still needs evidence.

## Observed Before Fixture

Do not add a new parser fixture or localized plan mapping from guesses alone.

- [ ] Capture a redacted response shape or a sanitized live-acceptance row.
- [ ] Identify the exact field names used for quota, balance, reset time, plan end, and plan display name.
- [ ] Confirm whether the check consumes real quota.
- [ ] Confirm whether the value is remaining quota, used quota, money balance, or usage-only metadata.
- [ ] Add a parser fixture only after the field boundary is observed.
- [ ] Keep API credits and subscription quota as separate provider types when they describe different products.

Useful command:

```bash
scripts/live_acceptance.sh --json
```

Live acceptance output is sanitized. It includes provider calibration status, last verified time, calibration evidence, and fallback behavior, but does not print secrets, cookies, tokens, credential labels, or raw provider responses.

## Long-Tail Calibration Queue

| Area | Candidate | Current Status | Evidence Needed | Next Action |
| --- | --- | --- | --- | --- |
| Claude Subscription OAuth usage/limits | Claude Code style OAuth quota endpoint | Pending | Confirm whether OAuth returns five-hour, weekly, reset, plan tier, and subscription-cycle fields more reliably than the web organization endpoint. | Capture a sanitized response shape, then decide whether OAuth becomes the primary source and web organization usage becomes fallback. |
| OpenAI prepaid credits | OpenAI platform billing / credit grant / prepaid balance | Pending | Confirm account/project scope, whether Admin key or web login is required, and whether fields describe API credits rather than Codex subscription windows. | Keep separate from Codex Subscription; add only if a stable balance endpoint is observed. |
| Anthropic Credits | Claude web prepaid credits | Verified | 2026-06-23 15:56 CST replay used an existing saved Claude Subscription web-login authorization and returned HTTP 200 with a parsed credits balance; direct `Anthropic Credits` live acceptance also passed with quota evidence. Values are API/prepaid credits, not Claude Subscription limits. | Keep separate from Claude Subscription; when no direct row exists, refreshing Anthropic Credits derives an independent monitoring row from the saved Claude authorization instead of asking the user to authenticate twice. |
| Cloud coding plans | Additional Aliyun / Tencent / Volcengine / XFYun package names | Watchlist | Observe real package names, internal enum values, expiry fields, and whether usage is remaining or used. | Add localized display mapping and parser fixtures only after a redacted field shape is observed. |
| Codex rare tiers | Less common Codex subscription plan strings | Watchlist | Observe plan identifiers beyond current `Pro 5x` / `Pro 20x` mapping, plus lifecycle source. | Extend `codexPlanDisplayName` only after the raw value is captured. |
| Claude rare tiers | Less common Claude Max / team / enterprise tier strings | Watchlist | Observe raw organization or subscription-detail tier fields and capability flags. | Extend Claude tier normalization only after the raw value is captured. |

## Docs And Browser Observation Log

| Candidate | Observation | Boundary |
| --- | --- | --- |
| OpenAI prepaid credits | Docs reviewed 2026-06-23; OpenAI Platform login missing during browser observation. | OpenAI API docs expose organization usage and cost reporting such as `GET/organization/costs`. No public prepaid credit balance API confirmed. Do not wire OpenAI prepaid credits until an official or logged-in Platform balance endpoint is observed and sanitized. |
| Claude Subscription OAuth usage/limits | Docs reviewed 2026-06-23. | Anthropic Admin API usage/cost reporting is an organization-admin surface that requires `org:admin`; it is separate from personal Claude Subscription quota. No Claude Code OAuth `usage/limits` endpoint has been observed yet, so keep the current `claude.ai` organization usage endpoint as the subscription source. |
| Claude web usage/prepaid credits | Live browser observation 2026-06-23; Anthropic Credits live acceptance passed 2026-06-23 15:56 CST. | Kimi WebBridge live browser observation found `GET https://claude.ai/api/organizations/<org>/usage`, `GET https://claude.ai/api/organizations/<org>/prepaid/credits`, and `GET https://claude.ai/api/organizations/<org>/overage_credit_grant`. The usage response exposes fields such as `five_hour.utilization`, `seven_day.utilization`, `seven_day.resets_at`, and `spend.used`; the prepaid response exposes fields such as `amount`, `auto_reload_settings`, `last_paid_purchase_cents`, and `pending_invoice_amount_cents`. Quota Radar treats prepaid credits as a separate `Anthropic Credits` provider using Claude web-login authorization. A sanitized replay through an existing Claude Subscription credential returned HTTP 200 and parsed the balance; direct Anthropic Credits live acceptance passed with quota evidence. |
| Kimi WebBridge | Connected; live browser observation ran for Claude. | Kimi WebBridge was usable for Claude calibration. It did not verify OpenAI prepaid credits because the browser redirected to OpenAI Platform login. |

## Latest Sanitized Snapshot

Live acceptance snapshot: 2026-06-23 13:06 CST.

| Provider | Result | Sanitized Evidence |
| --- | --- | --- |
| Querit | Passed | Usable quota-unknown state still reflects usage-only account evidence; no limit/reset fields observed. |
| Claude Subscription | Passed | Plan, two quota windows, reset fields, and plan-end metadata observed. |
| Anthropic Credits | Passed | Parser fixture and provider capability are wired from the observed `prepaid/credits` shape. A sanitized replay through saved Claude web-login authorization returned HTTP 200 and parsed a balance; direct Anthropic Credits live acceptance passed with quota evidence and no reset/plan-end/window fields. |
| Codex Subscription | Passed | Plan, two quota windows, reset fields, plan-end metadata, and reset-credit count observed. |
| Kimi Subscription | Passed | Plan-end metadata and usable quota state observed; no reset window exposed by the saved account in this run. |
| XFYun Spark Coding Plan | Passed | Three quota windows, reset fields, plan metadata, and package-end metadata observed. |
| Volcengine Coding Plan | Passed | Three quota windows, reset fields, plan metadata, and package-end metadata observed. |
| OpenCode Go | Passed | Three quota windows and reset fields observed; no package-end metadata observed. |
| Aliyun Coding Plan | Missing saved account | No live field boundary can be updated until a saved account is available. |
| Tencent Cloud Coding Plan | Missing saved account | No live field boundary can be updated until a saved account is available. |

## Evidence Log Template

Use this format when adding a new calibration note:

```text
Provider:
Credential type:
Observed at:
Source endpoint or UI path:
Quota fields:
Reset fields:
Plan fields:
Plan end fields:
Check consumes quota:
Parser fixture added:
Fallback behavior:
Secret handling:
```

## Guardrails

- Never paste raw cookies, bearer tokens, API keys, authorization headers, or account identifiers into docs or fixtures.
- Prefer redacted response shapes with realistic field names and synthetic values.
- If a provider returns only usage without limits, show `usable quota unknown`; do not invent remaining quota.
- If a field disappears from a previously calibrated provider, surface `Needs Recalibration` instead of treating the credential as invalid.
- If a balance increases, classify it as top-up/recovery and do not count it as negative consumption.
