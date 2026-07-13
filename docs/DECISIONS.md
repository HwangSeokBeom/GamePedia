# Technical Decisions

Record durable decisions append-only. Repository evidence can establish current state; proposals remain proposed until a product/technical owner accepts them.

## D-001 — Preserve native clients and backend evolution

- Date: 2026-07-12
- Status: proposed
- Context: iOS 2.0 and Core Server already implement broad behavior; `GamePedia_AOS` is only an empty directory and Android is not created.
- Decision: add a native Android client and evolve existing iOS/backend incrementally. Do not default to a rewrite.
- Alternatives: shared cross-platform UI rewrite; backend replacement.
- Consequences and risks: parity requires an explicit contract and duplicate platform UI effort, but preserves working behavior and limits migration blast radius.
- Verification impact: contract tests and per-platform behavioral acceptance checks are mandatory.

## D-002 — Freeze a versioned cross-platform contract before Android feature work

- Date: 2026-07-12
- Status: proposed
- Context: `Endpoint.swift` and Express route registration contain confirmed path mismatches, and only AI routes use `/api/v1`.
- Decision: inventory and reconcile the currently used contract, define compatibility/deprecation rules, then generate or validate client fixtures against an API description.
- Alternatives: allow Android to follow server routes ad hoc; copy iOS DTOs.
- Consequences and risks: adds an early stabilization phase but prevents two clients from encoding existing ambiguity.
- Verification impact: server route tests plus iOS/Android decoding fixtures and staging smoke tests.

## D-003 — Android uses native architecture, not iOS class mirroring

- Date: 2026-07-12
- Status: proposed
- Context: requested candidate stack is Kotlin, Compose, ViewModel, StateFlow, Coroutines, and feature modules.
- Decision: use unidirectional state where useful, platform ViewModels, coroutines/flows, Navigation Compose, and minimum justified modules. Reuse product/API semantics only.
- Alternatives: reproduce Coordinator/MVI/UseCase types one-for-one; begin with many fine-grained modules.
- Consequences and risks: clearer Android ownership; requires behavior matrices to avoid accidental product divergence.
- Verification impact: architecture dependency checks and feature parity acceptance tests.

## D-004 — Recommend Option A with modernization prerequisites

- Date: 2026-07-12
- Status: proposed
- Context: Android parity is the immediate goal; Option B combines two-client delivery with broad iOS/backend refactoring.
- Decision: ship Android parity in staged slices while performing only contract, security, observability, and reliability work required for safe multi-client support. Schedule broader iOS modernization separately.
- Alternatives: Option B cross-platform modernization; Option C next-generation product redesign.
- Consequences and risks: faster learning and lower release coupling; visible UX differences may persist until shared design rules mature.
- Verification impact: parity matrix, compatibility window, independent client release gates.

## D-005 — Propose Trustworthy Search as the first Android vertical slice

- Date: 2026-07-13
- Status: proposed
- Context: Trustworthy Search is the selected post-2.0 scope, while earlier plans separately proposed Home-to-Detail as the Android foundation. That split would leave the declared Search release incomplete and expand contract work across unrelated features.
- Decision: after identity/toolchain/design/contract gates, make public standard Search the first thin Android slice. Defer authenticated AI Search until the auth foundation is contract-backed. Home and Detail remain later parity slices.
- Alternatives: guest Home-to-Detail foundation; a non-feature shell/toolchain spike.
- Consequences and risks: one release scope stays traceable, but Search must be added to OpenAPI and staging fixtures before scaffolding, and the initial app has a deliberately narrow destination.
- Verification impact: shared Search fixtures, serializer/ViewModel/Compose tests, emulator/device accessibility/localization checks, and staging parity with iOS.

## Decision template

- Date:
- Status: proposed | accepted | superseded
- Context:
- Decision:
- Alternatives:
- Consequences and risks:
- Verification impact:
