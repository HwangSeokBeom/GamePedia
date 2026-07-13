# GamePedia 2.0 Baseline

## Baseline method

Snapshot date: 2026-07-13. This baseline uses only repository evidence from the iOS and Core Server working trees. It excludes `.env*`, credentials, generated/build artifacts, logs, and untracked duplicate-suffixed backend files. “Confirmed” means a tracked file or current untracked operating document supports the statement; it does not mean production behavior was exercised.

## Product baseline

### User value and main flows

1. A guest launches into the four-tab shell and browses Home or Search.
2. The user opens a game detail, sees IGDB-derived metadata, favorite/review context, and optional AI review summary.
3. Restricted actions present authentication; email, Apple, and Google paths yield JWT-backed sessions.
4. An authenticated user favorites a game, sets library status, writes/edits/deletes a rating/review, and participates in review discussions.
5. The user can link Steam, sync owned/recent activity, manage social/privacy settings, friends, moderation, and notifications.
6. Push payloads and `gamepedia://` links route into notifications, games, reviews, profile, login, or recommendation experiences.
7. Widgets expose trending, recently viewed, current-user activity, and review prompts from app-group snapshots. Friend-activity snapshot infrastructure exists, but no friend-activity widget is registered.

### Information architecture

| Area | Current behavior | Evidence/status |
|---|---|---|
| Home | Highlights, popular/trending/recommended sections and filters | Confirmed in Home presentation/use cases and game endpoints |
| Search | Suggestions, canonical search, localized aliases, AI natural-language assist | Confirmed |
| Game detail | Metadata, favorite/review state, Steam fallback, AI review summary | Confirmed |
| Library | Owned, playing, recent, favorites/reviews, status, Steam and recommendations | Confirmed; canonical source paths aligned, deployment unverified |
| Profile | Account/profile image, reviews/comments, titles, friends/activity, privacy | Confirmed; canonical source paths aligned, deployment unverified |
| Reviews | Rating/content/spoiler, CRUD, likes, comments/replies/reactions/reporting | Confirmed |
| Notifications | Remote list/read state plus local comment-notification merge | Confirmed; reconciliation semantics unresolved |
| Settings | Appearance/language/build info, legal/support, privacy/account actions | Confirmed in profile/settings sources; production URLs not runtime-verified |

### Sources, localization, and accessibility

- IGDB/Twitch is the canonical game discovery/detail source behind Core Server.
- Steam supplies linked account/library/recent-play data through Core Server.
- PostgreSQL supplies user-generated and account data.
- Resources exist for Korean, English, Japanese, and Simplified Chinese.
- Accessibility APIs appear through UIKit controls, but no repository-wide VoiceOver, Dynamic Type, contrast, reduced-motion, or accessibility acceptance suite was found. Accessibility readiness is `UNRESOLVED`.

### Incomplete and fallback flows

- Guest mode continues when no refresh token exists or refresh fails.
- AI features degrade to rule-based, unavailable, or empty results.
- Steam detail/library flows contain unavailable/privacy/rate-limit fallbacks.
- Client-side translation uses Apple translation-host types; the README’s separate Translate Server statement conflicts with the backend README’s canonical-original-data statement.
- Several client endpoints have no exact registered server counterpart; see the contract document.

## iOS baseline

### Targets, schemes, and platform

- Targets: GamePedia app, GamePediaTests, GamePediaUITests, GamePediaWidgetExtension.
- Shared app schemes include GamePedia, GamePedia-Dev, GamePedia-DeviceDev, GamePedia-Staging, and GamePedia-Prod; widget schemes are also shared.
- Project settings show Swift 5.0 and iOS 17.0 for main app/test/widget configurations.
- Main application marketing version is configured as 2.0.0 in primary configurations. DeviceDev now retains 2.0.0/build 1 after an evidence-backed merge reconciliation; release version truth still requires build-settings/Fastlane verification before release.
- The four committed DeviceDev conflict regions in `project.pbxproj` were reconciled on 2026-07-13. Conflict scanning, `plutil`, and the Ruby Xcode project parser pass, and all expected targets are present. `xcodebuild` remains unverified because SwiftPM's nested sandbox and CoreSimulatorService are unavailable in the managed environment.

