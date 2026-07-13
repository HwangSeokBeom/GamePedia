# Cross-Platform Capability and Parity Map

## Evidence rules

Snapshot date: 2026-07-13. “Implemented” means source routes/types/UI exist; it does not imply staging or production success. “Verified” requires observed execution at the stated level. No capability is currently fully verified across iOS, Android, backend, database, device, and external providers. `GamePedia_AOS` is an empty placeholder directory, not a Git or Gradle repository. See `CROSS_PLATFORM_MATRIX.md` for the requested outcome-oriented matrix.

Status vocabulary follows the post-2.0 request: implemented and verified; implemented but incomplete; implemented but not integrated; implemented with UX/reliability weaknesses; missing; deprecated/duplicated; or externally blocked.

## Current capability map

| Capability | Baseline classification | iOS evidence and weakness | Backend/contract evidence | Tests/operations | Android parity |
|---|---|---|---|---|---|
| Email/social auth, refresh, logout/delete | Implemented with reliability/runtime gaps | Auth layers; current single-flight/generation work is unexecuted | Auth routes and transactional refresh CAS; account deletion leaves profile media | Focused refresh tests exist; provider/device/runtime unverified | Missing; contract subset covers refresh only |
| Profile/privacy/titles | Implemented but incomplete | Profile flows and privacy DTOs; local caches are not account-scoped | User/privacy routes; canonical routes partly uncommitted | Fixture coverage only; retention/export unresolved | Missing |
| Home discovery | Implemented with UX/reliability weakness | Highlights/popular/trending/today recommendation; all-or-nothing load and no rendered retry | Game routes and recommendation foundations | Selected unit tests; no runtime/analytics acceptance | Missing; absent from OpenAPI gate |
| Standard Search | Implemented with UX/reliability weakness; current slice improves it | Debounce/genre/AI UI; latest-query/error/retry changes added in working tree | Search/suggestion routes exist; absent from OpenAPI gate; genre not accepted | New focused tests added but XCTest/runtime unexecuted | Missing |
| AI search/recommendations/summary/curator | Implemented with provider/fallback gaps | Four AI surfaces with deterministic/unavailable fallbacks | Validated outputs, caches, quotas/logs; provider runtime unresolved | Unit coverage exists; staging quality benchmark missing | Missing; absent from gate |
| Game detail | Implemented with integration uncertainty | IGDB detail, Steam fallback, favorite/review/AI context | Game/provider routes | Selected mapping tests; external/runtime unverified | Missing |
| Favorites and play status | Implemented with reliability gaps | Domain/Data/UI flows and library state | Favorites/library routes and PostgreSQL | Sparse integration/runtime coverage | Missing |
| Steam link, ownership, recent play, sync | Implemented with reliability/operational weakness | Link callback, sync, status/freshness UI, local cache | Rich library services; process-local sync coordination; canonical work uncommitted | Provider/device/background/runtime unverified | Missing; gate covers only status/import subset |
| Friends/activity/recommendations | Implemented but incomplete | Friend/profile/activity UI; compatibility DTOs | Social/privacy/recommendation/presence routes | Sparse integration; privacy runtime unverified | Missing |
| Reviews CRUD/likes | Implemented but runtime-unverified | Server-backed review repository/use cases | Review routes/services/PostgreSQL | Unit/DTO tests; staging integration missing | Missing |
| Comments/replies/reactions | Implemented but not integrated | iOS uses local data source/state | Server has threaded discussion routes | Cross-device/reconciliation tests missing | Missing |
| Reports/blocking/moderation | Implemented but not integrated | iOS moderation data source is local-only | Server report/block filtering; no moderator lifecycle/audit/appeal | Server-enforcement client flow unverified | Missing |
| Notifications/push/deep links | Implemented with reliability weakness | FCM registration, list/read/badge/routes plus local merge | Stored notifications, FCM, invalid-token cleanup; no durable outbox/preferences | Physical push/cold-warm route/device unverified | Missing |
| Widgets/system surfaces | Implemented but documentation duplicated/stale | Trending, recent-viewed, review prompt, activity widget sources; no friend-activity widget registered | Widget summary routes exist | Widget/device/privacy runtime unverified | Missing |
| Offline/cache | Implemented but unsafe/incomplete | Library/activity/comment/moderation/widget caches use global keys and may cross accounts | Server remains canonical | Logout/delete/account-switch isolation tests missing | Missing |
| Localization | Implemented but UI-unverified | ko/en/ja/zh-Hans resources | Some backend user copy is hardcoded Korean | Strings parse; layout/runtime/accessibility unverified | Missing |
| Accessibility | Missing accepted baseline | Ad hoc UIKit semantics only | Mostly client-owned | No comprehensive VoiceOver/Dynamic Type suite | Missing |
| OpenAPI/client contract | Implemented but incomplete | Hand-authored endpoints/DTO fixtures | 17-operation subset vs ~133 registered operations; compatibility aliases | Schema validator passes; real HTTP/DB/deployment incomplete | Blocked |
| Observability/abuse controls | Implemented but incomplete | Numerous `print` calls; reviewed sensitive values redacted | Winston/local logs; no SLOs/traces, narrow process-local limiter | Distribution/log-retention/load evidence missing | Missing |
| Android client | Missing and contract-blocked | N/A | Gate subset is insufficient for first full product parity | No Gradle/Kotlin/manifest evidence | Missing |

## Deprecated and duplicated surfaces

- Backend compatibility aliases cover old privacy, recent-play, push-token, Steam-status, and friend-recommendation paths. Android must use canonical operations only.
- Backend has user-owned duplicate-suffixed source, test, and migration files. They are excluded from canonical inventories and must not be changed without forensic owner review.
- iOS resources and generated localization artifacts have multiple historical locations; the application target uses the `GamePedia` synchronized tree. Do not infer both are runtime resources.
- Earlier baseline wording that described a friend-activity widget or said no OpenAPI existed has been corrected; future edits must preserve the distinction between the registered widgets and the partial OpenAPI gate.

## Selected Trustworthy Search parity

| Outcome | iOS working-tree status | Backend dependency | Future Android requirement | Current gap |
|---|---|---|---|---|
| Latest query wins | Implemented; tests added | Existing search route | `flatMapLatest`/generation guard | iOS XCTest/runtime not run; Android absent |
| Explicit loading/content/empty/error | Implemented in state/UI | Stable error envelope | Sealed/typed UI state | Backend search schema absent; runtime unverified |
| Retry current query | Implemented | Idempotent GET | Explicit retry event | Runtime/accessibility unverified |
| Query privacy | Length/type/count logging only in changed iOS path | Hashed new writes; historical retention unresolved | No raw log/persistence | Distribution/operator audit unresolved |
| Genre behavior | Client-only filter, no repeat request | Contract decision needed | Match accepted contract, not iOS mechanics | Server genre support absent/unaccepted |
| Localization/accessibility | Four failure strings and 44-point retry control | Error codes, not user copy | Four resources and Compose semantics | Device/font/VoiceOver/TalkBack unverified |

## First Android release gate

Do not scaffold until the owner accepts supported SDK/device policy, package/signing/Play ownership, environments, beta scope, privacy/data-safety rules, and a complete contract for the first vertical slice. The proposed first slice is public standard Search after its operations and fixtures are machine-checkable; authenticated AI Search follows the auth foundation. Functional and contract parity precede visual micro-parity.
