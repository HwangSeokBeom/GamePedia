# Cross-Platform Contract Baseline

## Authority and status

The Core Server now contains `openapi/cross-platform.openapi.json`, a committed 2.0 gate subset with 12 paths, 17 operations, and 18 schemas. It is explicitly not the complete backend API: static inspection finds roughly 133 registered operations. This document compares iOS `Endpoint.swift` and `AuthEndpoint.swift`, that gate subset, Express route registration, and server validators as of 2026-07-13. Registered server behavior is transport evidence; iOS behavior is consumer evidence; the partial schema is a compatibility gate. None alone establishes deployed production behavior.

Search, Home, Detail, reviews/discussions, most library/social/notification operations, moderation, and AI remain outside the machine-readable subset. Android implementation for those areas stays blocked until their accepted operations and fixtures are executable.

Status values:

- **Matched**: method/path/auth intent align at baseline level.
- **Drift**: exact method/path has no matching registered route or uses a different name.
- **Server-only**: implemented but no confirmed iOS Endpoint consumer.
- **Unresolved**: shape/semantics require tests or runtime evidence.

## Protocol conventions

| Concern | Confirmed current behavior | Required freeze decision |
|---|---|---|
| Base URL | Environment-selected Core Server root; most routes unversioned, AI uses `/api/v1` | Versioning and compatibility window |
| Media type | JSON for normal requests; multipart profile image upload | Size/type/error contract |
| Auth | `Authorization: Bearer <access>`; refresh token in body; server validates ACTIVE user | Refresh concurrency, retry, expiry, device/session policy |
| Success | `{ "success": true, "data": ... }` | Whether all endpoints must conform |
| Error | `{ "success": false, "error": { "code", "message", "details"? } }` | Stable codes, localization ownership, retry metadata |
| Naming | Server snake_case; iOS decoder converts keys to camelCase | Android serialization rule and exceptions |
| IDs | User/review/comment IDs are UUID strings; game IDs are frequently string in user data and Int in IGDB client models | Canonical game-ID wire type |
| Dates | Prisma/JSON serializes ISO timestamps; iOS formatters accept multiple forms in utility code | Exact RFC 3339 format, UTC/offset policy, fractional seconds |
| Pagination | Page/limit on some lists; cursor/limit on activity/comments; some lists unpaged | Per-endpoint model, ordering, next/end semantics |
| Locale | Client resources: ko/en/ja/zh-Hans; AI accepts locale in selected payloads | BCP-47 values, fallback, server-vs-client copy ownership |
| Images | IGDB/Steam/external URLs and server `/uploads` profile media | HTTPS, absolute URL, expiry, placeholders, resizing |

## iOS-consumed endpoint inventory

### Authentication

All are registered and broadly matched: `POST /auth/signup`, `/login`, `/forgot-password`, `/reset-password`, `/apple`, `/google`, `/refresh`, `/logout`; `GET /auth/me`; `DELETE /auth/me`. Exact password constraints, token TTLs, rotation race behavior, social-provider error mapping, and account-deletion cascade/retention require contract tests.

### Games and AI

Matched: `GET /games/highlights`, `/games/popular`, `/games/recommended`, `/games/search`, `/games/:id`; authenticated AI `POST /api/v1/ai/game-recommendations`, `/library-curator`, `/search-assist`; authenticated `GET /api/v1/ai/games/:gameId/review-summary`.

Server-only or not clearly consumed: `GET /games/suggestions`, `GET /games/detail`. Home filter parameters are `limit`, `platform`, `category`, `gameMode`; search uses `q` and `limit`. The iOS search `genre` argument is currently ignored.

### Reviews, comments, and moderation

Matched core routes: create/list/update/delete review; like/unlike; list/create/update/delete comments and replies; reactions; reports; current-user reviews/comments; `POST /reports`; block/unblock routes.

The server exposes multiple legacy aliases for comment updates, deletes, likes/reactions, and reports. Android must not implement all aliases. Freeze one canonical family and publish deprecation behavior.

Review pagination/sort, spoiler visibility, deleted-comment tombstones, nested reply depth, optimistic like/reaction conflict handling, blocked-user filtering, and duplicate-submission idempotency remain unresolved.

### Favorites and library

Matched favorites: `POST /favorites`, `DELETE /favorites/:gameId`, `GET /users/me/favorites`, `GET /games/:gameId/favorite-status`.

Matched library: `GET /users/me/library`, `/owned`, `/playing`, `/recently-played`; `POST /users/me/library/status`; Steam link POST/DELETE and owned sync POST; friend/playtime recommendation endpoints.