### UI and navigation

- UIKit is primary. SwiftUI is limited to WidgetKit and Apple Translation hosting surfaces.
- `SceneDelegate` creates `AppCoordinator`; it composes auth and four tab coordinators.
- The presentation style is feature-local unidirectional state: Intent, Mutation, Reducer, State, ViewModel, and UIKit controller/root view.
- Coordinator and dependency composition are pragmatic but centralized; `AppCoordinator` is a large cross-feature surface.

### Domain and data boundaries

- Domain contains repository protocols, use cases, entities, and recommendation/highlight services.
- Data contains repository implementations, remote/local data sources, DTOs/mappers, and the shared network client.
- Several screens or coordinators use `APIClient` or instantiate concrete dependencies directly; boundary consistency should improve incrementally.
- `APIClient` uses URLSession and `Endpoint.swift`; there is no generated client. The Core Server now has a formal but intentionally partial 17-operation OpenAPI gate.

### Persistence, auth, and concurrency

- Refresh token: Keychain. Access token: memory-only. Stable push device ID: Keychain-backed.
- UserDefaults: local settings, comment/moderation caches, and registration metadata.
- App group: widget snapshot transfer. No Core Data/SwiftData found.
- Combine is used heavily for MVI/auth; async/await, Tasks, actors, task groups, DispatchQueue, and MainActor are also present.
- APIClient maps auth failures but does not define a transport-wide synchronized refresh-and-retry policy. Android must not infer one.

### Dependencies and debt classification

| Classification | Finding | Evidence/rationale |
|---|---|---|
| Keep | Native UIKit/coordinator/domain-data layering | Broad implemented behavior and tests; rewrite has no evidence-based benefit |
| Keep | Keychain refresh token and memory-only access token | Appropriate trust boundary, subject to runtime checks |
| Improve | Hand-authored endpoint/DTO contract | Previously confirmed route drift is source-aligned for the gate subset; full coverage/deployment remain incomplete |
| Improve | Central dependency composition and direct APIClient bypasses | Maintainability/testability issue, not stylistic rewrite justification |
| Improve | Mixed concurrency cancellation/refresh rules | Multiple mechanisms with no single documented ownership policy |
| Improve | Production logging discipline | APIClient body previews and the full debug access-token logger were removed on 2026-07-13; runtime distribution-log inspection and broader log review remain |
| Improve | UI/accessibility coverage | UI test target is mostly template-level |
| Unresolved | Dependency obsolescence | Requires current upstream advisories; repository-only review cannot establish it |
| Unresolved | Signing/TestFlight health | Requires credentials, archive, upload, and install evidence |

### Tests and release

- Twenty-two unit-test files cover selected AI contracts, reviews/comments, widgets/deep links, FCM registration, home selection/coordinator, recommendation logic, backend fixtures, auth refresh races, and ordinary search state.
- UI tests contain only template/example/launch-performance coverage; real navigation/auth/library/profile flows are unverified.
- Fastlane includes build/release/versioning behavior; `bundle exec fastlane ios ci_build` is a repository-evidenced CI build lane.
- TestFlight, physical-device, OAuth, push, widgets, and Steam callbacks remain runtime-only.

## Backend baseline

### Runtime and modules

- Node.js >=20, Express 5, JavaScript, Prisma 6/PostgreSQL, JWT, bcrypt, Zod, Winston, Firebase Admin, Multer, Nodemailer.
- Optional Redis is only probed at startup in current code; no confirmed Redis-backed cache/session/job ownership exists.
- Route/module surfaces: auth, IGDB/game, favorites, library/Steam, reviews/comments, moderation, users/social/privacy/notifications/push, AI, and recommendation.
- Auth uses a legacy routes/controllers/services layout; other domains are mostly feature modules. This hybrid is a clarity issue, not proof that replacement is necessary.

