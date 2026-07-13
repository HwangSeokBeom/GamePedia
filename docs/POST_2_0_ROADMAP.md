# GamePedia Post-2.0 Roadmap

## Decision boundary

Snapshot date: 2026-07-13. This document separates repository evidence from production evidence. The iOS and Core Server working trees are dirty and contain user-owned work. `GamePedia_AOS` exists only as an empty placeholder directory: it is not a Git or Gradle repository. The backend has a committed 17-operation OpenAPI gate subset, but roughly 116 registered operations remain outside it and several canonical route implementations are still uncommitted. Production, staging, simulator, device, provider, database-migration, and Android behavior are therefore not established by this plan.

## Executive summary

The proposed next cross-platform release slice is **Trustworthy Search**. The current working tree contains only its **iOS sub-slice**: latest-query authority, distinct transport-failure/empty states, retry, removal of redundant genre-chip requests, privacy-safer Search diagnostics, and focused regression tests. The requested vertical slice is still **PARTIAL** because backend Search OpenAPI/HTTP fixtures, native Android implementation, and cross-platform execution evidence do not exist.

This is not the largest long-term product opportunity. A personalized discovery home using Steam, recent-play, taste, review, and friend signals has higher differentiation potential, but it currently needs a complete contract, module/fallback semantics, product ranking decisions, analytics, and cross-platform acceptance criteria. Reviews/discussions and account-isolated local state also contain High-severity gaps that must be resolved before a broader production-readiness claim.

Android is not scaffolded in this sub-slice. The machine-readable contract does not yet cover Search or AI Search. Creating a client now would encode undocumented behavior.

The global logging security requirement is also not satisfied by the narrow Search scan. Current client/server sources still contain direct logging of stable identifiers and uncontrolled error descriptions. A complete logging inventory, hashed structured logger migration, sentinel tests, and distribution/staging log inspection are release blockers.

## Opportunity analysis

Scores are relative, from 1 (least favorable) to 5 (most favorable). Complexity and operational risk are inverse scores: 5 means lower cost/risk.

| Candidate | User impact | Differentiation | Readiness | Complexity | Cross-platform feasibility | Operational risk | Testability | Rationale |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| Trustworthy Search | 4 | 2 | 5 | 5 | 5 | 5 | 5 | Existing endpoint/UI; concrete race, error, retry, privacy, and duplicate-call weaknesses |
| Personalized Discovery Home | 5 | 5 | 3 | 2 | 3 | 2 | 3 | Best strategic upside; requires a new module contract, ranking decisions, fallbacks, analytics, and backend work |
| Steam Sync Trust | 4 | 4 | 3 | 2 | 4 | 2 | 3 | Useful existing data; durable sync-run state/worker and provider staging evidence are missing |
| Discussion/Moderation Integration | 4 | 3 | 2 | 2 | 4 | 2 | 3 | Backend exists, but iOS discussion and moderation paths remain local-only and need migration/reconciliation |
| Account-Isolated Offline State | 5 | 1 | 3 | 3 | 4 | 4 | High privacy value; cache ownership and logout/delete clearing span several stores and widgets |
| Notification Preferences | 3 | 2 | 2 | 2 | 4 | 2 | 3 | Needs preferences model, quiet-hour rules, durable delivery, and operations ownership |

## Selected post-2.0 release scope (PARTIAL)

### Primary product improvement

**Trustworthy Search:** standard game search always represents the latest normalized query and exposes loading, content, legitimate empty, failure, and retry states distinctly. Completion means backend contract/API/tests, iOS, Android, and parity verification; the current artifact is the iOS sub-slice only.

### Supporting improvements

1. **Request efficiency:** changing the local genre chip no longer repeats the same backend request while `/games/search` ignores genre.
2. **Privacy-safe diagnostics:** log query length, result count, and error type only; never raw query or response payload.
3. **Cross-platform definition:** document the exact Android outcome and backend contract work before implementation.

### Traceable requirements

