# GamePedia iOS 2.1 → 2.4 roadmap (as delivered)

Four sequential releases turning the iOS client into a measurable,
operable live-service app, without weakening the hardened authentication
layer, fabricating backend capabilities, or rewriting working code. Each
release: clean dev baseline → focused branch → deterministic tests → full
local verification → one focused commit.

| Release | Branch | Commit | Status |
| --- | --- | --- | --- |
| 2.1 Realtime & Observability | `feat/2.1-realtime-observability` | `feat(realtime): add observable activity foundation` | merged (PR #15) |
| 2.2 Offline Library Sync | `feat/2.2-offline-library-sync` | `feat(library): add offline-first synchronization` | merged (PR #16) |
| 2.3 Performance & Internal Platform | `feat/2.3-performance-platform` | `perf(platform): add measurable shared iOS infrastructure` | merged (PR #17) |
| 2.4 Live Service Operations | `feat/2.4-live-service-operations` | `feat(activity): complete live-service operations foundation` | this release |

## 2.1 — Realtime & Observability

- `Core/Realtime`: actor-isolated hub, subscriber fan-out, deterministic
  reconnect, dedup + sequence protection, session-generation ownership.
  Transport intentionally absent (no backend contract) — REST fallback
  everywhere. `docs/REALTIME_ARCHITECTURE.md`.
- `Core/Observability`: signpost-paired metric recorder (`AppMetric`),
  MetricKit receipts, privacy-safe diagnostics screen (DEBUG).
- Backend ask: `docs/backend/REALTIME_CONTRACT_REQUEST.md`.

## 2.2 — Offline-first library sync

- `Core/Sync`: durable account-scoped operation queue (idempotency keys,
  per-entity ordering, compaction, park/pause, corruption quarantine,
  rollback-safe schema files). Kill-switch reverts to direct REST.
  `docs/OFFLINE_SYNC_ARCHITECTURE.md`.
- Backend ask: `docs/backend/LIBRARY_SYNC_CONTRACT_REQUEST.md`.

## 2.3 — Performance & internal platform

- Measured-first: `docs/PERFORMANCE_BASELINES.md` (local baselines,
  before/after evidence, budgets).
- Shared components extracted from proven duplication:
  `RequestCoordinator` (coalescing), `LatestRequestGate`,
  `PaginationStateMachine`, image pipeline policy.
- Automation: `scripts/verify.sh` (CI-equivalent),
  `scripts/check-architecture.sh` (layering rules as failing checks).

## 2.4 — Live service operations

- Unified **Activity Center**: canonical `ActivityCenterItem` over the
  notification inbox + friend activity feed; cross-source dedup via
  channel-agnostic logical keys; newest-first deterministic merge.
- **Read/unread** that survives restart: account-scoped read watermark on
  top of the mark-all-read server contract.
- **Degraded modes**: partial-source notice, offline last-known snapshot,
  user-driven retry — no silent failure, badge never rewritten from cache.
- **Kill-switch boundary**: `FeatureAvailabilityProviding` + local
  provider/overrides; bell reverts to the legacy inbox when off; push
  banners degrade to system presentation. No remote config claimed.
- **Incident-safe breadcrumbs**: bounded, sanitized operational timeline
  in the DEBUG diagnostics screen.
- Docs: `LIVE_SERVICE_OPERATIONS.md`, `INCIDENT_RESPONSE.md`,
  `RELEASE_VERIFICATION.md`, `BACKEND_CONTRACT_BLOCKERS.md`,
  `IOS_CAPABILITY_EVIDENCE.md`.
- Backend ask: `docs/backend/ACTIVITY_CENTER_CONTRACT_REQUEST.md`.

## Capability mapping (honest framing)

- **Platform engineering**: shared Core modules with enforced dependency
  rules, CI-equivalent local automation, measured budgets, kill-switch
  boundaries — evidence is local/deterministic, labeled as such.
- **Swift Concurrency**: actors own every mutable service state
  (`RealtimeHub`, `LibrarySyncEngine`, stores); structured tasks;
  injectable clocks/sleepers; zero sleeps in concurrency tests.
- **Realtime/WebSocket**: full client-side lifecycle machine, verified
  deterministically; live-socket behavior explicitly BLOCKED on a backend
  contract — not claimed.
- **Profiling/crash response**: signposts + MetricKit + diagnostics +
  breadcrumbs; production percentiles are not claimed anywhere
  (`docs/IOS_CAPABILITY_EVIDENCE.md` draws the line).
- **Service ownership**: degraded-mode UX, incident playbook, release
  runbook, rollback paths per feature.
