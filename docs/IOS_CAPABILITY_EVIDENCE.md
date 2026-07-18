# iOS capability evidence ledger

What the GamePedia iOS client can prove, per capability, and in which
environment. The point of this file is the distinction itself: implemented
code is not verification, local tests are not production evidence, and
nothing below upgrades its own category.

Evidence classes:

1. **Implemented code** — it compiles and ships.
2. **Deterministic local verification** — unit/concurrency tests with
   controlled clocks, gates, and fakes; serialized; no sleeps.
3. **Simulator verification** — manually exercised in the iOS Simulator.
4. **Device verification** — exercised on physical hardware.
5. **Live-backend verification** — exercised against a real deployed API.
6. **Production evidence** — telemetry from real users. **None exists;
   no claim in this repository may cite this class.**

Verification environment for the current entries: local macOS 26.4.1,
Xcode 26.6, iPhone 17 Pro simulator, `scripts/verify.sh` (serialized unit
tests, UI tests skipped — matching CI). Full suite at 2.4: 363 tests.

## Ledger

| Capability | Status | Evidence class | Notes |
| --- | --- | --- | --- |
| Auth refresh single-flight, session supersession, logout/deletion races | VERIFIED (local) | 2 | `AuthRefreshConcurrencyTests` (28 tests, repeated-run stress) |
| Realtime hub lifecycle: fan-out, backoff, session generations, dedup, sequence gaps | VERIFIED (local) | 2 | deterministic mock transport only |
| Realtime against a live socket | BLOCKED_WITH_REASON | — | no backend contract (`BACKEND_CONTRACT_BLOCKERS.md` #1) |
| Offline library queue: durability, restart, account isolation, compaction, corruption recovery | VERIFIED (local) | 2 | includes crash/restart simulation via persistent test stores |
| Server-side conflict/idempotency behavior | BLOCKED_WITH_REASON | — | blockers #2 |
| Request coalescing, stale-result rejection, pagination single-flight | VERIFIED (local) | 2 | 2.3 suites |
| Performance budgets & improvements | PARTIAL | 2–3 | local before/after in `PERFORMANCE_BASELINES.md`; labeled local/simulator; no production percentiles |
| Activity Center merge: cross-source dedup, deterministic ordering | VERIFIED (local) | 2 | `ActivityCenterUseCaseTests` |
| Degraded modes: partial source, offline last-known snapshot, retry | VERIFIED (local) | 2 | use case + view model suites; simulator smoke per `RELEASE_VERIFICATION.md` |
| Read/unread survives process restart | VERIFIED (local) | 2 | restart simulated with fresh store instances over persisted files |
| Cross-device read convergence | BLOCKED_WITH_REASON | — | blockers #3 |
| Exact cross-channel dedup (REST/push/realtime) | PARTIAL | 2 | logical-key + time-window heuristic verified; exactness needs server `dedupeKey` (blockers #4) |
| Push banner dedup & availability fallback to system presentation | IMPLEMENTED_BUT_RUNTIME_UNVERIFIED | 1–2 | suppression registry unit-tested; real APNs delivery/tap not exercised (needs device + push infra) |
| Deep-link / route authentication gating | VERIFIED (local) | 2 | `WidgetDeepLinkPolicyTests`, `ActivityCenterRoutePolicyTests` |
| Account switch/logout/deletion cleanup of live-service state | VERIFIED (local) | 2 | `LiveServiceRuntimeTests`, store purge tests |
| Kill-switch boundary (per-feature availability, overrides, revert paths) | VERIFIED (local) | 2 | local provider only; remote rollout BLOCKED (blockers #6) |
| Incident breadcrumbs privacy (structural redaction) | VERIFIED (local) | 2 | sanitizer property tests + diagnostics rendering test |
| Followed-game / recommendation-ready inbox events | BLOCKED_WITH_REASON | — | kinds reserved client-side; blockers #5 |
| Background push handling limits, process-death restoration on device | IMPLEMENTED_BUT_RUNTIME_UNVERIFIED | 1 | requires physical-device/push runs not available in this environment |

## Remaining unverified items (summary)

Physical-device behaviors (push, process death, memory warnings under real
pressure, network transitions), any live-backend interaction beyond the
committed REST endpoints, and every capability listed in
`BACKEND_CONTRACT_BLOCKERS.md`. These stay out of VERIFIED until the
required environment exists — local stress tests are never re-labeled as
production-scale proof.
