# Product

## Evidence boundary

This document describes behavior evidenced by `README.md`, application coordinators, feature source files, endpoint definitions, localization resources, widgets, and tests. It is not validated product research. Personas, usage frequency, business goals, analytics, monetization, and legal retention requirements remain `UNRESOLVED`.

## Current user value

GamePedia lets a user discover and search games, inspect game metadata, save favorites and play status, connect Steam context, write and discuss reviews, follow social activity, and receive notifications. AI recommendation/search/summary features add assisted discovery but have rule-based or empty-state fallbacks.

## Implemented information architecture

The root app exposes four tabs assembled by `AppCoordinator`: Home, Search, Library, and Profile. Authentication can be presented modally; guest users can browse public game data while restricted actions are gated. Game details and review discussions are reached from multiple tabs, notifications, pushes, and deep links.

## Traceable requirements

| ID | Implemented requirement | Primary evidence |
|---|---|---|
| GP-P01 | Browse highlights, popular, trending/recommended games with filters | `Presentation/Home`, `LoadHomeFeedUseCase`, `Endpoint.swift` |
| GP-P02 | Search games, suggestions, localized aliases, and AI search assist | `Presentation/Search`, backend IGDB/search/AI modules |
| GP-P03 | View canonical game detail with Steam fallback and review summary | `Presentation/GameDetail`, `GameDetailRemoteDataSource` |
| GP-P04 | Create, edit, delete, like, comment on, react to, and report reviews | `Presentation/Review`, Domain/Data review layers |
| GP-P05 | Favorite games and manage playing/backlog/completed/dropped library state | Favorite and Library layers; backend Prisma enums/models |
| GP-P06 | Link/unlink/sync Steam and show recent/owned/recommendation context | `Application/SteamLink`, `Data/Library`, backend library module |
| GP-P07 | Email, Apple, and Google authentication with session refresh/logout/delete | Auth coordinators/layers and backend auth routes |
| GP-P08 | Maintain profile, friends, privacy, moderation, titles, and activity | Profile/Friend/Moderation features and backend user module |
| GP-P09 | Register push tokens, list/read notifications, route notification taps | `Application/Push`, `Presentation/Notifications` |
| GP-P10 | Provide trending, recent-viewed, my-activity, and review-prompt widgets | `GamePediaWidgetExtension`, widget snapshot services/tests |
| GP-P11 | Support Korean, English, Japanese, and Simplified Chinese resources | `Resources/Localization/*` |

## Proposed quality requirement

`GP-Q01 Accessibility` is proposed for both native clients but is not established by current product evidence. It requires owner acceptance and explicit VoiceOver/TalkBack, scalable-text, contrast, touch-target, focus, and reduced-motion criteria; it must not be reported as existing parity behavior.

## Data sources

- Core Server proxies IGDB/Twitch for canonical game discovery/detail.
- Steam Web API supplies linked ownership/recent-play/social inputs through Core Server.
- Core Server/PostgreSQL owns user-generated and account data.
- Apple Translation framework is used in client translation-host code; README claims a separate Translate Server, but current canonical server behavior says it returns original data. The active production translation path is `UNRESOLVED` until runtime verification.

## Account and privacy behavior

Refresh tokens are stored in Keychain and access tokens in memory. The app supports logout, account deletion, profile image changes, social privacy settings, blocking, and reporting. Backend retention after account deletion, export/portability, consent, notification opt-in wording, and privacy-policy operational compliance are `UNRESOLVED`.

## Known incomplete or fallback behavior

- Guest mode continues after missing/failed refresh and gates restricted actions.
- AI recommendations/search/summary can return rule-based or unavailable fallbacks.
- Game detail includes a Steam fallback surface.
- Review comments include local storage/notification behavior as well as server APIs; conflict/reconciliation semantics are not formally specified.
- Several iOS endpoint paths do not match current registered backend paths; see `CROSS_PLATFORM_CONTRACT.md`.

## Current execution boundary

Android creation remains gated by the accepted contract and build/runtime evidence. This execution slice repaired the Xcode project structure and hardened iOS network/token logging; it did not deploy, migrate APIs, create Android, commit, or push.
