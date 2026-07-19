# Release verification runbook — GamePedia iOS

The checks a release of the iOS client must pass, what each proves, and
the honest status vocabulary. CI mirrors the local script; nothing here
claims more than the environment can prove.

## Status vocabulary (use exactly these)

- **VERIFIED** — exercised end-to-end in the claimed environment.
- **IMPLEMENTED_BUT_RUNTIME_UNVERIFIED** — code + deterministic tests
  exist, but the required backend/device/push infrastructure was not
  exercised.
- **PARTIAL** — some required paths verified, others not; list which.
- **BLOCKED_WITH_REASON** — cannot be verified; state the blocker.

Never label local/simulator evidence as production performance.

## Standard local verification (every release)

```
scripts/verify.sh            # full: static checks + serialized tests
scripts/verify.sh --static   # hygiene only
```

Runs, in order:

1. `git diff --check` — whitespace hygiene.
2. `scripts/check-architecture.sh` — layering rules (R1–R7), including
   the 2.4 rule that `Core/LiveService` stays Domain-free.
3. Sensitive-log scan — credential-shaped interpolation into print/log.
4. Serialized unit tests, `GamePedia-Dev`/Debug, signing disabled, UI
   tests skipped — byte-for-byte the Fastlane `ci_build` lane. Tests stay
   serialized on purpose; do not re-enable parallel execution.

Release build check (unsigned, catches Release-only compilation issues):

```
xcodebuild build -project GamePedia.xcodeproj -scheme GamePedia-Prod \
  -configuration Release -destination "generic/platform=iOS" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
```

## Live-service (2.4) release checklist

Deterministic suites (all part of the standard run):

- identity/dedup: `LiveActivityIdentityTests`
- kill-switch boundary: `FeatureAvailabilityTests`, `LiveServiceRuntimeTests`
- breadcrumb privacy: `OperationBreadcrumbsTests`
- durable state: `AccountScopedStateStoreTests`, `ActivityReadStateStoreTests`
- merge/degrade/cache: `ActivityCenterUseCaseTests`
- screen behavior: `ActivityCenterViewModelTests`
- route gating: `ActivityCenterRoutePolicyTests`

Simulator smoke (manual, Debug build):

1. Bell → Activity Center renders merged timeline; tap-through routes work.
2. Airplane mode → retry → offline last-known banner; list stays usable.
3. Re-enable network → retry → fresh timeline, notice clears.
4. Toggle `unifiedActivityCenter` off via debug override → bell opens the
   legacy Notifications screen.
5. Developer Diagnostics shows availability states and breadcrumbs, and
   contains no `@`, `Bearer`, or token-shaped strings.

Requires infrastructure the repo cannot drive (label accordingly):

- background push delivery and notification-tap routing on a physical
  device (needs APNs) — IMPLEMENTED_BUT_RUNTIME_UNVERIFIED;
- cross-device read-state convergence — BLOCKED_WITH_REASON (no per-item
  read contract);
- remote kill-switch rollout — BLOCKED_WITH_REASON (no remote config
  contract);
- realtime channel behavior against a live socket — BLOCKED_WITH_REASON
  (no realtime contract).

## Recording results

Update `docs/IOS_CAPABILITY_EVIDENCE.md` with the run date, environment
(macOS/Xcode/simulator), test totals, and any status changes. The final
release report must quote the actual `verify.sh` outcome, not intent.
