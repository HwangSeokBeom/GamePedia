# Current Platform Matrix

## Evidence boundary

Snapshot date: 2026-07-13. This audit uses repository source, tests, configuration, and the tracked partial OpenAPI document. It does not establish staging, production, provider, device, or store behavior. `GamePedia_AOS` is an empty directory, not a Git or Gradle project. The Core Server is on `main` with extensive user-owned changes, so this audit did not modify it.

## Current-state audit

| Audit area | iOS | Core Server | Android | Status |
|---|---|---|---|---|
| Repository | Git worktree on `dev`; extensive user-owned modified/untracked work | Git worktree on `main`; extensive user-owned modified/untracked and duplicate-suffixed files | Empty `GamePedia_AOS` directory; no `.git`, Gradle, manifest, Kotlin, or tests | iOS auditable; backend read-only; Android creation gated |
| Screens | 36 concrete UIKit controllers plus one generic `BaseViewController`; WidgetKit/translation-host SwiftUI surfaces also exist | N/A | None | iOS implemented; Android missing |
| Presentation state | 20 ViewModels; 11 Intent, 11 Mutation, 11 Reducer, and 21 State files; Combine plus structured concurrency | Request/service state, validation, and error middleware | None | iOS feature-local MVI exists; no shared client state contract |
| Networking | `URLSession`, hand-authored `Endpoint`/`AuthEndpoint`, DTO/mappers, shared decoder | Express routes/controllers/services; Zod validation; success/error envelopes | None | Broad source compatibility, incomplete machine-readable contract |
| DTO/API contract | Hand-authored DTOs; representative canonical fixture tests in working tree | OpenAPI 3.1 gate: 12 paths, 17 operations, 18 schemas; roughly 133 registered operations by existing static inventory | None | OpenAPI is a subset, not a complete Android contract |
| Cache/persistence | Memory caches, `NSCache`, global `UserDefaults` stores, Keychain refresh token/device ID, app-group widget snapshots | PostgreSQL/Prisma canonical state; process-local caches/rate limits; optional Redis probe only | None | Account isolation and distributed-cache semantics incomplete |
| Tests | 22 unit-test files and 2 template-level UI-test files | Unit/contract/HTTP integration tests exist; broad domain/DB/runtime coverage incomplete | None | Static/unit evidence partial; runtime parity unavailable |
| Runtime behavior | Simulator/build/tests blocked in the managed environment by SwiftPM package access/sandbox and CoreSimulator availability | HTTP/DB/provider/deployment behavior not exercised by this audit | No runnable project | Runtime unverified on every platform |

## Capability matrix

“Implemented” means source exists; it does not mean production-verified.

| Feature | iOS | Backend | Android | Status |
|---|---|---|---|---|
| Authentication and refresh | Implemented; current working tree adds single-flight/generation safeguards | Implemented; refresh is in partial OpenAPI | Missing | Runtime/provider verification required |
| Profile and privacy | Implemented | Implemented; canonical privacy operations are in partial OpenAPI | Missing | Source-aligned; deployment unverified |
| Home discovery | Implemented | Implemented routes/services | Missing | Outside OpenAPI gate |
| Standard search | Implemented; current working tree adds latest-query/error/retry behavior | Implemented `/games/search` and suggestions | Missing | Selected post-2.0 slice; Search contract still outside OpenAPI |
| AI search/recommendations/summary/curator | Implemented with fallbacks | Implemented with provider/cache/quota behavior | Missing | Provider quality/runtime and contract unverified |
| Game detail | Implemented with Steam fallback | Implemented IGDB/provider routes | Missing | Outside OpenAPI gate |
| Favorites and play status | Implemented | Implemented | Missing | Contract/runtime coverage incomplete |
| Steam link, ownership, recent play, sync | Implemented with cache/status UX | Implemented; selected status/recent/import operations are OpenAPI-gated | Missing | Provider/background reliability unverified |
| Friends, activity, recommendations | Implemented | Implemented | Missing | Privacy and pagination need fixture/runtime checks |
| Reviews CRUD and likes | Implemented against server | Implemented | Missing | Sparse integration/runtime evidence |
| Comments, replies, reactions | Implemented locally in production repository path | Implemented server routes | Missing | Not integrated cross-device; High gap |
| Reporting and blocking | Implemented locally in production repository path | Implemented server moderation routes | Missing | Not integrated with canonical server; High gap |
| Notifications and push | Implemented list/read/token/deep-link flow plus local merge | Implemented storage/FCM/token cleanup | Missing | Preferences, durable delivery, and device verification missing |
| Widgets/system integration | Four WidgetKit surfaces and app-group snapshots | Selected supporting summaries/routes | Missing | Device/privacy parity unverified |
| Localization | ko/en/ja/zh-Hans resources | Locale behavior varies by feature/provider | Missing | Layout and accessibility runtime unverified |
| Accessibility | Ad hoc semantics; no accepted comprehensive baseline | Mostly client-owned | Missing | Shared acceptance criteria required |

## Release conclusion

The realistic next cross-platform slice is **Trustworthy Search**, because it fixes a high-frequency discovery path with limited migration risk and deterministic tests. Only the iOS sub-slice is present in the current working tree. The cross-platform release remains **PARTIAL** until the backend Search contract/tests, Android implementation, and parity/staging evidence exist. Personalized Home remains the stronger strategic follow-up after the contract and signal/fallback model are accepted.

Android scaffolding is blocked until the owner accepts the package/application ID, minimum and target/compile SDK policy, Play/signing ownership, environment strategy, supported devices, and first contract-backed vertical slice. The local host has JDK 17 and Android SDK components, but no project wrapper or reproducible Android build definition.
