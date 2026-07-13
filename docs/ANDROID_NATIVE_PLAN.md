# Android Native Plan

## Preconditions and design stance

Do not create the Android project until Phase 0 repository adoption and Phase 1 product/API contract freeze exit. `/Users/hwangseokbeom/Documents/GitHub/GamePedia_AOS` currently exists only as an empty directory; it is not a Git or Gradle project. The proposal uses Kotlin, Jetpack Compose, ViewModel, StateFlow, and Coroutines, but package/application ID, library/plugin versions, minimum/target/compile SDK, and signing/Play ownership remain `UNRESOLVED` until official platform requirements, device analytics, and owner policy are reviewed and accepted.

Local host evidence is insufficient to remove those gates: JDK 17, Android Studio 2025.3, SDK platform `android-36.1`, and several Build Tools are installed, but there is no project Gradle wrapper, global Gradle command, confirmed Kotlin/AGP/Compose toolchain, or reproducible CI definition.

Android should reproduce GamePedia outcomes, not Swift class names. Use unidirectional state for complex screens, platform lifecycle-aware ViewModels, immutable UI state, suspend/Flow domain ports, and explicit navigation destinations. Do not create a UseCase for every method or a module for every screen without a real boundary.

Current gate evidence: `GamePediaCoreServer/openapi/cross-platform.openapi.json` is a committed 2.0 subset with 12 paths, 17 operations, and 18 schemas, and it permits `platform=android` for push tokens. It does not cover the selected Search slice or AI Search. Several matching canonical/compatibility route behaviors are still uncommitted/deployment-unverified. Therefore the contract-freeze precondition is not yet satisfied and no Android project should be scaffolded from this document alone.

## Candidate repository/module shape

The following is an eventual candidate graph, not a scaffolding checklist:

```text
:app                         composition, application lifecycle, top-level navigation
:core:model                  stable domain models/enums
:core:network                transport, auth interceptor/authenticator, serialization, errors
:core:data                   repositories, local/remote data sources, contract mapping
:core:database               Room only for justified durable/offline data
:core:designsystem           tokens, components, typography, icons, accessibility rules
:core:testing                fixtures, fakes, coroutine/test helpers
:feature:home
:feature:search
:feature:gamedetail
:feature:reviews
:feature:library
:feature:profile
:feature:auth
:feature:notifications
```

For the first Trustworthy Search slice, create only `:app`, one compact core boundary (or the minimum of model/network/data that tooling proves necessary), `:core:designsystem`, and `:feature:search`. Keep test helpers inside their owners initially. Extract database, testing, auth, home, detail, reviews, library, profile, and notifications modules only when their feature starts and an independent dependency, ownership, reuse, or build-isolation reason is recorded.

Keep social/friends/settings inside `feature:profile` initially and AI flows inside the owning Home/Search/Detail/Library features. Split them only when independent ownership, build isolation, or reuse justifies it. Widgets can begin in `:app` or a later `:feature:widgets` once parity scope confirms them.

Allowed dependency direction: feature -> core public APIs; core network/data -> model; `:app` -> all composition APIs. Feature modules must not depend on one another directly; navigation contracts or app-level routing connect them.

## Platform services

| Concern | Proposed Android-native direction | Decision gate |
|---|---|---|
| Networking | Retrofit/OkHttp or Ktor client with kotlinx.serialization; choose after a thin spike against frozen fixtures | No selection before contract freeze |
| Auth | Bearer interceptor plus single-flight refresh authenticator; encrypted credential storage for refresh token, memory access token | Security review and refresh state machine |
| Persistence | DataStore for settings; Room only for defined offline/cache/query needs | No speculative full-server mirror |
| Navigation | Navigation Compose with typed destinations/deep links; app-level route dispatcher | Frozen route outcomes |
| Images | Current maintained Compose image loader selected during foundation | URL/cache/privacy requirements |
| Push | Firebase Cloud Messaging; token registration with `platform=android`; notification channels and permission UX | Server validator and Android permission policy |
| Deep links | Verified Android App Links where domain exists; custom scheme fallback only if needed | Web-domain association ownership |
| Background | WorkManager for deferrable token/snapshot/sync work; foreground service only with evidenced need | Battery/data constraints |
| Widgets | Glance/AppWidget candidate for scoped widget parity | Product priority and refresh limits |
| Observability | Structured redacted client events, crash/error reporting provider `UNRESOLVED` | Privacy policy and provider decision |

## State and error model

Each feature exposes immutable `UiState` and accepts user events. ViewModels launch lifecycle-owned coroutines, delegate durable work to repositories, and reduce results into explicit loading/content/empty/partial/error/auth-required states. Server error codes stay typed below presentation; localized user copy is selected by client policy unless the contract explicitly declares server-owned copy.

Cancellation, retry, optimistic updates, stale-cache rendering, and conflict repair must be specified per mutation. Network availability is not a Boolean product state; repositories return cached/fresh provenance where caching exists.

## Feature parity matrix

