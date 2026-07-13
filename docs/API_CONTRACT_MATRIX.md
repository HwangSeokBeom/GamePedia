# API Contract Matrix

## Authority and classification

The Core Server route implementation is the runtime source of truth; the tracked OpenAPI file is an executable compatibility gate for only a subset. iOS endpoints/DTOs are consumers, not contract authority. Production deployment was not queried.

Status values:

- **OpenAPI-gated**: represented by the tracked 12-path/17-operation OpenAPI subset and source route.
- **Source-matched**: iOS method/path has a registered server implementation, but the operation is outside that subset.
- **Client-local**: iOS does not use the server implementation for the behavior.
- **Unresolved**: exact shape/semantics or deployment compatibility is not frozen.

## Protocol-wide contract

| Concern | Current evidence | Required freeze |
|---|---|---|
| Base/version | Core Server root; most routes unversioned; AI under `/api/v1` | Compatibility/deprecation window and versioning policy |
| Authentication | Bearer access token; refresh token in JSON body; ACTIVE user validation | One refresh replay, expiry/revocation, offline and device/session semantics |
| Success envelope | Generally `{ success: true, data: ... }` | Per-operation required data and empty-success rules |
| Error envelope | Generally `{ success: false, error: { code, message, details? } }` | Stable codes, retry metadata, localization ownership |
| Naming | Server JSON commonly snake_case; shared iOS decoder converts to camelCase with DTO exceptions | Android serialization annotations and canonical exceptions |
| IDs | User/review/comment UUID strings; IGDB game IDs often numeric while user-state game IDs may be strings | One field-by-field wire type; no lossy client assumptions |
| Dates | ISO/RFC-3339-like timestamps; iOS shared decoder also accepts fractional seconds and Unix values | UTC/offset/fractional precision and nullable/absent semantics |
| Pagination | Mixed page/limit, cursor, limit-only, and unpaged lists | Ordering, maximums, next/end semantics for each list |
| Nullability | DTOs contain tolerant aliases/defaults in several flows | Required vs nullable vs omitted for every frozen schema |
| Privacy/logging | Client changes redact raw query/token/body data; backend cleanup is incomplete | No access/refresh/authorization/FCM/email/Steam ID/raw query/AI prompt/provider body logging; retention cleanup |

## iOS-consumed operation families

