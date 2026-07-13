# Verification

`UNRESOLVED` is not executable guidance. Record command, environment, date, and observed outcome. Lower-level evidence never proves a higher level.

| Level | Confirmed command or procedure | Environment / limits |
|---|---|---|
| Syntax / project parse | `xcodebuild -project GamePedia.xcodeproj -list` | Local Xcode; does not compile |
| Format | `UNRESOLVED` | No formatter command/config confirmed |
| Lint / static | `UNRESOLVED` | No SwiftLint or canonical static command confirmed |
| Type checking / build | `xcodebuild -project GamePedia.xcodeproj -scheme GamePedia-Dev -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` | Candidate; package resolution and installed SDK required |
| Unit tests | `xcodebuild -project GamePedia.xcodeproj -scheme GamePedia-Dev -destination 'platform=iOS Simulator,name=<installed simulator>' CODE_SIGNING_ALLOWED=NO test` | Choose an actually installed simulator |
| UI tests | Same test invocation when scheme includes `GamePediaUITests` | Launch tests do not prove full UX |
| Integration | Core Server staging contract smoke suite: `UNRESOLVED` | Must not target production accidentally |
| Runtime | Launch Dev/Staging, verify environment badge/host, guest and restored sessions, Home/Search/Detail/Library/Profile | Requires server and configuration |
| UI / device | Physical-device OAuth, Keychain restore, push registration/tap, widgets/app group, Steam callback, deep links, localization, VoiceOver/Dynamic Type | Simulator is insufficient for several checks |
| Release | Fastlane release lanes, archive, upload, TestFlight install | Requires signing/App Store Connect credentials; see `fastlane/Fastfile` |
| Production / external | IGDB/Steam/social login/FCM/LLM/API monitoring | Owner-authorized external verification only |

## Required contract verification

1. Compare registered Express routes to every `Endpoint.swift` path/method/auth flag.
2. Validate representative request and response fixtures with both server schemas and client decoders.
3. Confirm error envelope, date formats/time zones, IDs, image URLs, pagination, push payloads, and deep-link targets.
4. Run authenticated staging smoke tests for every Android parity feature before freezing compatibility.

## Runtime-only gates

- Guest-to-auth transition and token refresh rotation
- Account deletion/logout and push-token cleanup
- Apple/Google OAuth callbacks
- Steam browser callback and privacy/fallback paths
- Notification delivery, badge/read state, and route destinations
- Widget timelines and app-group snapshot refresh
- Environment/scheme routing on simulator and physical device
- Four supported localizations and accessibility checks

Final verification belongs to a context separate from Builder and Challenger. External-model reviews do not substitute for execution evidence.

## Evidence from 2026-07-12 planning run

- `xcodebuild -project GamePedia.xcodeproj -list`: **failed** (exit 74). Xcode reported a damaged/unreadable project. Independent inspection found tracked source-control conflict markers in `project.pbxproj` at lines near 946, 1004, 1021, and 1039. CoreSimulator/log sandbox errors also occurred, but the conflict markers independently block project parsing.
- No iOS build, unit test, UI test, runtime, device, archive, TestFlight, or external integration verification was possible after that parse failure.
- Documentation presence/content command: `for f in AGENTS.md CLAUDE.md docs/PRODUCT.md docs/ARCHITECTURE.md docs/DECISIONS.md docs/VERIFICATION.md docs/TASKS.md docs/GAMEPEDIA_2_BASELINE.md docs/CROSS_PLATFORM_CONTRACT.md docs/ANDROID_NATIVE_PLAN.md docs/SERVICE_MODERNIZATION_OPTIONS.md docs/GAMEPEDIA_ROADMAP.md docs/RISK_REGISTER.md; do test -s "$f" || exit 1; done` — **passed** (exit 0). Trailing-whitespace scan `rg -n '[[:blank:]]+$' AGENTS.md CLAUDE.md docs/*.md` returned no matches. No Markdown formatter/linter is configured.
- Core Server `npm test`: **failed** in the managed sandbox. The default discovery included user-owned untracked duplicate `* 2.js` tests; HTTP route tests then failed because their ephemeral test server had no listening address in the restricted environment. A tracked-test-only retry produced the same route-test limitation, so those results are not treated as product failures.
- Core Server non-listening tracked subset command: `node --test test/ai/tag-normalizer.test.js test/firebase-admin.test.js test/igdb-detail.test.js test/push-token.service.test.js test/push.service.test.js` — **passed** (exit 0; 14 passed, 0 failed). This does not verify route registration, database integration, runtime, deployment, or external providers.

## Evidence from 2026-07-13 execution run

