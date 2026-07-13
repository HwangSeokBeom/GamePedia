<!-- ai-development-system:begin -->
# Project Instructions

This file extends the user's global Codex guidance. It contains project-specific facts only. `UNRESOLVED` values must be confirmed from repository or runtime evidence before use.

## Project Summary

GamePedia is a native iOS game-discovery and personal-library client. Repository evidence confirms browsing, search, game detail, reviews/discussions, favorites, Steam-backed library flows, social/profile features, AI-assisted discovery, notifications, and widgets. Product intent beyond the implemented behavior is `UNRESOLVED`.

## Product and Users

See `docs/PRODUCT.md` and `docs/GAMEPEDIA_2_BASELINE.md`. The implemented audience is people who discover games and track/review play activity; validated personas, analytics, and market requirements are `UNRESOLVED`.

## Technology Stack

- Swift 5 language setting, iOS 17 deployment target
- UIKit application UI; SwiftUI/WidgetKit in widget and translation-host surfaces
- Combine and Swift structured concurrency
- Coordinator navigation; MVI-style Intent/Mutation/State/Reducer presentation features
- UseCase/Repository/DataSource boundaries
- URLSession, Security/Keychain, UserDefaults, Firebase Messaging, Google Sign-In, Kingfisher
- Ruby/Fastlane for release automation

## Repository Structure

- `GamePedia/Application`: configuration, app/tab coordinators, deep links, push, Steam-link flow, widget refresh
- `GamePedia/Presentation`: UIKit feature screens and MVI presentation types
- `GamePedia/Domain`: entities, repository protocols, use cases, domain services
- `GamePedia/Data`: repositories, data sources, DTOs/mappers, API client/endpoints, local stores
- `GamePedia/Core` and `GamePedia/Shared`: cross-feature platform and shared types
- `GamePediaWidgetExtension`: WidgetKit widgets sharing app-group snapshots
- `GamePediaTests`, `GamePediaUITests`: XCTest targets
- `Config`, shared Xcode schemes, and `fastlane`: environment/release configuration

## Architecture and Dependency Rules

See `docs/ARCHITECTURE.md`. Preserve the intended direction `Presentation -> Domain protocols/use cases <- Data implementations`; composition currently happens mainly in coordinators. Do not move platform navigation into domain types or expose backend DTOs as domain models. Some features bypass a strict boundary and use `APIClient` directly; classify and migrate deliberately rather than copying that pattern.

## State and Data Ownership

- PostgreSQL/Core Server is authoritative for accounts, reviews, favorites, social state, library status, notifications, and AI usage/logs.
- IGDB responses proxied by Core Server are authoritative for canonical game metadata; Steam is authoritative for linked Steam ownership/recent-play inputs.
- The refresh token and stable push-device identifier are Keychain-backed; the access token is memory-only.
- UserDefaults and app-group snapshots hold local UX/cache/widget state, not canonical server records.

## Confirmed Commands

- Project discovery: `xcodebuild -project GamePedia.xcodeproj -list`
- Resolve packages: `xcodebuild -resolvePackageDependencies -project GamePedia.xcodeproj -scheme GamePedia-Dev`
- Simulator build candidate: `xcodebuild -project GamePedia.xcodeproj -scheme GamePedia-Dev -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
- Simulator unit-test candidate: `xcodebuild -project GamePedia.xcodeproj -scheme GamePedia-Dev -destination 'platform=iOS Simulator,name=<installed simulator>' CODE_SIGNING_ALLOWED=NO test`
- Format/lint/full verification: `UNRESOLVED` — no canonical repository command was found.

Commands marked candidate require execution evidence in the current environment before being reported as successful. See `docs/VERIFICATION.md`.

## AI Workflow Policy

- Default workflow tier: Tier 2; use Tier 3 for cross-repository architecture, API contracts, auth/security, migrations, deployment, or release work.
- High-risk paths: auth/token storage, account deletion, privacy/moderation, push routing, deep links, environment selection, signing/release, cross-repository API changes, and concurrency-driven state synchronization.
- Claude planning/review is manual and requires explicit scope approval. Claude implementation remains disabled unless explicitly selected and isolated.
- Exclude `.git`, `.env*`, credentials, provisioning/signing material, Google service credentials, private keys/certificates, tokens, `DerivedData`, and `build` artifacts from external-model context.
- Final verification owner: a Codex Final Verifier context separate from Builder and Challenger.

## Security and Compatibility Constraints

- Never add server secrets to the client or documentation.
- Preserve bearer-token redaction. Debug token logging in `DefaultAuthRepository` is a confirmed security debt and must not be enabled in distribution builds.
- Preserve iOS 17 compatibility unless a product decision changes it.
- Preserve guest-mode gating and app/widget app-group compatibility when changing navigation, auth, or models.
- API and push/deep-link changes require coordinated backend/iOS/Android contract verification.

## Files and Directories That Must Not Be Modified for Planning Tasks

Production Swift, Xcode project settings, schemes, entitlements, signing files, generated resources, and assets. Planning/adoption work is limited to `AGENTS.md`, `CLAUDE.md`, and `docs/` unless the user expands scope.

## Known Environment Limitations

- Signing, TestFlight, push delivery, Apple/Google login, Steam callbacks, and external API behavior require credentials and external systems.
- Simulator success does not verify physical-device Keychain, push, widgets, Universal Links/custom schemes, or Sign in with Apple.
- The related backend working tree contains user-owned untracked duplicate files; never delete or normalize them without explicit approval.

## Project-Specific Completion Requirements

Use traceable requirements; reconcile iOS endpoints with registered server routes; review all docs as a single cross-platform set; report static/build/runtime/UI/external evidence independently; and never call the modernization plan production-verified without real iOS, backend, and contract execution.
<!-- ai-development-system:end -->