| ID | Requirement | Implementation/evidence | Acceptance verification |
|---|---|---|---|
| P20-S01 | Only the newest query may update standard search results or error state | `SearchViewModel` request UUID plus task cancellation | Controlled late-response unit test |
| P20-S02 | A failed request must not be rendered as “no results” | `SearchState.errorMessage`, reducer error mutation, dedicated error view | Reducer/ViewModel test and UI runtime check |
| P20-S03 | Failure must offer an immediate retry using the current query | `SearchIntent.retryTapped`, retry button, zero-debounce retry | Failure-then-success unit test and UI runtime check |
| P20-S04 | Clearing a query must cancel pending work and reset loading/content/empty/error | `invalidateSearch()` and reducer reset | Inverted pending-request unit test |
| P20-S05 | Genre selection must not duplicate an identical request while the server ignores genre | Local filtering retained; network resubmission removed | Request-count unit test |
| P20-S06 | Search diagnostics must not log query text or response bodies | Query length/result count/error type logs in changed Search paths | Full-repository sentinel scans plus distribution/server runtime log inspection; narrow scan alone is insufficient |
| P20-S07 | New user-facing failure copy must be localization-ready and accessible | ko/en/ja/zh-Hans keys, 44-point retry control, semantic button/title | strings validation plus VoiceOver/localization device check |
| P20-S08 | Android must reproduce latest-query-wins and explicit state outcomes after contract freeze | `CROSS_PLATFORM_MATRIX.md`, `ANDROID_NATIVE_PLAN.md` | Future serializer/ViewModel/Compose/staging suite |
| P20-S09 | No client/server log may expose prohibited data or unhashed stable identifiers | Current narrow Search redaction plus unresolved global audit | Full logging inventory, centralized redacted logger, sentinel tests, distribution/staging inspection |

## Product changes

- Users no longer see an older result set overwrite a newer query when requests complete out of order.
- Network/server failures have a clear, retryable state instead of appearing as a valid zero-result search.
- Clearing search consistently removes pending/loading/error state.
- Genre chips continue to filter the complete returned result set locally without an unnecessary repeat call.
- Existing AI search assistance remains independent; it is not presented as proof that standard search succeeded.

## iOS implementation plan

1. Add an explicit search loader seam and request identity to make cancellation/race behavior deterministic and testable.
2. Extend state/reducer/intent with prepare, error, clear, and retry transitions.
3. Add an accessible error/retry surface and localized copy.
4. Add focused tests for late response suppression, retry recovery, clear cancellation, genre request deduplication, presentation-state separation, and stable canonical genre matching.
5. Run full-project syntax, localization, diff, project, build, XCTest, runtime, localization, and VoiceOver checks as the environment permits.

## Backend work breakdown

Required before cross-platform release, not implemented in this writable repository:

1. Add `/games/search` and `/games/suggestions` to the executable OpenAPI contract, including `q`, `limit`, normalization, locale behavior, success/error envelopes, rate-limit outcomes, and cache/fallback metadata.
2. Decide whether genre is a supported server filter. Until accepted, omit it from the shared contract and keep iOS local filtering explicit.
3. Add actual HTTP tests without mocked auth/service behavior, plus database/provider-degraded fixtures where meaningful.
4. Add distributed privacy-safe search/AI abuse controls. Current process-local/push-only rate limiting is insufficient.
5. Define and execute retention cleanup for historical raw search/AI database and file logs; new hashed writes do not sanitize old data.
6. Resolve account-deletion profile-media cleanup and Steam callback redirect allowlisting before a production-readiness claim.

## Android work breakdown

No GamePedia Android repository exists; only the empty `GamePedia_AOS` directory is present. Do not create files in it until the owner accepts application ID, SDK/device support, signing/Play ownership, environments, first parity slice, and the relevant OpenAPI expansion.

When the Search slice starts, use a lifecycle-aware ViewModel and `StateFlow`; normalize/debounce the query; use `flatMapLatest` or an equivalent generation token; expose idle/loading/content/empty/error states; keep retry explicit; do not persist or log raw queries; and validate serializers against the same server fixtures. Compose semantics tests must verify error announcement, retry, keyboard search, focus, large fonts, and four locales.

## API and data changes

### Current iOS slice

- No endpoint, request, response, database, or migration change.
- `/games/search` continues to send `q` and `limit` only.
- Genre remains a client-side presentation filter and is not claimed as a server contract.
- Search error state is transient in memory; no raw query is persisted.

### Future personalized-home release

Prefer a versioned module response with stable module IDs, ordered items, reason codes, source/provenance, freshness, and per-module degraded state. Do not require the entire home to fail when one provider/module fails. This proposal requires product and API acceptance before implementation.

## Migration plan

No application/database migration is required for the current iOS sub-slice. It is compatible client work, not the completed cross-platform Trustworthy Search release. Release completion requires the contract-first backend increment and native Android slice described above.

Future backend work must include a separate, owner-approved privacy migration or operational cleanup for historical raw query/AI records and file logs. It must inventory affected stores, define retention/legal ownership, back up or irreversibly sanitize according to policy, verify counts and samples without exposing content, and include rollback/incident procedures. Do not edit duplicate-suffixed migration files.

## Test plan