- Conflict scan `rg -n '^(<<<<<<<|=======|>>>>>>>)' GamePedia.xcodeproj/project.pbxproj` returned no matches (exit 1, expected for a clean scan). The four committed DeviceDev conflict regions were reconciled by retaining the additive analyzer/string-catalog settings from the dev merge parent and the newer `MARKETING_VERSION = 2.0.0` / `CURRENT_PROJECT_VERSION = 1` values from the 2.0 parent. No PBX objects, UUIDs, file references, or build phases were involved.
- `plutil -lint GamePedia.xcodeproj/project.pbxproj` passed (exit 0). Ruby `Xcodeproj::Project.open` passed and discovered `GamePedia`, `GamePediaTests`, `GamePediaUITests`, and `GamePediaWidgetExtension` (exit 0). This establishes syntax/project-structure parsing independently of package resolution.
- `xcrun swiftc -frontend -parse` across app, widget, unit-test, and UI-test Swift sources passed (exit 0). This is syntax evidence only, not type checking or a build.
- `xcodebuild -project GamePedia.xcodeproj -list`, `-showBuildSettings`, `-resolvePackageDependencies`, and the generic iOS Simulator build candidate all reached Swift Package resolution but failed (exit 74). Redirecting HOME/module/package/derived caches to writable `/tmp` paths and reusing the complete local SourcePackages checkout still failed because this managed environment prohibits SwiftPM's nested `sandbox-exec`. `xcrun simctl list devices available` failed (exit 1) because CoreSimulatorService is unavailable, so unit/UI tests had no valid installed destination and were not run. No compile, unit, UI, simulator runtime, device, or external verification is claimed.
- Sensitive-log static scans found no remaining APIClient body-preview helpers/labels, full/partial token values, raw translation text, Steam ID/auth URL, selected-title values, or raw game/friend-search terms in the reviewed paths after hardening. Full-project Swift parsing passed (exit 0). Runtime/distribution-log inspection and a broader privacy-aware logging policy remain unverified.
- Core Server read-only checks excluded all duplicate-suffixed user files: `node --check` passed for 112 canonical JavaScript files; `npx prisma validate` passed; explicit canonical tests ran 77 tests with 61 passing and 16 HTTP-listening failures caused by the sandbox returning no server address. HTTP, database, deployment, and external-provider runtime remain unverified.
- `git diff --check` passed (exit 0).

## Evidence from 2026-07-13 dev synchronization and 2.0+ continuation

- Branch synchronization was reproduced in an isolated writable clone because the managed filesystem cannot write the owner repository. Local `dev` fast-forwarded from `e896f650f00f4dde660dd2f0eb6a3dcd08c08726` to `main` at `53e42f8cccb9e73c0623bef39f01b776a1417ec0`; `git rev-list --left-right --count dev...local-source/main` returned `0 0`. No history rewriting or conflict resolution was required. `git fetch --prune origin` failed before updating refs because DNS could not resolve `github.com`.
- Current Core Server working-tree OpenAPI declares canonical `GET /users/me/recently-played`, `GET/PATCH /users/me/privacy`, `GET /users/me/steam`, `POST /users/me/friends/steam/import`, `GET /users/{userId}/friend-recommendations`, refresh rotation, and push-token operations. The iOS endpoint factories use the canonical recent-play/privacy paths. Contract-bearing canonical, alias, and push-semantic backend changes remain uncommitted; their exact promotion set requires a method/path comparison across all 17 OpenAPI operations.
- Client contract changes add canonical privacy request keys and response aliases, the canonical recent-play `games` array, required Steam status/import booleans, a shared ISO-8601/fractional-seconds/Unix-timestamp decoder, decoded Steam-import envelopes, and tests for representative fixtures. Refresh rotation now uses a replaying single in-flight request so concurrent callers do not submit the same rotating refresh token twice. Refresh commit and logout/account-deletion invalidation are ordered by one generation-aware lock; deterministic barrier tests cover a decoded refresh paused immediately before persistence, although those XCTest cases could not execute in the managed environment.
- App and widget build settings now agree on `MARKETING_VERSION = 2.0.0`, `CURRENT_PROJECT_VERSION = 1`, and iOS 17 across Debug, DeviceDev, Staging, and Release. Ruby Xcodeproj inspection confirmed the existing bundle IDs, entitlements, and configuration names were preserved.
- Conflict scan, `plutil -lint`, Ruby Xcodeproj structural parsing, `xcrun swiftc -frontend -parse` for all app/widget/unit/UI Swift files, targeted `swiftc -typecheck` for `APIJSONCoding.swift`, reviewed sensitive-log scans, and `git diff --check` passed.
- `xcodebuild -project GamePedia.xcodeproj -list ...` failed with exit 74 while resolving newly required Firebase transitive packages. The existing local SourcePackages cache does not contain those repositories; the managed environment cannot write the owner cache or resolve GitHub over DNS. CoreSimulatorService is also unavailable. Therefore package resolution, full type checking, simulator build, XCTest, UI tests, runtime, device, and external-provider verification remain unverified.

