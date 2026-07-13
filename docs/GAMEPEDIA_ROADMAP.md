# GamePedia Cross-Platform Roadmap

## Operating model

Each phase uses the Tier 3 sequence for meaningful changes: Claude Lead Architect (read-only plan, when authenticated and explicitly scoped), Codex Explorer/Builder, independent Claude Architecture Challenger, and separate Codex Final Verifier. If Claude is unavailable, record the gap, use a clearly labeled independent fallback review, and do not report `VERIFIED` on the strength of that fallback alone.

Do not start a phase because the previous phase produced documents; start only when its exit evidence is accepted. iOS, Android, and backend releases remain independently deployable.

## Phase 0 — Repository adoption and baseline

- **Objective:** establish evidence boundaries, ownership rules, current behavior/architecture/operations, and unresolved facts.
- **Repositories:** iOS and Core Server; `GamePedia_AOS` is an empty placeholder and the future Android repo is not created.
- **Claude role:** lead architecture evidence challenge; **Codex role:** explore repositories, author docs, preserve worktree, execute static verification.
- **Deliverables:** operating docs, baseline, contract baseline, Android proposal, options, roadmap, risk register.
- **Entry:** owner-authorized planning scope and repository access.
- **Exit:** all requested docs exist; claims trace to files; unknowns marked; independent reviews complete or gaps explicit; no production code changed.
- **Verification:** links/path checks, route inventory comparison, Markdown checks, git diff/status, reviewer findings.
- **Blockers/dependencies:** unauthenticated Claude; untracked duplicate backend files; missing stakeholder/production evidence.

## Phase 1 — Product and API contract freeze

- **Objective:** distinguish product requirements from iOS implementation and freeze Android parity behavior/API compatibility.
- **Repositories:** iOS and Core Server; Android planning artifacts only.
- **Claude role:** propose boundaries/versioning and migration alternatives; **Codex role:** build route/DTO/fixture inventory and contract tests.
- **Deliverables:** accepted parity matrix, canonical endpoint list, machine-readable schema, auth/pagination/error/date/media/push/deep-link rules, deprecation plan.
- **Entry:** Phase 0 accepted; product/API owners named; staging test access available; R-28 Xcode project conflicts are reconciled far enough to parse the project and run client decoding tests.
- **Exit:** every iOS endpoint classified; all drift decisions accepted; fixtures validate server and iOS; compatibility window and explicit Android deferrals approved.
- **Verification:** route registration tests, schema validation, iOS decode tests, authenticated staging smoke tests.
- **Blockers/dependencies:** remaining R-28 build/runtime execution gap, unclear business behavior, read-only backend in the current task, missing credentials/test accounts, account/privacy retention decisions.

## Phase 2 — Shared design system and UX rules

- **Objective:** define cross-platform tokens, components, states, content rules, accessibility, localization, and adaptive behavior without forcing identical UI.
- **Repositories:** design documentation plus iOS; Android repo only after Phase 1 and creation authorization.
- **Claude role:** challenge system scope and product-vs-platform boundaries; **Codex role:** inventory iOS components/states and implement approved token artifacts/tests.
- **Deliverables:** color/type/spacing/icon tokens, component/state catalog, empty/loading/error/auth rules, four-locale content conventions, accessibility acceptance checklist.
- **Entry:** parity flows frozen; brand assets/ownership available.
- **Exit:** representative Home/Detail/Review/Auth designs cover compact/large text/dark mode/error/empty states and are accepted for both platforms.
- **Verification:** token validation, contrast/touch-target review, VoiceOver/TalkBack prototypes, four locales/pseudolocale screenshots.
- **Blockers/dependencies:** missing design authority, brand licenses/assets, accessibility target policy.

This phase may run in parallel with a non-production Android foundation slice after Phase 1. Only the tokens, states, localization, and accessibility rules required by that slice are on its critical path; the broad catalog is a beta gate.

## Phase 3 — Backend stabilization

