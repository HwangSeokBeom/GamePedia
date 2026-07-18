# GamePedia iOS Performance Baselines (2.3)

All numbers in this document are **local evidence only**: unsigned Debug
builds on the iOS Simulator (iPhone 17 Pro, Xcode 26.6 toolchain, Apple
Silicon host, local `127.0.0.1:3001` dev backend). They are baselines for
relative before/after comparison inside the same environment. Nothing here
is a production p50/p95, crash-free-rate, or device-performance claim.

Measurement sources:

- `[Metric]` console lines emitted by `PerformanceMetricRecorder` (2.1),
  which mirror `os_signpost` intervals visible in Instruments under the
  same names.
- Console request logs (`[HomeAPI]`, `[GameAPI]`) counted per launch.
- Deterministic XCTest evidence where noted.

## Pre-change baseline (branch point `ba49410`, 2026-07-19)

### Launch intervals — 3 cold launches (app terminated between runs)

| Run | cold_launch (ms) | first_home_render (ms) |
|----:|-----------------:|-----------------------:|
| 1 | 2865.7 | 1527.8 |
| 2 | 2213.5 | 1192.6 |
| 3 | 2583.8 | 1574.2 |

`cold_launch` includes the fixed splash presentation delay; both metrics
are simulator wall-clock and vary run-to-run. They are recorded to detect
regressions, not as absolute budgets.

### Duplicate home-list requests at launch (defect)

One cold launch issues each home list request **twice**:

```
GET /games/popular?limit=10      x2
GET /games/recommended?limit=10  x2
GET /games/highlights?limit=5    x2
```

Cause: `GameWidgetSnapshotRefreshService` (widget snapshot refresh) and
`HomeViewModel` (home screen load) both execute `LoadHomeFeedUseCase`
concurrently during startup. Existing dedupe layers do not cover this:
`GameDetailRequestStore` coalesces only `/games/:id`, and
`WidgetSnapshotRefreshCoordinator` coalesces only widget refresh passes
against each other.

### Notifications load coalescing (defect)

`NotificationsViewModel.loadNotifications()` has no in-flight guard and no
request identity: rapid retry taps issue one network request per tap, and
two overlapping loads race last-write-wins on state.

### Existing request-coordination duplication (extraction justification)

Three hand-rolled implementations of the same concern predate 2.3:

- `GameDetailRequestStore` (actor: in-flight join + TTL + 429 backoff)
- `WidgetSnapshotRefreshCoordinator` (actor: in-flight join + TTL)
- `SearchViewModel` UUID latest-request-wins gate

## 2.3 measured budgets (defined after baseline, per release gate)

1. Duplicate home-list requests at cold launch: **0** (each endpoint
   requested exactly once), verified by launch log capture and by a
   deterministic coalescing unit test.
2. Rapid notifications retries: exactly **1** in-flight request,
   deterministic unit test.
3. A cancelled/superseded list load must never overwrite newer state,
   deterministic unit test.
4. Pagination must reject duplicate pages and reset cleanly,
   deterministic unit test.
5. `cold_launch` / `first_home_render` post-change medians must not
   regress by more than run-to-run noise already visible in the baseline
   table above.

## Post-change evidence (same host, simulator, and local dev backend)

### Duplicate home-list requests at launch — budget 1: MET

Three instrumented cold launches each show every home list endpoint
requested exactly **once**:

```
GET /games/popular?limit=10      x1   (+ [RequestCache] hit age=0s)
GET /games/recommended?limit=10  x1   (+ [RequestCache] hit age=0s)
GET /games/highlights?limit=5    x1   (+ [RequestCache] hit age=0s)
```

The launch sequence is sequential (the widget snapshot refresh finishes
before Home's load starts), so in-flight coalescing alone was measured to
be insufficient; the home screen's load joins the 30-second success TTL
of the shared list coordinator instead. 30s is below both existing
accepted freshness policies (widget refresh TTL 45s, game-detail cache
TTL 600s). The same coalescing behavior is locked by deterministic unit
tests (`RequestCoordinationTests`).

### Launch intervals — 3 cold launches (post-change)

| Run | cold_launch (ms) | first_home_render (ms) |
|----:|-----------------:|-----------------------:|
| 1 | 1024.9 | 29.8 |
| 2 | 1010.7 | 27.5 |
| 3 | 1025.3 | 26.7 |

Both medians improved far beyond baseline noise (budget 5 met:
`cold_launch` ~2580ms → ~1020ms, `first_home_render` ~1530ms → ~28ms).
Mechanism: Home previously waited on its own duplicate network round
trip after the splash; it now renders from the list data the widget
refresh already fetched seconds earlier. The absolute numbers reflect a
localhost dev backend and remain local simulator evidence only.

### Deterministic budgets 2–4 — MET

- Rapid notifications retries → exactly one in-flight request, one
  drained follow-up (`NotificationsViewModelTests`).
- Superseded/stale completions can never overwrite newer state
  (`RequestCoordinationTests` gate tests, `PaginationStateMachineTests`
  stale-completion tests).
- Duplicate pages rejected and reset semantics clean
  (`PaginationStateMachineTests`).

Full serialized suite after the change: 283 passed / 0 failed
(baseline 251; 32 tests added by 2.3).
