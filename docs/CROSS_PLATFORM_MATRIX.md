# Cross-Platform Matrix

## Outcome rules

This is the canonical user-outcome matrix requested for post-2.0 planning. Platform-specific type names, navigation mechanics, and storage APIs are not parity requirements. Source presence is reported separately from execution evidence.

| Outcome ID | User outcome | iOS 2.0/current working tree | Core Server dependency | Android target | Parity status |
|---|---|---|---|---|---|
| XP-01 | Browse useful game highlights and lists | Home highlights/popular/trending/recommendations and filters | Game discovery routes and IGDB proxy | Native Compose Home with partial-module states | iOS/backend source exists; Android and contract gate missing |
| XP-02 | Search and receive only results for the latest query | Debounce plus current generation guard; explicit loading/content/empty/error/retry | `GET /games/search`; stable error/normalization rules required | Lifecycle-aware `StateFlow` with `flatMapLatest` or generation guard | iOS implemented but unexecuted; backend OpenAPI/Android missing |
| XP-03 | Understand why a game is recommended | Rule-based and AI recommendation surfaces | Candidate, preference, Steam/friend signals, validated explanation | Native explanation UI from reason codes, not server prose alone | Incomplete on all platforms |
| XP-04 | View reliable game details under provider degradation | Canonical detail plus Steam fallback | IGDB/Steam mapping and fallback metadata | Detail destination with independent partial states | iOS/backend source exists; Android/contract missing |
| XP-05 | Save and track games consistently | Favorites and library status flows | Canonical PostgreSQL favorites/library state | Repository-backed native flows | Android missing; contract/runtime incomplete |
| XP-06 | Link Steam and understand sync freshness/failure | Link callback, sync status/freshness/cache UX | Link/callback/status/sync/mapping/provider behavior | Custom Tabs/App Link plus typed sync state | Android missing; external/device reliability unverified |
| XP-07 | Authenticate safely and recover sessions once | Guest gates and current single-flight refresh work | Access/refresh rotation, revocation, active-user checks | Credential storage plus single-flight authenticator | Partial OpenAPI exists; runtime/provider/Android missing |
| XP-08 | Participate in review discussions across devices | Review CRUD server-backed; comments/reactions currently local-backed | Canonical review/comment/reaction APIs | Compose thread/reply/spoiler states | Review partial; discussion parity blocked by iOS integration gap |
| XP-09 | Report or block and see enforcement everywhere | Current production repository path is local-backed | Server reports/blocks/filtering | Server-backed moderation actions and filtered content | Not integrated; High parity gap |
| XP-10 | Discover friends/activity within privacy choices | Friend/profile/activity/privacy UI | Social/privacy/presence/recommendation routes | Native profile/social destinations | Android missing; privacy/runtime fixtures incomplete |
| XP-11 | Receive useful, non-duplicated notifications that open the right place | FCM token, list/read/badge and deep-link dispatcher | Notification storage/publish/token cleanup | FCM channels/permission plus route dispatcher | Preferences/durable delivery/Android/device evidence missing |
| XP-12 | Keep one account's local data isolated from another | Several global cache/UserDefaults/app-group keys | Server remains canonical | Account-scoped DataStore/Room/cache keys where used | High iOS privacy/reliability gap; Android policy required |
| XP-13 | Use the product in ko/en/ja/zh-Hans with accessible native controls | Four resources; partial semantics | Stable codes/data rather than hardcoded localized errors | Android resources, pseudolocale, TalkBack/font-scale support | Acceptance and device checks missing |

## Selected cross-platform release slice: Trustworthy Search (PARTIAL)

The current working tree contains the iOS sub-slice only. The release boundary includes all four columns below; plans and source presence do not substitute for executable parity evidence.

| Requirement | iOS | Backend | Android | Required cross-platform verification |
|---|---|---|---|---|
| Latest query wins | Request UUID plus task cancellation in working tree | Idempotent Search request; cancellation does not imply server cancellation | `flatMapLatest` or generation token | Controlled late-response tests on both clients |
| Explicit states | Pure presentation-state resolution for loading/content/empty/error | Stable success/error envelope and retry classification | Sealed/typed UI state | Fixture, reducer/ViewModel, UI semantics tests |
| Retry | Retry current normalized query without debounce | Safe GET retry and typed rate/provider failures | Explicit retry event | Failure-then-success tests and staging smoke |
| Query privacy | Changed path logs length/count/type, not raw query | No raw query/prompt/provider body in logs; retention policy required | No raw query persistence/logging | Static scans plus distribution/operator log inspection |
| Filters | Genre is currently local-only and does not repeat request | Decide canonical filter/sort parameters before parity | Implement accepted server semantics, not UIKit behavior | Request-count and locale/canonical-value fixtures |
| Localization/accessibility | Four failure strings, Dynamic Type label, 44-point retry target | Stable codes; client owns localized copy | Four locales plus Compose semantics | VoiceOver/TalkBack, large-font and focus checks |

## Sequencing

1. Execute the current iOS Search tests/build/runtime checks in a normal Xcode environment.
2. Add Search and suggestions to executable OpenAPI with success, error, normalization, rate-limit/provider-degraded, pagination/limit, date, and nullability rules.
3. Add server HTTP/fixture tests and iOS decoder compatibility tests; verify staging.
4. Resolve Android identity, SDK, signing, environments, and release ownership.
5. Create `GamePedia_AOS` as an independent Git/Gradle project and implement Search as the first thin vertical slice after the identity, toolchain, design, and contract gates are accepted.

`CROSS_PLATFORM_PARITY.md` contains the broader risk-oriented baseline; this file is the requested release outcome matrix.