- **Objective:** make Core Server safe for two clients before feature load grows.
- **Repositories:** Core Server; small compatible iOS patches as needed.
- **Claude role:** migration/security/reliability plan; **Codex role:** implement contract fixes, tests, observability, backup/runbook evidence.
- **Deliverables:** canonical/compatible routes, expanded auth/domain integration tests, structured redacted logs, request correlation/metrics/alerts, scoped rate limits, health/readiness, migration and backup/restore runbooks.
- **Entry:** contract/design foundations accepted; staging isolation exists.
- **Exit:** parity APIs pass contract/integration/load/security checks; rollback/restore drill meets accepted RPO/RTO; dashboards/alerts exercised; old iOS remains compatible.
- **Verification:** Node tests, DB integration, staging smoke/load/failure tests, migration rehearsal, restore drill, security review.
- **Blockers/dependencies:** infrastructure access, data classification, SLO/RPO/RTO decisions, user-owned migration duplicates.

The parity-critical cutline before a non-production Android foundation slice is narrower: canonical routes/fixtures, compatible auth, environment isolation, sensitive-log controls, and a stable staging path. Broader domain coverage, load/security programs, centralized observability, SLOs, and measured backup/restore are parallel tracks and remain mandatory beta/production gates where applicable.

## Phase 4 — Android foundation

- **Objective:** create the authorized Android repo/project and prove one safe end-to-end vertical slice.
- **Repositories:** new Android repo plus contract/design artifacts and Core Server staging.
- **Claude role:** challenge module graph/security/state ownership; **Codex role:** scaffold, implement, test, and document foundation.
- **Deliverables:** Gradle convention/config, initial modules, CI, environment isolation, public network layer, navigation, design system, localization/accessibility, and the standard Trustworthy Search slice. Auth storage and authenticated AI Search enter only when their contract-backed slice starts.
- **Entry:** Phase 1 exits; the Phase 2 slice-level rules and Phase 3 parity-critical cutline above are met; Android repo creation is explicitly authorized; SDK/device/signing policies are decided. Full Phase 2/3 exit is not required for a non-production fixture/staging foundation slice.
- **Exit:** vertical slice passes unit/contract/UI/device/staging checks; module graph is minimal; no secrets in repo; release variant can produce an internal artifact.
- **Verification:** Gradle checks, dependency rules, emulator/device tests, process-death/offline/concurrent-auth tests, security scan.
- **Blockers/dependencies:** Play/app ID/signing ownership, current toolchain decisions, staging reliability.

## Phase 5 — Android feature parity

- **Objective:** implement accepted parity in vertical slices, prioritizing core value before long-tail widgets/social enhancements.
- **Repositories:** Android and Core Server; iOS only for compatible contract corrections.
- **Claude role:** per-slice architecture/risk review; **Codex role:** implement/test slices and maintain parity evidence.
- **Deliverables:** Search, Detail, Auth, Reviews, Favorites/Library/Steam, Profile/Social/Privacy, Notifications/Push, and scoped widgets/AI features.
- **Entry:** Android foundation accepted; backend SLO/contract stable.
- **Exit:** every included GP-P requirement meets its verification row; deferred items are explicit; no unresolved Blocker/High findings.
- **Verification:** unit/contract/integration/UI/screenshot/accessibility/localization/device/staging matrices.
- **Blockers/dependencies:** provider policies, Steam test account/privacy, push devices, feature creep.

## Phase 6 — iOS modernization

- **Objective:** address evidence-backed iOS debt independently of Android launch.
- **Repositories:** iOS; Core Server only for backward-compatible needs.
- **Claude role:** prioritize architecture changes by measured risk/value; **Codex role:** incremental refactors with regression tests.
- **Deliverables:** redacted network logging, canonical contract client, clearer composition, documented concurrency/cancellation, critical UI tests, accessibility fixes, dependency updates proven compatible.
- **Entry:** Android parity behavior stable enough to compare; changes have independent release plan.
- **Exit:** targeted debt metrics/risks improve without product behavior drift; physical-device/TestFlight gates pass for affected areas.
- **Verification:** existing/new XCTest, build/archive, UI/device, OAuth/push/widget/deep-link regression.
- **Blockers/dependencies:** signing/provider accounts, temptation to combine stylistic rewrite with delivery.