| Feature | Operations consumed by iOS | Auth | Request/query | Response/pagination/date/nullability | Contract status |
|---|---|---|---|---|---|
| Email/social auth | `POST /auth/signup`, `/login`, `/forgot-password`, `/reset-password`, `/apple`, `/google`, `/refresh`, `/logout`; `GET/DELETE /auth/me`; profile mutations under `/auth/me` | Mixed; bearer for me/logout/delete, refresh token body for rotation | Auth/profile DTOs; multipart image upload | Session/user/error envelopes; token expiry/rotation/provider errors need full freeze | Refresh OpenAPI-gated; remainder source-matched/unresolved |
| Home | `GET /games/highlights`, `/popular`, `/recommended` | Public | `limit`, optional `platform`, `category`, `gameMode` | Game arrays; no accepted module-level partial/freshness model | Source-matched; outside OpenAPI |
| Search | `GET /games/search`; server also exposes `GET /games/suggestions` | Public | Search: `q` length 1–100 and `limit` 1–30. Suggestions: `q` and `limit` 1–8. iOS `genre` argument intentionally ignored | Search returns `query`, equivalent `games`/`results`, `suggestions`, and original/normalized/effective query metadata; aliases, compatibility lifetime and degraded/error metadata remain unfrozen | Source-matched; outside OpenAPI; selected release blocker |
| Game detail | `GET /games/{id}` | Public | Numeric game ID | Game detail with provider/Steam fallback; media/nullability unresolved | Source-matched; outside OpenAPI |
| AI | `POST /api/v1/ai/game-recommendations`, `/library-curator`, `/search-assist`; `GET /api/v1/ai/games/{id}/review-summary` | Bearer | Validated prompt/context DTOs; AI Search schema currently permits limit up to 100 while behavior clamps to 5–20 | Result/fallback/quota/cache metadata; server-side output validation required; accepted limit must be made consistent | Source-matched; outside cross-platform OpenAPI |
| Reviews | `POST /reviews`; `GET /games/{id}/reviews`; `PATCH/DELETE /reviews/{id}`; `POST/DELETE /reviews/{id}/like`; `GET /users/me/reviews` | Bearer in current iOS, including list | Review DTOs and optional sort | Ordering/pagination/spoiler/like consistency/date rules incomplete | Source-matched; outside OpenAPI |
| Discussions/moderation | Server exposes comment/reply/reaction/report/block operations | Bearer for mutations | IDs, body, reaction/report types | Cursor/page, tombstone, depth, idempotency and blocked-user semantics unresolved | **Client-local on iOS** despite server routes; not parity-ready |
| Favorites | `POST /favorites`; `DELETE /favorites/{gameId}`; `GET /users/me/favorites`; `GET /games/{gameId}/favorite-status` | Bearer | Game ID, optional sort | Lists/status; ID and pagination rules need freeze | Source-matched; outside OpenAPI |
| Library | `GET /users/me/library`, `/owned`, `/playing`, `/recently-played`; `POST /users/me/library/status` | Bearer | Optional sort; status DTO | Mixed lists/summaries; source IDs, canonical IDs, dates/nulls need fixtures | Source-matched; outside OpenAPI |
| Steam | `GET /users/me/steam`; `POST/DELETE /users/me/library/steam/link`; `POST .../sync-owned`; recommendation endpoints; callback is server/browser driven | Bearer except callback/provider redirect boundary | Link/sync actions; callback state/redirect | Required status booleans plus nullable IDs/profile/dates; provider errors/freshness | Status is OpenAPI-gated; most source-matched/unresolved |
| Profile/social | `GET /users/me`, `/users/search`, friend requests/friends/activity/recommendations/profile; block; privacy; Steam-friend import | Bearer | Keyword, IDs, cursor, privacy DTO | Mixed arrays/cursors; privacy keys and selected aliases fixture-tested | Selected privacy/recent/import/recommendation OpenAPI-gated; remainder source-matched |
| Notifications | `GET /users/me/notifications`; `PATCH .../read-all`; `PUT/DELETE /users/me/push-token` | Bearer | Page/limit; push token/device/app/build/environment/platform | Notification page/meta, nullable relation IDs, read/created dates; push replacement/deletion semantics | Push token OpenAPI-gated; list/read source-matched |

## Partial OpenAPI gate

The tracked OpenAPI 3.1 gate has 12 paths, 17 operations, and 18 schemas. It covers health, refresh, selected current-user/profile/privacy/recent-play/Steam/friend-recommendation operations, and push-token registration/deletion. It accepts `platform = ios | android`. It does **not** cover Home, Search, Game Detail, reviews/discussions, most library/social/notification operations, moderation, or AI. Those areas cannot be treated as Android-ready.

## Trustworthy Search contract increment

Before Android Search implementation, add and test:

| Item | Required decision |
|---|---|
| Operation | Canonical `GET /games/search` and `GET /games/suggestions` paths, operation IDs, auth/public behavior |
| Query | `q` normalization and length bounds; `limit` default/max; accepted filters/sort; locale/BCP-47 behavior |
| Success | Required game summary fields, canonical ID types, localized/original title behavior, empty array semantics, cache/provider metadata |
| Failure | Stable validation, rate-limit, provider-unavailable, timeout, and internal codes with retryability metadata |
| Pagination | Explicitly declare limit-only/no-pagination or define cursor/page semantics and ordering |
| Dates/media | Exact timestamp format and absolute HTTPS image URL/null/placeholder behavior |
| Privacy | No raw query in application/provider logs; accepted hashed/aggregated analytics and retention policy only |
| Compatibility tests | Server schema and real HTTP fixtures; iOS decoder tests; future Android serializer tests; staging smoke |

## Release blockers

1. Core Server is currently on dirty `main`; the requested Git policy requires an owner-safe `dev` workflow before mutation.
2. Several canonical source changes are uncommitted/deployment-unverified.
3. Search is outside the executable OpenAPI subset.
4. Android identity, SDK, signing, environment, and first-slice decisions remain unresolved.
5. No authenticated staging, database, provider, device, or production compatibility run has been observed.
