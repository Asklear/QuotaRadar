# Dual-DMG GitHub Release Workflow Design

## Goal

Publish both macOS distribution variants from the same `v*` tag:

- `build/QuotaRadar.dmg`, the standard build with GitHub update checks;
- `build/QuotaRadar-WhiteLabel.dmg`, the white-label build with the upstream updater compiled out.

This change prepares and pushes the release branch only. It does not merge to `main`, create a tag, or publish a GitHub Release.

## Workflow

Keep the existing single macOS release job. After behavior tests pass, build the standard DMG first and the white-label DMG second. The second build may replace the scratch app bundle, but it writes a distinct DMG path and therefore does not modify the already-created standard artifact.

Before upload, require both files to be non-empty and pass `hdiutil verify`. Confirm that the standard app binary contains the two expected GitHub updater URLs before the white-label build replaces the app bundle. After the white-label build, scan both its app binary and DMG strings and fail if an `Asklear/QuotaRadar` updater URL is present.

Configure the existing `softprops/action-gh-release` step with a multiline `files` value containing both DMGs. Keep one action invocation so both assets are attached to the same tag release.

## Release Notes

Update the workflow body in English and Chinese to say that the release contains both the standard Swift macOS DMG and the WhiteLabel DMG. Briefly distinguish the standard updater-enabled build from the build that omits upstream update endpoints.

## Regression Coverage

Extend `Tests/run_behavior_tests.sh` with source assertions requiring:

- the standard packaging command;
- the white-label packaging command;
- both DMG paths in the release action's upload list;
- artifact verification and white-label updater-URL exclusion in the workflow;
- release wording that no longer says only one Swift macOS DMG is published.

Use a red-green cycle: add the workflow assertions first and verify they fail against the current single-DMG workflow, then make the minimal workflow change and rerun the complete behavior suite.

## Delivery Boundary

After tests pass, commit the workflow and regression coverage, rename the local historical branch from `release/v0.4.4` to `release/v0.4.6`, and push that branch to `origin`. Do not merge, tag, or trigger the tag-based release workflow in this step.