| Level | Trustworthy Search gate |
|---|---|
| Syntax/format | Swift parse, strings `plutil`, `git diff --check`; formatter remains unresolved |
| Static/privacy | Scan changed search paths for raw-query/body logging and unsafe persisted query keys |
| Type/build | `GamePedia-Dev` generic Simulator build with signing disabled |
| Unit | Six focused SearchViewModel/presentation tests plus existing XCTest suite |
| Integration/contract | Backend schema validation and actual `/games/search` HTTP fixtures; not satisfied by the current partial OpenAPI |
| Runtime/UI | Slow/failed/out-of-order response, retry, clear, genre change, AI-assist coexistence |
| Accessibility/localization | VoiceOver focus/announcement, 44-point target, Dynamic Type, ko/en/ja/zh-Hans |
| Android | Future serializer, ViewModel, Compose semantics, emulator and staging checks |
| External/production | Owner-authorized IGDB/provider and deployed-server smoke; no production mutation from this task |

## Deferred items

- Personalized discovery-home endpoint and UI modules
- Durable Steam sync-run state and background worker
- Server-backed iOS discussions/moderation migration and offline reconciliation
- Account-scoped cache/widget/local discussion state and logout/delete purge
- Notification preferences, quiet hours, durable push outbox/retry
- Full OpenAPI coverage and generated clients
- Android scaffolding and Play operations
- Search history, saved filters, typo tolerance, pagination, server genre/platform/rating filters, and offline result cache

## Release gates and remaining risks

The cross-platform slice cannot be called complete or production-verified until the backend contract/tests, iOS build/XCTest/runtime/accessibility checks, Android implementation/build/tests, staging parity, and independent finding resolutions exist. Existing High risks—global identifier/sensitive-data logging, account-crossing local caches, local-only moderation/discussions, deleted profile media, historical sensitive logs, auth/search abuse controls, incomplete contract, and unverified backend deployment—remain explicit release blockers.

## Challenger findings and resolutions

| Finding | Severity | Resolution | Evidence and remaining verification |
|---|---|---|---|
| Loading/debounce could render as a legitimate empty result because two UI derivations disagreed | High | **ACCEPTED** | Replaced duplicate visibility logic with one pure `SearchPresentationState.resolve`; empty requires completed successful search. Added transition coverage for debounce/loading/empty/error/AI. XCTest/runtime remain unexecuted. |
| Combined canonical route/required-field stabilization can be incompatible with an older deployed server | High | **PARTIALLY_ACCEPTED** | The risk predates Trustworthy Search. Client release remains gated on backend-first promotion or an accepted tolerant compatibility window plus old/new fixtures and staging. No release/commit/push is performed here. |
| Localized genre chip labels were compared directly with canonical backend genre names | Medium | **ACCEPTED** | Added stable `SearchGenre` IDs, localized display names, canonical token matching, and canonical matching tests. Four-locale runtime/UI checks remain required. |
| Documents overstated explicit state behavior while the rendering defect existed | Medium | **ACCEPTED** | The rendering defect was fixed; evidence remains explicitly qualified as unexecuted and runtime-unverified in the roadmap, parity map, tasks, and verification log. |
| Baseline named a friend-activity widget and stale unit-test count | Low | **ACCEPTED** | Corrected to current-user activity, noted orphaned friend-activity snapshot infrastructure, and refreshed the unit-test source count to 22. |
| Final Verifier found controller callbacks could mix a captured old state with the newest ViewModel state | Medium | **ACCEPTED** | Search callbacks now render the captured immutable state atomically; AI-only updates use the last rendered Search state. Controller scheduling/runtime tests remain unexecuted. |
| Final Verifier found residual OpenAPI/test-count documentation inconsistencies | Medium | **ACCEPTED** | Baseline language now identifies the partial 17-operation gate and lack of a generated/complete contract; the test plan now records six focused tests. |
| Global logging security requirement is not gated by the narrow Search scan | High | **PARTIALLY_ACCEPTED** | Documentation now makes the full client/server logging inventory, hashed structured logging, sentinel tests, and distribution/staging inspection a release blocker. Broad code remediation remains unsafe while the backend is dirty on `main`, so the High risk remains unresolved and status cannot be `VERIFIED`. |
| Current Trustworthy Search was labeled as a complete release slice | Medium | **ACCEPTED** | Renamed it an iOS sub-slice and marked the cross-platform release `PARTIAL`; completion now traces to backend contract/tests, iOS, Android, and parity evidence. |
| Android Home-to-Detail foundation conflicted with selected Search scope | Medium | **ACCEPTED** | Search is now the single proposed first Android vertical slice in the decision record, Android plan, roadmap, matrices, and tasks. |
| Repeated five-route backend count was unsupported | Medium | **ACCEPTED** | Removed the count and require a HEAD-versus-working-tree table for all 17 OpenAPI operations before promotion. |
| UIKit controller count was ambiguous | Low | **ACCEPTED** | Inventory now records 36 concrete controllers plus one generic base controller; the repo-wide filename command returns 37. |

No commit or push is authorized by this request. See `VERIFICATION.md`, `RISK_REGISTER.md`, and `CROSS_PLATFORM_PARITY.md` for current evidence and gaps.