### Authentication and authorization

- Email/password, Apple, Google, forgot/reset password, access/refresh issuance, rotation, logout/revocation, `/auth/me`, and account deletion are present.
- Protected routes use `Authorization: Bearer`, validate an access-token type, and reload an ACTIVE user.
- Ownership/authorization checks exist in service code for user-owned mutations; exhaustive authorization verification was not run.

### Prisma/PostgreSQL ownership

Confirmed models include users, refresh/password-reset tokens, reviews/likes/comments/reactions/reports, favorites, friends/requests, social accounts, user titles/library, Steam-IGDB mapping, moderation, search queries, notifications/push tokens, activity/presence/privacy, and AI logs/usage. Migrations span March–May 2026. User-owned untracked duplicate migration files must not be applied or deleted without a separate forensic task.

### External APIs, caching, and jobs

- IGDB/Twitch and Steam integrations are confirmed.
- Apple/Google identity, Firebase Admin push, mail, and configurable OpenAI-compatible LLM providers are confirmed.
- IGDB/search and AI services include in-memory caches/fallbacks; caches are process-local and lost on restart.
- No durable background-job queue or scheduler was found. Notification publishing happens in request/service flows. Background-job requirements are `UNRESOLVED`.

### Reliability, security, and operations

- Success/error envelopes and centralized error sanitization exist.
- Winston logs to console/files; no confirmed centralized aggregation, trace propagation, metrics backend, alerting, or SLOs.
- Rate limiting is in-memory and confirmed only on selected push endpoints; global/auth/AI abuse controls are incomplete or `UNRESOLVED`.
- `app.disable('x-powered-by')` and body limits exist. No Helmet/CORS middleware was found; whether reverse proxy controls compensate is `UNRESOLVED`.
- A health endpoint exposes push initialization state. Database/external dependency readiness is not part of the response.

### Deployment, migrations, backups, and monitoring

- GitHub workflow validates on Ubuntu, then can deploy main/staging to separate self-hosted EC2 clones.
- Repository docs also state actual deployment is currently manual and runner service inactive. Current production automation mode is therefore `UNRESOLVED` pending operational evidence.
- Deployment runs `npm ci`, environment validation, Prisma generate/migrate deploy, PM2 restart/start, cwd verification, and `pm2 save`.
- Migration rollback is fix-forward or restore-based. No automated backup schedule, restore drill evidence, RPO/RTO, or database monitoring configuration was found.

### Test/API documentation gaps

- Node tests cover AI, IGDB 429 fallback, Firebase configuration, push tokens, and push service.
- Auth, review, favorite, library, social, moderation, migration, and deployment integration coverage is incomplete.
- README and route/validator code remain necessary for operations outside the committed 17-operation OpenAPI gate. No generated client or complete API contract exists.
- In the 2026-07-12 managed sandbox, 14 tracked non-listening tests passed. Full `npm test` and an explicit tracked suite could not exercise HTTP route tests because the restricted environment did not provide a listening server address; default discovery also included the untracked duplicate tests. This is partial test evidence, not a backend verification result.

## Cross-repository baseline conclusion

GamePedia 2.0 is a broad, repository-evidenced native iOS/server implementation with useful layering and substantial source-level feature depth. The iOS project now parses structurally, but compilation remains unverified because the managed environment blocks SwiftPM/CoreSimulator execution; backend HTTP tests were likewise sandbox-blocked, and runtime/external systems were not exercised. Its largest Android-readiness gap is not UIKit age; it is that the committed machine-checkable gate covers only 17 of roughly 133 operations, while matching route implementations and operational/end-to-end behavior remain deployment-unverified. Modernization should preserve evidence-backed native architecture, expand the contract by accepted vertical slice, close security/reliability gaps, and then build Android in independently releasable parity slices.
