# Live-service operations (iOS 2.4)

How the GamePedia iOS client behaves as an operated service: one canonical
activity surface, explicit degradation, a testable kill-switch boundary,
and incident-safe diagnostics. Everything here is client-side; server
capabilities are never fabricated (see
`docs/backend/ACTIVITY_CENTER_CONTRACT_REQUEST.md`).

## Unified Activity Center

Entry: the notification bell (`HomeCoordinator.showNotifications()`).
When `LiveServiceFeature.unifiedActivityCenter` resolves available, the
bell opens `ActivityCenterViewController`; otherwise the legacy
Notifications screen runs unchanged — that is the rollback path.

Pipeline (`FetchActivityCenterUseCase`):

1. Fetch the notification inbox and the friend activity feed concurrently.
   REST is the only item source — push and realtime never inject rows.
2. Map both into the canonical `ActivityCenterItem`
   (`Domain/ActivityCenter/`): stable `identity` (exact key),
   channel-agnostic `logicalKey`, canonical `kindCode`, display fields,
   `SocialActivityRoute`.
3. Merge: newest first, deterministic tie-break, exact duplicates dropped,
   cross-source twins (same `logicalKey` within 10 minutes) collapsed with
   the inbox item winning (it carries server read state).
4. Overlay the account-scoped read watermark.
5. Persist the merged view as the account's last-known snapshot.

### Degradation ladder (no failure is silent)

| Condition | Behavior |
| --- | --- |
| Both sources fresh | Full timeline |
| One source fails | Partial timeline + "some updates couldn't be loaded" notice + retry |
| Both fail, snapshot exists | Last-known items + offline notice + retry |
| Both fail, no snapshot | Error state + retry (user-driven only) |

`ActivitySourceHealth` carries per-source freshness into the UI; the badge
is only rewritten from fresh server-backed counts, never from cache.

## Identity and deduplication

`LiveActivityIdentity` (Core/LiveService) derives:

- `exact` key — unique per delivered item (`id:<serverID>` preferred);
  used for read-state bookkeeping and push TTL dedup.
- `logical` key — canonical event class + actor/game/review/comment facets;
  used to collapse the same logical activity across channels.

`LiveActivityDeduplicator` is the single TTL+capacity-bounded suppression
registry. `SocialActivityDeduplicator` (push banners/routes) now delegates
to it, so push, banner, and future realtime ingestion share one "processed
once" guarantee. Keys are built from stable identifiers only — titles,
messages, emails, and tokens structurally cannot enter a key.

Exact cross-channel identity needs a server `dedupeKey` (requested).

## Read/unread state

Server contract: mark-ALL-read only. The client layers an account-scoped,
schema-versioned read watermark (`ActivityReadStateStore`) on top:

- viewing the Activity Center advances the watermark to the newest visible
  item and calls the idempotent server mark-all-read (failures are
  breadcrumbed and retried on the next visit);
- watermarks only move forward and never un-read server-read items;
- state survives process restart, is invisible across accounts, and is
  purged on account deletion.

## Feature availability (kill-switch boundary)

`FeatureAvailabilityProviding` (Core/LiveService) is the single answer to
"is this live-service capability usable?". `LocalFeatureAvailabilityProvider`
resolves build-time `FeatureFlags` plus in-process overrides and announces
changes via `.liveServiceAvailabilityDidChange`.

Current consumers:

- `unifiedActivityCenter` — bell routing (off → legacy screen);
- `socialPushBanners` — off → pushes fall through to the system banner
  (never dropped);
- `realtimeActivity` — can never resolve available without a backend
  contract, mirroring `RealtimeRuntime`;
- `offlineLibrarySync` — reported for diagnostics (the engine keeps its
  existing flag wiring from 2.2).

There is no remote provider. Server-controlled rollout is not claimed; the
override path exists so tests and DEBUG tooling can exercise both sides of
every switch.

## Operation breadcrumbs

`OperationBreadcrumbRecorder` keeps a bounded (200) in-memory, oldest-first
timeline of sanitized operational events: session transitions, availability
changes, Activity Center load outcomes (`load_success`, `load_partial`,
`load_cache_fallback`, `load_failed`), mark-read failures, and push
duplicate suppressions. Every code and metadata value must pass a strict
identifier alphabet (≤64 chars, no `@`, no spaces, no `+/=`); anything else
is stored as `<redacted>`. Breadcrumbs are surfaced only on the DEBUG
diagnostics screen and are never persisted or uploaded.

## Account lifecycle

`LiveServiceRuntime` (started in `AppDelegate`) bridges
`.authSessionDidChange` / `.authAccountDidDelete`:

- login sets the account scope; logout clears it (files stay sandboxed and
  unreachable without the scope);
- account switch replaces the scope — every store call is keyed by the
  account ID captured at call time, so the previous account's queue/state
  can never be read or written;
- account deletion purges read state and snapshots (all schema versions
  plus quarantined copies).

## Operational levers in an incident

1. DEBUG diagnostics screen → availability states + breadcrumbs +
   realtime/sync counters (safe metadata only).
2. Local kill-switch override per feature (DEBUG/tests today; remote
   config requested).
3. Build-time flags: `enableUnifiedActivityCenter`,
   `enableOfflineLibrarySync`, `enableRealtimeActivity` — each reverts to
   the previous behavior without data loss.

See `docs/INCIDENT_RESPONSE.md` for the playbook and
`docs/RELEASE_VERIFICATION.md` for the release runbook.
