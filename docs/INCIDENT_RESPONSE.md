# Incident response — GamePedia iOS client

Client-side playbook for live-service incidents. Scope: what an iOS
engineer can observe and control from the app. Server-side runbooks live
with the backend.

## First 5 minutes

1. **Reproduce on a Debug build** (`GamePedia-Dev` scheme).
2. Open the **Developer Diagnostics screen** (DEBUG environment menu →
   Developer Diagnostics). It shows safe metadata only:
   - session booleans (never token values),
   - realtime hub counters and connection state,
   - library sync queue counters,
   - local metric samples (labeled local/simulator),
   - **feature availability states** (2.4),
   - **operation breadcrumbs** (2.4) — the sanitized timeline of what the
     live-service layer did last (loads, fallbacks, suppressions, session
     transitions).
3. Note the last breadcrumb codes before the symptom. Codes are stable
   machine identifiers (`load_partial`, `load_cache_fallback`,
   `mark_read_remote_failed`, `duplicate_suppressed`,
   `availability_changed`, `session_guest`, `account_state_purged`).

## Symptom → likely layer

| Symptom | Look at | Notes |
| --- | --- | --- |
| Activity Center shows offline banner | `load_cache_fallback` breadcrumbs | Both REST sources failed; the screen is serving the account's last-known snapshot. Check API health. |
| "Some updates couldn't be loaded" | `load_partial` + source metadata | Exactly one source failed; the other is live. |
| Duplicate banners/rows | `duplicate_suppressed` count, dedupe keys | Client collapses by logical key within 10 min; exact cross-channel identity needs the requested server `dedupeKey`. |
| Unread badge wrong | `mark_read_remote_failed` | Server mark-all-read failed; local watermark still advanced; the call retries on next visit. |
| Items reappear unread after reinstall | expected | Read watermark is device-local (no per-item server contract). |
| Library changes not syncing | sync counters (`isBlockedOnAuth`, parked ops) | 2.2 engine; see OFFLINE_SYNC_ARCHITECTURE. |
| Realtime "connected" anywhere | should be impossible | No backend contract; hub must be `unavailable`. Treat as a bug. |

## Containment levers

Ordered by blast radius, smallest first:

1. **Local availability override** (DEBUG verification of the off-path):
   `LiveServiceRuntime.shared.availability.setOverride(.unavailable(.localOverride), for: ...)`.
2. **Build-time kill-switches** (next release / hotfix):
   - `enableUnifiedActivityCenter = false` → bell opens the legacy
     Notifications screen; no data migration needed either direction.
   - `enableOfflineLibrarySync = false` → direct REST mutations (pre-2.2
     path); queued operations stay on disk untouched.
   - `enableRealtimeActivity` is already false everywhere.
3. **Remote kill-switch** — NOT AVAILABLE. Requested in
   `docs/backend/ACTIVITY_CENTER_CONTRACT_REQUEST.md` §4. Do not claim it.

## Data-safety rules during incidents

- Never ask users to log out to "fix" the Activity Center: logout only
  clears the in-memory scope; it neither repairs nor removes on-disk state.
- Corrupted local stores self-quarantine (`*.corrupt`) and restart empty —
  collect the quarantined file from a Debug device before deleting.
- Breadcrumbs and diagnostics contain no credentials, emails, or free-form
  content by construction (sanitizer + tests). They may be pasted into
  incident channels.

## After the incident

- File the missing backend capability if the workaround was client-local.
- Add a deterministic regression test that reproduces the trigger.
- Update `docs/IOS_CAPABILITY_EVIDENCE.md` if verification status changed.
