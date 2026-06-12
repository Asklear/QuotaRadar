# Desktop Tauri Parity Checklist

This checklist is the gate for deciding whether the Tauri desktop app is close enough to the current Swift macOS app to ship as a preview. It is intentionally stricter than a build checklist: the app must preserve the quota-first user experience, credential safety model, and provider semantics.

## Current status

- Track: Tauri cross-platform preview under `apps/desktop-tauri`
- Stable release track: Swift macOS app
- Local platform checked: macOS arm64
- Windows/Linux screenshot QA: pending real runner or device screenshots
- Visual QA on 2026-06-12: local main-window and tray-popover screenshots showed no obvious top clipping, sidebar overlap, or action-button displacement. A later real macOS bundle check confirmed the Swift-shared app mark, provider icon assets, and fixed-size menu bar popover, while also exposing a main-window initial-placement issue on multi-display setups.
- Stability hardening on 2026-06-13: the Tauri preview repairs off-screen main-window frames, prefers the current interaction display when no valid user frame exists, excludes generated Rust/Playwright artifacts from Vite watch, and provides local macOS ad-hoc signing plus `/tmp/quotaradar-tauri-qa...` screenshot QA commands.
- Latest local verification commands:
  - `pnpm test -- --run`
  - `pnpm typecheck`
  - `cargo test --manifest-path apps/desktop-tauri/src-tauri/Cargo.toml`
  - `pnpm tauri build --bundles app`
  - `pnpm sign:mac`
  - `scripts/qa_tauri_macos_screenshots.sh`
  - `bash scripts/check_tauri_sources.sh`

## Feature parity

| Area | Required behavior | Status | Notes |
| --- | --- | --- | --- |
| Tray popover | Risk-first menu bar surface with quota risk summary and attention list | Partial | Mock route and real macOS bundle QA cover fixed popover size and top clipping. Needs native tray positioning QA on Windows/Linux and more dark/transparent menu-bar checks. |
| Main quota monitoring | Provider-first quota table with configured providers only | Partial | Mock UI and selectors cover configured-provider filtering and provider summaries. Swift-shared app/provider icons are now in place. Main-window placement now repairs off-screen saved frames; still needs repeated real multi-display QA before broader preview. |
| Credentials | Provider-aware credential management, copy only for copyable API keys | Partial | Unit/integration tests cover credential creation, copyability, web authorization shell, and stored companion API keys. |
| Diagnostics | Shows configured providers only, concise health/HTTP state, no duplicated quota rows | Partial | Mock diagnostics exist; needs real Tauri state verification with stored credentials. |
| Settings | Language, launch at login, update checks, refresh intervals, costly refresh, proxy, transparency, provider order | Partial | Unit/integration tests cover settings contracts and provider ordering. Needs native autostart and proxy QA per OS. |
| i18n | Simplified Chinese, Traditional Chinese, English, Japanese, Korean with no missing keys | Pass in source checks | `scripts/check_tauri_sources.sh` validates locale key parity and empty values. |
| Provider order | Custom order applies to all main pages and tray popover | Partial | Selector/unit coverage exists; drag-and-drop behavior needs visual QA. |
| Secret safety | No real secrets in source/tests/docs/screenshots; web login authorization is not copyable | Pass in source checks | Safety script scans source/docs and asserts dashboard authorization is not copyable. |
| Costly refresh | Brave and other costly checks are skipped by normal automatic refresh | Pass in backend tests | Scheduler and provider tests cover costly refresh policy. |
| Update/install | No silent update until signed artifacts and manifests exist | Pass in backend/config checks | Commands return informational pending state; release doc records unsigned boundary. |
| Platform caveats | macOS, Windows, Linux package/update differences documented | Partial | Release doc covers target package names, unsigned preview boundaries, local macOS ad-hoc signing, and signing gaps. Needs CI artifact policy later. |

## Screenshot QA matrix

Playwright screenshots are generated under `apps/desktop-tauri/tests/e2e/screenshots/` and must remain ignored unless explicitly chosen as masked documentation assets. Real macOS bundle screenshots must be generated outside the repository with `scripts/qa_tauri_macos_screenshots.sh`; the default output path is `/tmp/quotaradar-tauri-qa-YYYYMMDD-HHMMSS`.

| Platform | Scenario | Command or route | Status | Notes |
| --- | --- | --- | --- | --- |
| macOS arm64 | Default language main window | `pnpm test:e2e -- main-window.spec.ts` | Pass locally | Captures `main-window.png`; verifies sidebar/content separation. |
| macOS arm64 | Tray popover route | `pnpm test:e2e -- tray-popover.spec.ts` | Pass locally | Captures `tray-popover.png`; verifies `560 x 500` surface. |
| macOS arm64 | Real bundle main window and menu bar popover | `scripts/qa_tauri_macos_screenshots.sh` | Required before preview handoff | Writes `main-window-screen.png`, `menu-bar-popover-screen.png`, and `window-state.txt` under `/tmp/quotaradar-tauri-qa...`; do not commit these files. |
| macOS arm64 | External display placement | `scripts/qa_tauri_macos_screenshots.sh` with an external display attached | Required when hardware is available | Confirm the main window stays on the current interaction display unless the user has saved a visible frame on another display. |
| macOS arm64 | Dark mode and transparent menu bar contrast | Manual pass plus `scripts/qa_tauri_macos_screenshots.sh` | Pending if current desktop is not representative | The script records a checklist item because it does not automatically toggle system appearance. |
| macOS arm64 | Narrow minimum window | `main-window.spec.ts` layout assertion | Partial | Tests sidebar/content separation; add explicit minimum viewport regression if defects appear. |
| macOS arm64 | Simplified Chinese | Not automated yet | Pending | Needs route or mock setting hook for language-specific screenshot. |
| macOS arm64 | Fixture-heavy configured account | Current mock credentials | Partial | Mock data includes AI Search and LLM providers, low quota, expired login, CNY balances, subscription windows. |
| Windows | Default language main window | CI/manual Playwright | Pending | Requires Windows runner screenshots. |
| Windows | Tray popover route | CI/manual Playwright | Pending | Verify window chrome, fonts, and scaling. |
| Linux | Default language main window | CI/manual Playwright | Pending | Requires WebKit/GTK rendering check. |
| Linux | Tray popover route | CI/manual Playwright | Pending | Verify panel size and font metrics. |

## Defect rules

- Fix only parity defects in this phase.
- Do not add new providers while working this checklist.
- Do not change provider semantics without updating `docs/provider-capabilities.md` and `docs/provider-capabilities.en.md`.
- Do not commit generated screenshots, traces, `dist`, `target`, `node_modules`, or real credential material.

## Exit criteria

- Local macOS e2e screenshots pass and are visually checked.
- GitHub Actions preview passes on macOS, Windows, and Linux.
- Windows and Linux screenshots are reviewed for layout regressions.
- All source safety checks pass.
- Any intentional UI divergence is recorded in `docs/desktop-tauri-ui-spec.md`.
