# Xcode Scheme Workflow

GamePedia iOS branch workflow:

- `dev`: feature work and day-to-day development
- `staging`: stabilization, QA, and release candidate validation
- `main`: production-ready code only

Use schemes by environment, not by branch name:

- `GamePedia-Dev` for local development
- `GamePedia-Staging` for staging verification
- `GamePedia-Prod` for production release validation and archive work

Rules to avoid repeated scheme merge conflicts:

1. Do not casually modify `GamePedia-Prod.xcscheme` during normal development.
2. Daily development should use `GamePedia-Dev` or `GamePedia-Staging`.
3. Keep production scheme changes rare, intentional, and release-focused.
4. If a scheme file must change, isolate that change in a separate commit when possible.
5. Prefer fixing environment behavior through `Debug` / `Staging` / `Release` build configurations and `xcconfig`, not by editing schemes repeatedly.
6. Before merging `dev -> staging` or `staging -> main`, check shared scheme diffs and revert accidental scheme noise.

Practical default:

- Run locally with `GamePedia-Dev`
- Verify staging with `GamePedia-Staging`
- Reserve `GamePedia-Prod` for release checks, archive, and production-only validation
