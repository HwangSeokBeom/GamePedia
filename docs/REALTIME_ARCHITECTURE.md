# Realtime architecture (iOS 2.1 foundation)

The client-side realtime foundation shipped in 2.1. It is production-code
that deliberately never connects: the backend has no committed realtime
contract (`docs/backend/REALTIME_CONTRACT_REQUEST.md`), so the transport is
`UnavailableRealtimeClient` everywhere and every feature falls back to pure
REST. Nothing in this document claims a live socket was exercised.

## Components (`GamePedia/Core/Realtime/`)

- **`RealtimeHub` (actor)** — single owner of the (future) physical
  connection. Subscriber fan-out (`subscribe() -> AsyncStream<RealtimeSignal>`),
  session-generation ownership, reconnect with jittered exponential backoff
  (`ReconnectPolicy`, injectable sleeper/jitter for determinism),
  foreground/background bridging, diagnostics snapshot.
- **`RealtimeClient` protocol** — transport boundary.
  `UnavailableRealtimeClient` (production), `MockRealtimeClient`
  (tests/DEBUG demo only).
- **`RealtimeEvent` + `RealtimeEventDecoder`** — the PROPOSED envelope
  (id, type, schemaVersion, sequence, occurredAt, payload). Malformed
  frames are isolated; unknown types counted, never crashing.
- **`EventDeduplicator`** — bounded FIFO id-dedup (capacity 512).
- **`EventSequenceStore`** — first/next/stale/gap judgment; gaps raise
  `RealtimeSignal.reconciliationRequired(.sequenceGap)`.
- **`RealtimeRuntime`** — composition root started in `AppDelegate`;
  bridges `.authSessionDidChange` and UIKit lifecycle into the hub.
- **`ActivityFeedInvalidationSource`** — the only feature-facing surface:
  realtime is an invalidation hint; **REST remains the source of truth**.

## Invariants (all covered by deterministic tests)

- one physical connection serves all subscribers; cancelling one never
  closes the shared connection; last-subscriber behavior explicit;
- session replacement invalidates the previous connection generation —
  events from an old session cannot reach the new one;
- logout closes the authenticated connection and cancels reconnects;
- reconnect never uses an obsolete credential and never recurses refresh;
- duplicate event ids applied once; stale sequences rejected; gaps trigger
  REST reconciliation;
- backoff is exponential with bounded, injected jitter — no sleeps in
  tests (`TestRealtimeSleeper`, `FixedJitterSource`);
- raw payloads, tokens, emails, Authorization values never logged
  (enforced by the verify.sh sensitive-log scan + diagnostics tests).

## 2.4 relationship

2.4 does not open a connection either. It adds:

- `LiveServiceFeature.realtimeActivity` in the availability boundary,
  which can never resolve `available` while no backend contract exists;
- the unified `LiveActivityDeduplicator`, which future realtime ingestion
  must route through so push/REST/realtime share one suppression registry;
- breadcrumb category `.realtime` for incident timelines.

## Verification status

- Hub/state-machine/dedup/backoff invariants: VERIFIED (deterministic
  local tests, simulator).
- Live socket behavior, server heartbeats, credential handshake:
  BLOCKED_WITH_REASON — no committed backend contract.