## Evidence from 2026-07-13 Trustworthy Search slice

- Full-project Swift syntax: `rg --files GamePedia GamePediaWidgetExtension GamePediaTests GamePediaUITests -g '*.swift' -0 | xargs -0 xcrun swiftc -frontend -parse` passed (exit 0), including the new SearchViewModel tests. This is syntax evidence only.
- Targeted Search core type checking passed with temporary minimal stubs for existing transport/localization symbols: the actual `Game`, query policy, state, intent, mutation, reducer, and `SearchViewModel` sources type-checked in Swift 5 mode. This does not type-check UIKit rendering, the XCTest file, or the complete app module and is not a substitute for the Xcode build.
- Project/resource structure: `plutil -lint` passed for `project.pbxproj`, both app plists, the widget plist, and all four changed localization files. Ruby `Xcodeproj::Project.open` passed and found the app, unit-test, UI-test, and widget targets.
- Static hygiene: conflict scan returned no matches; the changed Search tree contains no `print` interpolation of raw `query`; `git diff --check` passed; required post-2.0 roadmap/parity/risk/task/verification documents are non-empty.
- `xcodebuild -project GamePedia.xcodeproj -scheme GamePedia-Dev -list -derivedDataPath /tmp/GamePediaDerivedData` with temporary HOME/module-cache variables failed (exit 74) at Swift Package resolution. Xcode still attempted forbidden writes under the owner SwiftPM manifest cache; CoreSimulatorService was unavailable. No build or test target began.
- Six focused `SearchViewModelTests` were added for late superseded responses, failure/retry recovery, clear-before-debounce cancellation, genre-change request deduplication, presentation-state separation, and canonical genre identity. They did not execute because package resolution/test destination prerequisites failed.
- No simulator runtime, UI, VoiceOver, Dynamic Type, device, staging, backend database/HTTP, Android, provider, migration, deployment, or production verification was performed.

## Evidence from 2026-07-13 post-2.0 ecosystem audit

- iOS static checks passed: conflict-marker scan, `plutil -lint` for the Xcode project/app/widget plists and four localization files, full app/widget/unit/UI Swift frontend parse, Ruby Xcodeproj target parsing, required-document presence, trailing-whitespace scan, and `git diff --check`.
- `xcodebuild -project GamePedia.xcodeproj -list -clonedSourcePackagesDirPath /tmp/GamePediaSourcePackages` failed before listing targets because the incomplete temporary package cache required GitHub clones and DNS/network access was unavailable. CoreSimulatorService was also unavailable.
- The explicit generic Simulator build with `-disableAutomaticPackageResolution` and signing disabled failed with exit 74 during the same unresolved Swift package graph; compilation did not start. XCTest, UI tests, and simulator runtime were consequently not run.
- Android discovery found `/Users/hwangseokbeom/Documents/GitHub/GamePedia_AOS` exists but contains zero entries and is not a Git/Gradle project. Workspace searches found no GamePedia `AndroidManifest.xml`, Gradle wrapper/settings, Kotlin source, or Android tests. No Android build/lint/test command exists to run.
- Local Android host inspection found JDK 17.0.19, Android Studio 2025.3, SDK platform `android-36.1`, and Build Tools 36.0.0/36.1.0/37.0.0. No project wrapper or reproducible AGP/Kotlin/Compose/CI toolchain is defined; this is environment discovery, not a build.
- Independent OpenAPI counting found version 3.1.0, 12 paths, 17 HTTP operations, and 18 schemas. The gate is intentionally partial; Search/Home/Detail/reviews and most parity APIs are absent.
- Core Server canonical `node --check` passed; `npx prisma validate` passed with Prisma 6.19.2; backend `git diff --check` passed. A selected non-socket suite passed 35/35.
- Backend `npm test` observed 109 tests: 88 passed, 18 failed, and 3 skipped. All 18 failures occurred when the managed sandbox denied HTTP listener creation with `EPERM`; PostgreSQL refresh/push concurrency tests were skipped without an isolated database. These results do not verify HTTP route behavior.
- Backend clean-checkout reproducibility is independently blocked because tracked `package.json` invokes untracked `scripts/test/run-canonical-tests.js`. The server worktree is dirty on `main`, contrary to the request's `dev`-only mutation rule, so no backend files were changed.
- No database migration, live HTTP server, authenticated staging, IGDB, Steam, LLM, Firebase, simulator/device, Play, deployment, or production check was performed.
- Challenger logging review found the narrow Search/token/body scans are not a global security gate: raw stable identifiers and uncontrolled error descriptions remain in client/server logging sinks. No full-repository sentinel runtime, distribution-build, or staging sink verification was performed; this is an unresolved High release blocker.
- Controller inventory command `rg --files GamePedia -g '*ViewController.swift'` returned 37 files: 36 concrete controllers and one generic `BaseViewController`.