## Phase 7 — Cross-platform QA

- **Objective:** validate shared outcomes and intentional differences across current iOS, Android, and backend.
- **Repositories:** all three plus test/contract artifacts.
- **Claude role:** challenge coverage and release assumptions; **Codex role:** execute matrices, triage evidence, verify fixes.
- **Deliverables:** parity results, device/OS/localization/accessibility matrix, migration/compatibility report, security/privacy review, known-issues register.
- **Entry:** Android parity complete; candidate iOS/backend versions deployed to staging.
- **Exit:** no unresolved Blocker/High; accepted Medium/Low decisions recorded; rollback and support procedures rehearsed.
- **Verification:** real-device end-to-end flows, concurrency/offline/failure cases, contract/load/security/accessibility tests.
- **Blockers/dependencies:** device lab/testers, stable staging, representative accounts/data.

## Phase 8 — Beta

- **Objective:** validate reliability, usability, compatibility, and operations with controlled users.
- **Repositories:** all release artifacts and operational configuration.
- **Claude role:** analyze scope/risk changes; **Codex role:** prepare builds, monitor evidence, fix approved issues, verify releases.
- **Deliverables:** TestFlight/internal/closed-track releases, release notes, feedback/support loop, dashboards, go/no-go criteria.
- **Entry:** Phase 7 exit; store compliance/privacy artifacts accepted.
- **Exit:** agreed crash/ANR, latency/error, auth, push, retention, and task-success thresholds met; critical feedback resolved.
- **Verification:** signed installs, store pre-launch checks, beta telemetry, sampled end-to-end external integrations.
- **Blockers/dependencies:** reviewer/store delays, consent/analytics configuration, insufficient beta cohort.

## Phase 9 — Production release

- **Objective:** release with controlled blast radius and independent rollback.
- **Repositories:** tagged/release branches and deployment configuration; commits/pushes require explicit owner instruction.
- **Claude role:** final risk challenge; **Codex role:** execute approved checklists and final verification.
- **Deliverables:** staged Android rollout, compatible backend release, optional separate iOS patch, release/support/rollback communications.
- **Entry:** beta exit and explicit go decision; backups/rollback/feature flags ready.
- **Exit:** rollout reaches approved percentage with SLOs healthy and no unresolved critical incident.
- **Verification:** production synthetic/smoke checks, dashboards/alerts, store/crash/ANR data, compatibility checks for old iOS clients.
- **Blockers/dependencies:** live incident, migration failure, store rejection, external-provider outage.

## Phase 10 — Post-release monitoring

- **Objective:** protect users, learn from real behavior, and prioritize the next modernization slice.
- **Repositories:** operational docs, issue/task tracking, subsequent independently scoped changes.
- **Claude role:** architecture/product evidence synthesis; **Codex role:** monitor, diagnose, implement authorized fixes, verify outcomes.
- **Deliverables:** 24-hour/7-day/30-day reviews, incident/postmortem records, KPI/SLO comparison, debt and Option B/C decision update.
- **Entry:** production rollout begins.
- **Exit:** stabilization window closes; ownership/runbooks proven; follow-up roadmap accepted.
- **Verification:** alert history, crash/ANR/error/latency trends, auth/push/Steam success, support and product outcomes.
- **Blockers/dependencies:** missing telemetry/data governance, unclear on-call ownership, insufficient cohort size.

## Release sequencing guardrails

Never combine first Android launch with a destructive database migration, auth replacement, first-time deployment-platform migration, major iOS navigation rewrite, or unvalidated product redesign. Prefer additive server changes, compatibility windows, feature flags/kill switches where justified, and separate rollback units.

The first Android vertical slice is a learning artifact, not a production bypass. Beta still requires the applicable full Phase 2 and Phase 3 exits. A dependency register must state for every prerequisite whether it gates foundation, feature parity, beta, or production, with an owner and evidence.
