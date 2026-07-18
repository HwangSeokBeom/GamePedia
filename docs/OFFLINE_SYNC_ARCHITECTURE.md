# Offline-first library sync architecture (iOS 2.2 foundation)

Shipped in 2.2. Library mutations (favorites, play status) stay responsive
during transient network failure via a durable, account-scoped operation
queue that replays committed, replay-convergent REST mutations. The server
has no idempotency-key or conflict-version contract yet
(`docs/backend/LIBRARY_SYNC_CONTRACT_REQUEST.md`); the client therefore
does not claim verified true conflict resolution.

## Components (`GamePedia/Core/Sync/`)

- **`LibrarySyncEngine` (actor)** — the queue: stable idempotency keys,
  per-entity FIFO ordering, add/remove compaction, capped retry with
  park-on-permanent-failure, auth-pause (`isBlockedOnAuth`), session-
  generation inertness, duplicate-callback protection, diagnostics
  snapshot. Feature code talks to `LibraryMutationSyncing`.
- **`FileSyncOperationStore` (actor)** — durable queue storage: one JSON
  file per (schema version, SHA-256(accountID)) under Application Support;
  schema version in the file name (rollback-safe); corruption quarantine
  (`.corrupt`); `purge(accountID:)` for account deletion.
- **`RESTLibrarySyncTransport`** — replays through the existing
  repositories; invents no endpoints.
- **`LibrarySyncFailureClassifier`** — stable `error.code` values →
  transient / permanent / authRequired. Never message text.
- **`LibrarySyncRuntime`** — composition root; kill-switch
  `FeatureFlags.enableOfflineLibrarySync` (off → `mutationRouter == nil`
  → pre-2.2 direct REST path); bridges auth, account deletion,
  foreground, and `NWPathMonitor` connectivity.

## Invariants (deterministic test coverage)

- optimistic UI with explicit pending state; restart never loses queued
  operations; retries reuse the same idempotency key;
- operations are scoped by authenticated user ID — an account switch can
  never submit the previous account's queue; account deletion purges the
  account's files (all schema versions + quarantined copies);
- per-entity deterministic ordering; independent entities sync in
  parallel; safe add→remove compaction;
- permanent validation failures park (no infinite retry); transient
  transport failures preserve pending work; refresh-token failure pauses
  without corrupting the queue;
- corrupted stores quarantine and restart empty; server responses remain
  authoritative; no credential material in queue files or logs.

## 2.4 relationship

The 2.2 storage contract became the generic
`AccountScopedStateStore<Payload>` (Core/LiveService) used by the Activity
Center read watermark and last-known snapshot. The engine itself is
unchanged in 2.4; the availability boundary reports
`offlineLibrarySync` state for diagnostics, and breadcrumb category
`.sync` is reserved for its incident timeline.

## Verification status

- Queue semantics, durability, account isolation, migration/corruption
  safety: VERIFIED (deterministic local tests incl. restart simulation
  with persistent stores).
- True server-side idempotent/conflict behavior under concurrent writers:
  BLOCKED_WITH_REASON — no server contract; replay convergence is argued
  from the committed REST semantics, not proven against a live backend.
