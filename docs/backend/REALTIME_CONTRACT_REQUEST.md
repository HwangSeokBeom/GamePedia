# Backend Contract Request — Realtime Activity Channel

Status: **REQUEST / PROPOSAL — NOT IMPLEMENTED**

| Item | State |
| --- | --- |
| Current backend capability | **MISSING** — no WebSocket, SSE, or any push-stream endpoint exists on GamePediaCoreServer (verified against the dev branch; presence and activity feeds are REST-polled) |
| Proposed capability | **NOT IMPLEMENTED** — everything below is a client-side proposal awaiting backend review |
| iOS client state | Protocol boundary + deterministic mock only. Production provider is `UnavailableRealtimeClient` and `FeatureFlags.enableRealtimeActivity == false` in every environment. No remote URL, header, or payload shape has been guessed or implemented. |

## Why

The iOS 2.1 release ships a realtime foundation (`Core/Realtime`) so friend
activity can eventually update without polling. The client treats realtime
strictly as an **invalidation channel**: REST remains the source of truth and
every realtime signal at most triggers a REST reconciliation
(`GET /users/me/friends/activity`). Nothing user-visible depends on this
request being fulfilled — the app degrades to today's pure REST behavior.

## PROPOSED event envelope

PROPOSED — field names/semantics are open questions, not a committed contract:

```json
{
  "id": "evt_01H...",          // globally unique event id (client dedup key)
  "type": "friend_activity",   // namespaced event type
  "schemaVersion": 1,           // envelope version for forward compatibility
  "sequence": 42,               // per-session monotonically increasing
  "occurredAt": "2026-07-18T09:00:00Z",
  "payload": { }                // type-specific body; client treats as opaque hint
}
```

Client-side policy already implemented against this proposal (mock-verified
only): duplicate `id` applied once; `sequence` less than or equal to the last
applied value rejected; a sequence gap triggers REST reconciliation; unknown
`type` values are counted and ignored without error.

## Open questions for the backend team

1. **Transport**: WebSocket vs SSE? URL path? (The client has deliberately not
   guessed `/ws` or `/realtime`.)
2. **Authentication handshake**: how is the access token presented
   (header at upgrade, first-frame auth message, query param is assumed
   unacceptable)? What is the close behavior when the token expires mid-connection?
   Which `error.code` values can the handshake return (alignment with
   `TOKEN_EXPIRED` / `TOKEN_REVOKED` / `UNAUTHORIZED` from the auth contract)?
3. **Reconnect/resume**: is there a resume token or `Last-Event-ID`-style
   mechanism, or is every reconnect a fresh session requiring REST reconciliation?
4. **Sequence semantics**: is `sequence` per-connection, per-user-session, or
   global per user? What should the client do on server restart (sequence reset)?
5. **Sequence-gap policy**: server-side replay window vs client REST
   reconciliation (client currently assumes reconciliation only).
6. **Event retention**: how long are events retained for replay, if at all?
7. **REST reconciliation endpoint**: confirm `GET /users/me/friends/activity`
   (cursor-based) remains the authoritative reconciliation read.
8. **Push/WebSocket deduplication key**: FCM social pushes and realtime events
   need one logical identity. Proposal: reuse `UserNotification.dedupeKey` or
   the `UserActivityEvent` id as the envelope `id` so a client can suppress the
   duplicate channel.
9. **Authorization rules**: which activity is a user allowed to receive
   (friend privacy settings, blocks)? Server-side filtering assumed.
10. **Schema-version compatibility**: what does the server do when a client
    connects with an older supported `schemaVersion` (down-convert vs close)?
11. **Rate limits / connection limits**: max concurrent connections per user,
    reconnect rate limits, and the `error.code` the client should expect when
    throttled (stable codes only — clients never parse `error.message`).
12. **Privacy/logging**: confirm events contain no raw emails/tokens; iOS will
    log only event ids/types/sequences, never payloads.
13. **iOS/Android parity**: Android has a matching session foundation; the
    contract should be reviewed by both platforms before implementation.

## Requested deliverables

- A committed OpenAPI/AsyncAPI (or markdown) contract in
  `GamePediaCoreServer/docs` including transport, handshake, envelope, error
  codes, and limits.
- A staging endpoint for integration verification.

Until then the iOS remote realtime implementation stays **absent** and
production behavior stays **disabled by default**.
