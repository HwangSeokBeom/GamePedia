# Tasks

## Current execution state

- [x] Adopt evidence-based operating documentation in the writable GamePedia repository.
- [ ] Populate the seven GamePediaCoreServer operating files — evidence is gathered, but the managed filesystem rejected writes outside the GamePedia writable root.
- [x] Capture product/iOS/backend/cross-platform baseline.
- [x] Draft Android native direction, modernization options, roadmap, and risk register.
- [x] Reconcile the committed DeviceDev conflict regions without changing PBX objects, signing, entitlements, bundle IDs, or deployment targets.
- [x] Remove authenticated API request/response body previews, full/partial credential values, and the reviewed raw translation/profile/Steam/search inputs from iOS logs.
- [x] Fast-forward the isolated `dev` work copy to `main` without rewriting history and preserve the owner repository working tree.
- [x] Align iOS recent-play and privacy endpoints with the current cross-platform canonical routes; retain server aliases as backend compatibility only.
- [x] Align representative privacy, recent-play, Steam status/import, push-token, envelope, and date-decoding DTO behavior with `cross-platform.openapi.json`.
- [x] Add replaying single-flight refresh rotation and generation-guarded commit so concurrent callers share one backend CAS request and late refresh output cannot restore a logged-out/deleted session.
- [x] Align app and widget 2.0 marketing/build versions across Debug, DeviceDev, Staging, and Release without changing signing, entitlements, deployment targets, or bundle IDs.
- [x] Confirm `GamePedia_AOS` is only an empty placeholder—not a Git/Gradle Android repository—and record the committed-but-incomplete OpenAPI gate evidence.
- [x] Select Trustworthy Search as the proposed next cross-platform slice, implement/document the current iOS sub-slice, and mark the full release `PARTIAL`.
- [x] Implement latest-query-wins, explicit search failure/retry, clear cancellation, local genre request deduplication, privacy-safe diagnostics, and localized failure copy on iOS.
- [x] Add focused ordinary-search ViewModel tests; execution remains pending because XCTest is unavailable in this environment.
- [ ] Run authenticated Claude Lead Architect review — the 2026-07-13 restricted CLI process could not access workspace trust/authentication; no new login was attempted because host authentication is separately verified.
- [ ] Run authenticated Claude Architecture Challenger review — same restricted-process limitation; independent Codex Challenger evidence is reported separately and is not represented as Claude.
- [ ] Run Antigravity/Gemini review — the CLI could not bind its required localhost language-server socket in the managed sandbox, before model execution.
- [ ] Obtain product-owner decisions for proposed decisions in `DECISIONS.md`.

## Next executable work

- [ ] Establish an owner-approved Core Server `dev` branch/worktree path that preserves the dirty `main` worktree before any backend edit.
- [ ] Make the canonical backend test runner tracked and prove `npm ci && npm test` from a clean checkout/worktree.
- [ ] Inventory all 17 OpenAPI operations against backend `HEAD`, dirty route/controller/service behavior, aliases, and tests; then promote only the accepted contract-bearing changes from a safe `dev` workflow.
- [ ] Run `xcodebuild -resolvePackageDependencies`, the GamePedia-Dev simulator build, and XCTest from a normal Xcode environment with GitHub/package cache access; resolve any actual compile or test finding before committing.
- [ ] Run authenticated staging smoke checks for recent play, privacy, Steam status/import, friend recommendations, push registration/deletion, and concurrent refresh rotation.
- [ ] Inspect distribution/device logs for credential, search, profile, Steam, and provider-data leakage after the static logging changes.
- [ ] Define analytics-backed parity acceptance criteria and supported product flows.
- [ ] Define shared design/accessibility/localization rules before Android UI implementation.
- [ ] Establish backend integration environment, migration/backup/restore evidence, and service-level objectives.
- [ ] Create the Android project only after Phase 0/1 exit criteria are accepted.
- [ ] Expand OpenAPI and actual HTTP fixtures for public standard Search before the first Android feature slice; add authenticated AI Search only with the auth foundation.
- [ ] Complete the full iOS/backend logging-sink inventory and hashed structured-logger migration with sentinel and distribution/staging verification.
- [ ] Run the new `SearchViewModelTests` in Xcode and manually verify slow/out-of-order/failure/retry/clear/genre/AI-assist coexistence, four locales, Dynamic Type, and VoiceOver.
- [ ] Replace iOS local-only discussion/moderation production repositories with canonical server-backed implementations after route/authorization/pagination/tombstone/idempotency freeze.
- [ ] Account-scope or atomically clear Library, activity, discussion/moderation, notification, and widget state on logout/delete/account switch.

## Blockers

- The Core Server is on dirty `main`, while this request requires `dev`; 23 tracked files and many user-owned untracked/duplicate files prohibit an automatic branch switch, cleanup, or implementation in place.
- The tracked Core Server `npm test` script references an untracked canonical-test runner, so clean-checkout test reproducibility is currently broken.
- The managed environment blocks SwiftPM's nested `sandbox-exec` and CoreSimulatorService. Project syntax and structure parse, but `xcodebuild -list`, build settings, compile, and tests require a normal macOS Terminal/Xcode run.
- The Core Server OpenAPI is present, but contract-bearing canonical, compatibility-alias, and push-semantic changes remain uncommitted in its working tree. A 17-operation HEAD-versus-working-tree inventory is required before promotion.
- The managed environment cannot resolve GitHub or update the incomplete Firebase SwiftPM cache, and CoreSimulatorService is unavailable. Full type checking, build, XCTest, UI, runtime, and device checks require a normal Xcode session.
- Claude and Antigravity/Gemini external reviews could not execute inside the restricted process; these failures are not evidence that host authentication is invalid.
- Product personas, analytics, business KPIs, support policy, data retention, SLOs, backup/restore outcomes, and production runtime state are not present in repository evidence.
- Backend has numerous user-owned untracked duplicate files; their intended disposition is unknown and outside this task.

## Remaining risks

See `RISK_REGISTER.md`; highest priorities are contract drift, credential/runtime-only integrations, migration/backup readiness, sensitive debug logging, and release scope coupling.
