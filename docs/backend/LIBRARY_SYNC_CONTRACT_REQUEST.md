# Backend Contract Request — Library Sync Idempotency and Conflict Semantics

Status: **NOT IMPLEMENTED on GamePediaCoreServer** (as of iOS 2.2)

| Area | Current committed capability | Proposed | iOS state |
| --- | --- | --- | --- |
| Favorite add | `POST /favorites` — unique-violation swallowed, replay converges | accept `Idempotency-Key` | replayed via offline queue (client-side key only) |
| Favorite remove | `DELETE /favorites/{gameId}` — `deleteMany`, no 404, replay converges | accept `Idempotency-Key` | replayed via offline queue (client-side key only) |
| Play status | `POST /users/me/library/status` — find-then-upsert on `(userId, source, externalGameId)`, replay converges | accept `Idempotency-Key` + optimistic concurrency | replayed via offline queue (client-side key only) |
| Conflict detection | none — silent last-write-wins | `version`/`updatedAt` precondition (`409 CONFLICT` + stable code) | client treats server response as authoritative; no conflict UI possible |
| Contract documentation | none (endpoints absent from `openapi/cross-platform.openapi.json`) | committed OpenAPI coverage | iOS mirrors source-code routes only |

## Why

iOS 2.2 ships an offline-first library sync queue: mutations are accepted
locally with a stable client-side idempotency key (a UUID per user intent,
reused verbatim across retries), persisted per account, and replayed against
the committed REST mutations above. This is safe **today** only because each
of those mutations is naturally convergent on replay.

What the client cannot do without server support:

1. **True duplicate detection.** If a request succeeds but the response is
   lost (timeout after commit), the client retries and relies on natural
   convergence. That works for absolute-state mutations, but any future
   non-idempotent mutation (e.g. incrementing playtime, appending notes)
   would double-apply. An `Idempotency-Key` header consumed server-side
   closes this class permanently.
2. **Lost-update detection.** Two devices editing the same library entry
   silently last-write-wins. The status response already returns
   `updatedAt`, but no precondition consumes it. An `If-Match`/`version`
   precondition returning `409` with a stable `error.code` (proposed:
   `LIBRARY_ENTRY_CONFLICT`) would let clients surface conflict-resolution
   messaging instead of silently discarding a write.
3. **Contract stability.** The library/favorite endpoints are not in the
   committed OpenAPI document, so the offline queue is built against
   source-code inspection of `GamePediaCoreServer`, not a committed contract.

## Proposed contract (for discussion, not assumed)

- All library/favorite mutation endpoints accept an optional
  `Idempotency-Key: <uuid>` header; replays within a retention window return
  the original result without re-applying side effects (activity events).
- `POST /users/me/library/status` accepts an optional `expectedUpdatedAt`
  (or integer `version`) field; a mismatch returns `409` with
  `error.code = "LIBRARY_ENTRY_CONFLICT"` and the current server entry.
- Error codes remain stable string constants; clients never parse
  `error.message`.
- The endpoints are added to `openapi/cross-platform.openapi.json` (or a
  committed markdown contract in `GamePediaCoreServer/docs`).

## Open questions for the backend team

1. Is the idempotency retention window per user or global, and how long?
2. Should replayed favorite adds re-fire activity events? (iOS assumes no.)
3. Is `updatedAt` (ISO-8601, millisecond precision) precise enough for a
   precondition, or should an integer `version` column be introduced?
4. Will `409 CONFLICT` from Prisma P2002 (already emitted by the generic
   error middleware) be distinguished from an explicit
   `LIBRARY_ENTRY_CONFLICT` precondition failure?

## iOS behavior until this lands

- The offline queue replays only the three naturally convergent mutations
  listed above; nothing else is queued.
- Client-generated idempotency keys are stored and reused across retries but
  are **not transmitted** (no invented header).
- Server responses remain authoritative; conflicting concurrent edits are
  last-write-wins with no client-side conflict messaging.
- Remote conflict behavior is documented as **runtime-unverified**: there is
  no server contract to verify against.
