# Product 2.2 contract provenance

`Sources/GamePediaProduct22API/openapi.json` is a **byte-exact** copy of the
GamePediaCoreServer contract document. It is not edited, reformatted or
regenerated in this repository. If the server publishes a new contract, replace
the file wholesale and update every field below in the same commit.

| Field | Value |
| --- | --- |
| Source server HEAD | `ce083aa9d873c4f9338c0f926cc2cea647c455bf` |
| Source path | `openapi/product-2.2.openapi.json` |
| Source checkout | `/Users/hwangseokbeom/.codex/worktrees/1c7d/GamePediaCoreServer` |
| SHA-256 | `c0c5c0287879b4139306d59ef4951afc2d81d409ba34f24bdc7233e3c0612e27` |
| Synced at (UTC) | 2026-07-31T08:16:26Z |
| Contract `info.version` | 2.2.0 |
| Operations declared | 26 |
| iOS base commit | `6a0e7f558f8338b4ad161defa4e798041aa7c985` |
| Contract implementation commit | `6fbcf094ef45d971ce43e2ea7f5236dc525f199e` |

Verified at sync time: the server checkout was at exactly that HEAD with a clean
working tree, and `shasum -a 256` of the source file matched the value above.

### Revision history

The first sync was server HEAD `a42ef7d0510c39811844293cc4dbebbf55a5da39`
(SHA-256 `c7bb0f48…32de55`). That revision left four operations' 2xx bodies as
a bare `SuccessEnvelope`, which cost the app catalog-search and Playlog
pagination, the Quick Add deep link, and any submission-status screen —
recorded at the time in `docs/product-2.2-contract-gaps.md` rather than worked
around with hand-written DTOs.

Commit `6fbcf094` types all four. The change is purely additive: 19 new
schemas, none removed, no existing schema altered, and the operation set is
unchanged at 26.

## Generator and runtime versions

Pinned with `exact:` in `Package.swift`. A contract client that changes its
decoding behaviour on a patch bump is not a contract client.

| Package | Version | Revision |
| --- | --- | --- |
| swift-openapi-generator | 1.11.1 | `73997cc62c2193d5046e431c9d546119dda14502` |
| swift-openapi-runtime | 1.12.0 | `3d3a8457661daf7fb260ceeb9f0e24e5204ba5fb` |
| swift-openapi-urlsession | 1.3.1 | `08796d36c99ad2318929bfa1d1e40f82194b65cc` |

Version 1.3.1 includes the upstream terminal-event race fix that prevents a
request-body stream from crashing when URLSession delivers overlapping close
events.

Transitive pins are recorded in `Package.resolved`, which is version
controlled. `swift package resolve` must not modify it.

Toolchain used for the initial generation: Xcode 26.6 (17F113), Swift 6.3.3.

## Generator configuration

`Sources/GamePediaProduct22API/openapi-generator-config.yaml`:

```yaml
generate:
  - types
  - client
accessModifier: public
namingStrategy: defensive
```

## What is and is not checked in

Checked in: the OpenAPI document, the generator config, `Package.swift`,
`Package.resolved`, and the hand-written client factory.

**Not** checked in: `Types.swift`, `Client.swift`, `Server.swift`. Those are
produced by the `OpenAPIGenerator` build plugin on every build, from the
document above. Committing a generated snapshot would let the checked-in Swift
types drift away from the contract without anything failing, which is exactly
the failure mode this package exists to prevent.

The generated types and the generated operation client are the **only** DTOs at
the network boundary. Nothing in the app hand-writes a `Codable` mirror of a
Product 2.2 schema; the app converts generated types into domain entities
through explicit mappers and never lets a generated type escape the data layer.

## Notes on how the generator read this document

Two contract shapes are worth recording because the app's mappers depend on
what the generator did with them:

* `TodaySection` is a `oneOf` of eight section schemas whose `key` property is
  a distinct `const`. The generator recognised that as a discriminator and
  emits a `key`-switched decoder, so a section always decodes as the case its
  `key` names — mis-decoding one section type as another is not possible.
* Each section schema is itself a `oneOf` of an `ok` variant (non-null `data`)
  and a `disabled`/`unavailable` variant (`data: null`). Those two share the
  same `key` const, so the generator emits an ordered `case1`/`case2` decoder.
  `case1` requires a non-null `data`, so a `data: null` section falls through
  to `case2` deterministically. `TodayFeedFixtureTests` covers both directions.

## Verification

`scripts/verify-product22-contract.sh` (repo root) re-checks the SHA-256, the
26 operationIds, that the eight Today section schemas are reachable from the
Today response, that `editorialCuration.data.articles` resolves to
`ArticleSummary`, and that the package builds warning-free.
