# Service Modernization Options

## Versioning decision framework

Do not choose 2.1, 3.0, or another label from engineering effort alone. Decide from user-visible compatibility and product positioning:

- A parity release that adds Android while preserving the iOS/server product may use the current product generation and a platform-specific first Android release; exact marketing label is an owner decision.
- A release that materially changes shared navigation, account behavior, API compatibility, or product proposition warrants a major-version/product-generation decision.
- Backend API versions are independent of app marketing versions and should change only when compatibility requires it.

Current recommendation: do not name the next release yet. Accept scope first, then record the label, compatibility window, and store rollout plan.

## Option A — Android parity release

### Scope

Build a native Android client for the confirmed GamePedia 2.0 flows. Make only backend/iOS changes required for contract compatibility, security, observability, accessibility rules, and reliable multi-client operation. Preserve product behavior and iOS architecture otherwise.

### Benefits

- Directly serves the stated next goal with the lowest coupled change surface.
- Produces real cross-platform learning before broad redesign.
- Lets iOS continue shipping while Android develops in vertical slices.
- Forces valuable contract stabilization without requiring a rewrite.

### Risks and complexity

- Complexity: **High**, because parity spans auth, social, Steam, push, reviews, localization, widgets, and release operations even without redesign.
- Existing UX inconsistencies may be preserved temporarily.
- “Parity” can expand unless acceptance criteria and deferred items are explicit.
- Backend route drift/security/operations gaps must still be addressed.

### Migration/backend/release impact

- Add compatibility aliases or coordinated fixes for confirmed drift; freeze canonical API and push/deep-link contracts.
- Add Android platform support to push-token validation and operational dashboards.
- Release Android through internal/closed/open testing and staged production rollout independently of an iOS release.
- iOS changes should be small, separately releasable contract/security patches.

### Must not be combined

Do not combine first Android production launch with a wholesale iOS architecture migration, major information-architecture redesign, destructive schema migration, auth-provider replacement, or deployment-platform migration.

## Option B — Cross-platform modernization

### Scope

Deliver Android plus selected iOS modernization, API cleanup/versioning, shared design/accessibility/localization rules, broader automated tests, CI/CD improvements, and backend observability/reliability work.

### Benefits

- Establishes stronger long-term platform consistency.
- Removes contract ambiguity and improves release confidence across clients.
- Can reduce duplicated product decisions through shared tokens and behavior specifications.

### Risks and complexity

- Complexity: **Very High**.
- Android critical path becomes coupled to iOS refactoring and backend changes.
- Simultaneous client migrations complicate compatibility, rollback, and fault isolation.
- Architectural modernization can drift into style-driven churn.

### Migration/backend/release impact

- Requires an explicit compatibility layer, endpoint deprecation schedule, migration sequencing, and parallel old/new client support.
- Requires larger staging capacity, observability, contract test coverage, and release coordination.
- Should ship in multiple independently reversible releases, not one “big modernization” event.

### Must not be combined

Do not combine contract breaking changes, database migration, iOS navigation rewrite, Android first launch, and CI/deployment migration in the same production cutover. Separate infrastructure changes from client behavior releases.

## Option C — Full GamePedia next generation

### Scope

Revalidate the proposition using stakeholder/user research and analytics; redesign information architecture and UX; build coordinated iOS/Android experiences; evolve backend capabilities; add only evidence-backed features with clear value.

### Benefits

- Opportunity to address product usefulness rather than only implementation parity.
- Can simplify accumulated flows and establish a coherent new brand/design system.
- May justify new APIs and data models around validated user goals.

### Risks and complexity

- Complexity: **Extreme** and currently under-evidenced.
- Highest schedule, migration, adoption, accessibility, and regression risk.
- Existing working behavior can be lost before new value is validated.
- Repository evidence cannot justify major IA or feature changes by itself.

### Migration/backend/release impact

- Requires discovery research, prototype validation, analytics baseline, content/data migration plan, dual-client compatibility, beta cohorts, support readiness, rollback/feature flags, and staged adoption.
- Backend impact could range from additive APIs to new models, but is `UNRESOLVED` until product decisions exist.

### Must not be combined

Do not combine proposition discovery, final design, both client rewrites, schema replacement, and production migration as one committed scope. Research/prototype validation must precede implementation authorization.

## Comparison

| Criterion | Option A | Option B | Option C |
|---|---|---|---|
| Immediate Android goal | Strongest fit | Fit but delayed/coupled | Weak until discovery completes |
| Product behavior change | Minimal | Limited/managed | Major |
| Backend impact | Compatibility/stability | Cleanup/versioning/observability | Potentially major, unresolved |
| iOS impact | Small required patches | Planned modernization | Major redesign |
| Release risk | High but separable | Very high | Extreme |
| Evidence sufficiency today | Highest | Moderate | Low |
| Reversibility | Highest | Moderate | Lowest |

## Recommendation

Choose **Option A — Android parity release with non-negotiable modernization prerequisites**: contract freeze, logging/privacy remediation, auth/push/deep-link state machines, staging contract tests, minimum observability, backup/restore evidence, and shared design/accessibility/localization rules. This is not “Android at any cost”; these prerequisites make a second client safe.

Preserve Option B as the follow-on program after Android beta evidence identifies the highest-value shared modernization. Preserve Option C as a separately funded discovery initiative only when stakeholder/user evidence justifies changing the proposition.

## Scope decision required

Before naming or scheduling the release, the owner must accept: parity feature set and explicit deferrals; supported Android versions/devices; widget inclusion; compatibility duration; beta cohort; SLOs; security/privacy gates; and independent iOS/backend release boundaries.
