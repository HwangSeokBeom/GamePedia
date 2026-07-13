# Architecture

## System context

The iOS app is a native client of GamePediaCoreServer. The server owns account and user-generated state in PostgreSQL and integrates IGDB/Twitch, Steam, identity providers, Firebase Admin, mail, and an optional LLM provider. Firebase Messaging reaches the iOS client; widget snapshots are shared locally through an app group.

## iOS composition

- `SceneDelegate` creates `AppCoordinator`.
- `AppCoordinator` restores guest/authenticated state and composes tab coordinators and most dependencies.
- `HomeCoordinator`, `SearchCoordinator`, `LibraryCoordinator`, and `ProfileCoordinator` own tab navigation; `AuthCoordinator` owns auth flows.
- UIKit is the main presentation technology. SwiftUI appears in WidgetKit and Apple Translation hosting, not as the primary app architecture.
- Many feature view models follow Intent -> Mutation -> Reducer -> State with Combine publishers. Async/await and actors are also used for network/data work.

## Intended boundaries

```text
UIKit View/Controller -> ViewModel/Reducer -> UseCase -> Domain Repository protocol
                                                     <- Data Repository -> DataSource/APIClient/local store
SceneDelegate -> AppCoordinator -> feature coordinators and dependency composition
```

Domain owns business-facing models and repository protocols. Data owns DTOs, mapping, persistence, and transport. Presentation owns rendering and navigation requests. Application owns platform composition and routes. Current exceptions include view models/coordinators that call `APIClient` or instantiate dependencies directly; these are technical-debt candidates, not a reason for a rewrite.

## Networking and contract

`APIClient` uses URLSession, snake_case-to-camelCase decoding, bearer tokens for authenticated endpoints, 30-second request and 60-second resource timeouts, and a shared Core Server base URL selected by build environment. `Endpoint.swift` is the closest client-side endpoint manifest, but it is not generated and has confirmed drift from backend route registration. See `CROSS_PLATFORM_CONTRACT.md`.

## Persistence and ownership

- Keychain: refresh token and stable device identifier; access token remains in memory.
- UserDefaults: selected appearance/language and several local caches/UX synchronization stores.
- App group: widget snapshot exchange.
- In-memory stores: active user session and several caches.
- Core Server/PostgreSQL: canonical account/review/favorite/library/social/notification data.

No Core Data or SwiftData usage was found.

## Concurrency

The codebase mixes Combine pipelines, `Task`, async/await, task groups, actors, `DispatchQueue.main`, and `MainActor.run`. This is supported but increases cancellation/lifetime and duplicate-update risk. Modernization should establish feature-level ownership and cancellation rules rather than mechanically converting all Combine code.

## Dependencies

Swift Package Manager resolves Firebase iOS SDK, GoogleSignIn-iOS, and Kingfisher. Package obsolescence/security status requires current upstream review and is therefore `UNRESOLVED` in this repository-only baseline.

## Cross-platform boundary

Product rules must be expressed as API/domain contracts rather than copied UIKit/MVI names. Android should share server-visible semantics—IDs, auth, pagination, errors, dates, route targets, validation, and feature outcomes—while using Android-native UI/state/navigation/background primitives.

## Architecture risks

- Hand-authored client/server contracts drift.
- Central coordinators contain large composition and routing surfaces.
- Network payload previews and the full debug access-token logger were removed on 2026-07-13; remaining operational logs still require a distribution-build privacy review.
- Local comment/notification fallbacks can diverge from server truth.
- Backend has mixed legacy auth layering and feature-module layering; this is maintainable if boundaries are clarified, not necessarily replaced.
- Runtime-only behavior includes OAuth, Keychain restore, push, widgets, Steam callbacks, environment routing, signing, and external API fallbacks.