| Product requirement | iOS reference behavior | Backend dependency | Android-native implementation | Platform difference | Verification |
|---|---|---|---|---|---|
| GP-P01 Home | Home coordinator, filters, highlights/popular/trending/today recommendation | `/games/highlights`, `/popular`, `/recommended`; local rule-based recommendation | Compose feed, feature ViewModel/StateFlow, lazy lists, saved filter state | Back behavior, window sizes, scroll restoration | Fixture tests, reducer/ViewModel tests, screenshot/accessibility, staging feed smoke |
| GP-P02 Search | Suggestions, debounced search, genre chips, AI assist | games search/suggestions and AI search-assist | Debounced Flow with `flatMapLatest`, query state, typed results | IME actions, predictive back, process restore | Query/cancellation tests, locale cases, network fallback, staging |
| GP-P03 Detail | IGDB detail, favorite/review, translation host, Steam fallback, AI summary | game/review/favorite/AI routes | Detail destination with parallel repository loads and partial states | Translation UI differs; adaptive layout | Contract fixtures, partial-failure tests, accessibility/screenshot, staging |
| GP-P04 Reviews | Create/edit/delete/like; nested discussion/reactions/reporting | Review and moderation routes | Compose forms/lists; Paging only if frozen contract supports it; optimistic mutations with repair | Keyboard, spoiler affordance, Android share | Validation/ownership/error tests, deep-link route, moderation staging test |
| GP-P05 Favorites/library | Favorite changes, status sections, local cache | favorites and library routes | Repository-backed screens; DataStore/Room only for specified cache | Process death and offline surfaces | Mutation consistency, empty/privacy/rate-limit states, contract smoke |
| GP-P06 Steam | External browser link/callback, privacy guides, sync/fallback | Steam link/callback/sync/library routes | Custom Tabs/App Link callback, persisted pending state, WorkManager only for permitted sync retry | App Links/browser task behavior differs | Cancel/error/replay/security tests, staging Steam sandbox/account |
| GP-P07 Auth | Guest shell, modal auth, email/Apple/Google, refresh/logout/delete | auth routes/social verification | Credential Manager/provider SDKs as appropriate; app-level auth gate; single-flight refresh | Sign in with Apple availability/policy and Credential Manager UX | Unit state machine, concurrent 401, process restore, provider/device staging |
| GP-P08 Profile/social/privacy | Profile, friends, activity, titles, blocks, privacy, settings | user/social/moderation routes | Profile graph with typed destinations; DataStore settings | Android permissions/settings navigation | Contract tests, block/privacy consistency, localization/accessibility |
| GP-P09 Notifications | FCM token actor, list/read/badge, route dispatcher | push-token and notification routes/Firebase | FCM service, channel strategy, permission education, route dispatcher, retry work | Android 13+ permission/channels and background restrictions | Token replacement/logout, tap routes, cold/warm starts, physical devices |
| GP-P10 Widgets | Four WidgetKit widgets from app-group snapshots | selected widget summary endpoints/client snapshots | Scope after core parity; Glance/AppWidget + WorkManager/data store | Size classes, refresh quotas, interaction rules | Host/device matrix, stale data, auth/logout, deep-link tests |
| GP-P11 Localization | ko/en/ja/zh-Hans resources | locale-aware AI/search fields | Android resources and locale-aware formatters | Locale identifiers and font metrics | Pseudolocale and four-locale content/layout checks |
| GP-Q01 Accessibility (proposed cross-platform quality requirement) | iOS readiness is unresolved; existing UIKit semantics are not an accepted product specification | Mostly client-side; server errors/media need accessible presentation data | TalkBack/content descriptions, scalable text, contrast, touch targets, reduced motion where relevant | Android semantics/focus and window behavior differ | Owner-accepted policy, TalkBack/VoiceOver, font scale, contrast and touch-target audit on both clients |

## Build variants and signing

Mirror behavior, not Xcode names: `debug` local development, `staging` internal/beta, and `release` production are initial candidates. Use distinct application IDs or suffixes where simultaneous install and server isolation are required. All environment hosts come from build configuration, never embedded secrets. Signing keys stay outside the repository and CI uses protected credentials. Exact flavors/build types must be decided with release ownership; avoid a flavor for every scheme historical artifact.

## Testing strategy

- Unit: serializers, mappers, validators, state reducers/ViewModels, auth refresh, route parsing, formatters.
- Contract: frozen backend fixtures and schema compatibility in CI.
- Integration: repositories with MockWebServer/test DB where appropriate; authenticated staging smoke as a separate gate.
- UI: Compose semantics tests for critical flows; screenshot tests for design-system states and locales.
- Device: OAuth, FCM, App Links, process death, offline/reconnect, background work, widgets, accessibility, low-memory/battery constraints.
- Release: signed internal bundle, Play pre-launch report, staged rollout monitoring, rollback/disable controls.

## CI/CD and Play release

Candidate CI stages: formatting/lint/static analysis; unit/contract tests; debug/staging assemble; instrumentation on managed emulator matrix; signed bundle only on protected release workflow; artifact provenance and dependency/security scanning. Providers and exact commands remain unresolved until the project exists.

Play Console preparation includes application ID ownership, privacy/data-safety declarations, content rating, store assets/localizations, tester tracks, signing ownership/Play App Signing decision, staged rollout, crash/ANR monitoring, and support/rollback process. These are deliverables, not assumptions.

## Foundation exit criteria

- Contract freeze and product parity matrix accepted.
- Minimum/target SDK and device support decided from evidence.
- Auth, environment, logging/redaction, navigation, design tokens, accessibility, and localization foundations tested.
- One thin vertical slice—public standard Search using frozen fixtures and live staging—passes unit, contract, UI, and device checks before parallel feature expansion. Authenticated AI Search remains deferred until the auth foundation contract is included.
- Module graph remains within the initial justified set; new modules require a documented boundary reason.
