# Backend contract blockers — iOS live-service roadmap

Single index of every capability the iOS client has scaffolded but cannot
runtime-verify because the backend contract does not exist. Each item
links the full request document. The client never fabricates these:
missing capabilities resolve to explicit `unavailable` states, protocol
boundaries with deterministic mocks, and documented degradation.

| # | Capability | Blocks | Client state today | Request |
| --- | --- | --- | --- | --- |
| 1 | Realtime channel (WS/SSE), event envelope, auth handshake | live activity updates, event-to-UI latency measurement | `UnavailableRealtimeClient`; hub verified against deterministic mock only | `backend/REALTIME_CONTRACT_REQUEST.md` |
| 2 | Idempotency keys / conflict versions on library mutations | provable exactly-once + conflict resolution | replay-convergent queue; LWW; conflicts runtime-unverified | `backend/LIBRARY_SYNC_CONTRACT_REQUEST.md` |
| 3 | Per-item notification read state | cross-device read/unread convergence | device-local read watermark, account-scoped, restart-safe | `backend/ACTIVITY_CENTER_CONTRACT_REQUEST.md` §1 |
| 4 | Cross-channel `dedupeKey` | exact one-logical-activity-once across REST/push/realtime | canonical logical key + 10-minute collapse window (heuristic) | `backend/ACTIVITY_CENTER_CONTRACT_REQUEST.md` §2, `backend/REALTIME_CONTRACT_REQUEST.md` #8 |
| 5 | Followed-game update + recommendation-ready notification types | those event classes appearing in the Activity Center | kinds reserved in the canonical model; routing ready (`recommendation` push route works) | `backend/ACTIVITY_CENTER_CONTRACT_REQUEST.md` §3 |
| 6 | Remote feature availability / kill-switch config | server-controlled rollout & incident kill | local provider + in-process overrides; build-time flags for rollback | `backend/ACTIVITY_CENTER_CONTRACT_REQUEST.md` §4 |

Review cadence: revisit at each release planning session; when a contract
lands, the corresponding items in `docs/IOS_CAPABILITY_EVIDENCE.md` move
from BLOCKED/IMPLEMENTED_BUT_RUNTIME_UNVERIFIED toward VERIFIED with real
runtime evidence.