| iOS expectation | Registered server | Status/action |
|---|---|---|
| `GET /users/me/steam` | Exact route exists in the dirty server working tree and OpenAPI gate | **Matched in source; deployment unverified** |
| `GET /users/me/recently-played?limit=` | Same canonical profile route; old `/recent-plays` is deprecated compatibility | **Matched in source; deployment unverified** |
| `POST /users/me/library/steam/link` | Same | Matched; response link/callback semantics need fixture |
| Steam callback custom scheme | Server `GET /library/steam/callback`, iOS Steam callback parser | Unresolved redirect/deep-link error/cancel contract |

### Profile, friends, privacy, and notifications

Matched broad surfaces: current profile, profile update/image, user search, friends/count/activity, requests, blocks, titles, other-user profile/presence/library/review/taste views, notifications/read/read-all, and push-token create/update/delete.

Previously confirmed drift candidates are now aligned in the iOS/server working trees and represented by the OpenAPI gate, but the matching server implementations are not branch-stable/deployment-verified:

| iOS expectation | Registered server | Status/action |
|---|---|---|
| `GET/PATCH /users/me/privacy` | Same canonical route; `/privacy-settings` is deprecated compatibility | **Matched in source; deployment unverified** |
| `GET /users/:id/friend-recommendations` | Same canonical route plus current-user compatibility form | **Matched in source; deployment unverified** |
| `POST /users/me/friends/steam/import` | Same canonical discovery-only import route | **Matched in source; deployment unverified** |
| `GET /users/me/recently-played` | Same canonical route; `/recent-plays` is deprecated compatibility | **Matched in source; deployment unverified** |

Duplicate server aliases exist for `/users/me` vs `/users/me/profile`, push token PUT vs POST, and profile mutations under `/users/me` vs `/auth/me`. Freeze one canonical set.

## Authentication contract proposal

Before Android work, accept and test the following without changing behavior accidentally:

1. Access token bearer format and expiry; refresh token rotation and revocation.
2. One refresh attempt shared by concurrent failed requests; queued requests replay at most once.
3. Refresh failure clears local session and returns a typed auth outcome; offline failure does not silently delete a valid refresh token unless specified.
4. Refresh token stored in iOS Keychain and Android encrypted credential storage; access token held in memory unless a security review approves otherwise.
5. Logout attempts server revocation and push-token deletion, then clears local credentials even when network cleanup fails; document retry consequences.
6. Account deletion cascade, retained audit/moderation data, social-token revocation, and user messaging remain `UNRESOLVED` until owner/legal decisions.

## Request/response model freeze

Create fixtures from server validators/mappers rather than copying Swift types. Minimum shared model families:

- Auth session/user/error
- Game summary/detail and source provenance/fallback metadata
- Review/comment/reaction/moderation
- Favorite/library status and Steam link/sync
- Profile/friend/activity/privacy/presence/title
- Notification page/push token/push route payload
- AI recommendation/search/curator/review summary including fallback and quota metadata

For every field, record required/nullable/default, range/length/enum, ID type, date type, locale behavior, and compatibility rule. Unknown fields should be ignored by clients unless security-sensitive; removal/type changes require a version or negotiated compatibility period.

## Push-token contract

Confirmed iOS request data includes token, `platform: "ios"`, stable device ID, app version, build number, and environment. Android should use `platform: "android"` only after the server validator explicitly supports it. Define token replacement, per-user/device uniqueness, logout deletion, invalid-token deactivation, environment isolation, and background retry. Never log raw tokens.

## Push and deep-link routing

Current iOS custom scheme supports:

- `gamepedia://game/<gameId>`
- `gamepedia://trending`
- `gamepedia://profile`
- `gamepedia://login`
- `gamepedia://review/<reviewId>`
- `gamepedia://review/new/<gameId>`

Current push destination families include notifications, game detail, review/thread, friend requests, profile, and library curator. Payload keys accept several aliases (`type`, `activityType`, `eventType`, etc.), which is tolerant but ambiguous. Freeze canonical keys: schema version, route, notification ID, optional game/review/comment/user IDs, source, and badge. Android App Links and notification intents may differ, but route outcomes must match.

## Platform-specific behavior not automatically shared

- UIKit tab/coordinator indices, modal presentation, and MVI type names
- Apple Translation host UI and Sign in with Apple presentation
- WidgetKit timelines/app-group snapshots versus Android widgets/DataStore/WorkManager
- iOS Keychain API and background execution constraints
- Google Sign-In SDK callback mechanics
- TestFlight environment behavior and custom scheme routing

These are implementation details. The shared contract is the user-visible outcome and server interaction.

## Contract-freeze exit criteria

- Every iOS endpoint classified and every Drift item resolved with compatibility/deprecation decision.
- Machine-readable API description or executable schema/fixture suite committed in the backend.
- Representative success/error/pagination/date/media fixtures decode in iOS and planned Android serializers.
- Auth refresh, push/deep-link, Steam callback, and account-deletion state machines documented.
- Staging smoke suite passes for the parity set; production remains separately authorized.
