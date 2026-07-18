# Backend contract request — Activity Center / live-service operations

Status: **REQUEST — nothing in this document is implemented server-side.**
Owner: iOS. Companion requests: `REALTIME_CONTRACT_REQUEST.md`,
`LIBRARY_SYNC_CONTRACT_REQUEST.md`.

The iOS 2.4 release ships a unified Activity Center composed purely from the
two committed REST contracts (`GET /users/me/notifications`,
`GET /users/me/friends/activity`). The client works today, but four gaps
force client-side workarounds that only the backend can remove.

## 1. Per-item read state

Today only `PATCH /users/me/notifications/read-all` exists. The client keeps
a local, account-scoped read watermark so unread state survives restart, but:

- read state is per-device, not per-account across devices;
- friend-activity items have no server read state at all.

Request:

- `PATCH /users/me/notifications/{id}/read`
- optional `PATCH /users/me/notifications/read` with `{ "ids": [...] }`
- read state included in the friend-activity feed items, or a unified
  activity resource (below).

## 2. Cross-channel dedupe key

One logical activity reaches the client as (a) an inbox notification, (b) a
friend-activity feed item, and (c) an FCM push — each with a different
object ID. The client currently derives a composite logical key
(canonical type + actor + game + review + comment) and collapses items whose
timestamps fall within 10 minutes. That heuristic cannot be exact.

Request (same as REALTIME_CONTRACT_REQUEST open question #8):

- a server-assigned `dedupeKey` present on the notification resource, the
  friend-activity item, and the push payload for the same logical event.

## 3. Followed-game updates and recommendation events

The 2.4 canonical model reserves event classes for followed-game updates
(release date changes, price drops, new reviews milestones) and
recommendation completion (`recommendation` kind is already routed from the
`library_curator` push). There is no REST resource that delivers these into
the inbox/feed.

Request:

- inbox notification types for followed-game updates with stable `type`
  codes (e.g. `followed_game_update`), `relatedGameId`, and the usual
  identifier fields;
- a notification emitted when a recommendation batch completes
  (`recommendation_ready`), carrying no free-form payload beyond display
  strings.

## 4. Remote kill-switch / feature availability config

2.4 introduces a client-side availability boundary
(`FeatureAvailabilityProviding`): every live-service consumer asks one
provider whether a capability is usable, and a local override can disable a
feature at runtime. There is **no remote implementation** — the client does
not fabricate one and does not claim server-controlled rollout.

Request:

- a small, cacheable config endpoint (e.g. `GET /client-config/ios`) with
  per-feature availability flags and stable reason codes;
- flags delivered as codes, never localized text;
- explicit TTL/cache semantics so the client can fail safe (last-known
  config, then build-time defaults).

## Non-goals

- No WebSocket/SSE requirements here (tracked in REALTIME_CONTRACT_REQUEST).
- No new mutation semantics (tracked in LIBRARY_SYNC_CONTRACT_REQUEST).

Until these land, the affected behaviors stay client-local and are labeled
IMPLEMENTED_BUT_RUNTIME_UNVERIFIED or PARTIAL in
`docs/IOS_CAPABILITY_EVIDENCE.md`.
