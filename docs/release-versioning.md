# Release Versioning And Environment Guide

GamePedia uses `dev -> staging -> main`, but version and build numbers are not the source of truth by themselves.

## Branch roles

- `dev`: feature development and daily debugging. Default runtime is `GamePedia-Dev` + `Debug`, which points to `http://127.0.0.1:3001`.
- `staging`: pre-release QA and TestFlight beta distribution. `GamePedia-Staging` + `Staging` points to `https://staging-gamepedia-api.duckdns.org`.
- `main`: production release validation and App Store Connect upload. `GamePedia-Prod` + `Release` points to `https://gamepedia-api.duckdns.org`.

## What each distributed build sees

- Staging beta builds use the `GamePedia-Staging` scheme and `Staging` configuration, so they target the staging API.
- Main release builds use the `GamePedia-Prod` scheme and `Release` configuration, so they target the production API.
- A healthy production server does not prove that a staging beta build will show production data.

## Source of truth for version and build

- `project.pbxproj` contains committed fallback values, but CI can overwrite them before archive/upload.
- `fastlane/Fastfile` updates `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` at build time.
- GitHub Actions passes `RELEASE_VERSION` and optional `RELEASE_BUILD_NUMBER` into Fastlane.
- If no production build number override is provided, Fastlane resolves the next number from App Store Connect.

## Why App Store Connect numbers alone are not enough

- `1.3.1(2)` only tells you the uploaded marketing version and build number.
- It does not prove whether the archive came from `staging` or `main`.
- It also does not prove which API the app is targeting, because CI can rewrite version/build without changing the branch's committed `project.pbxproj` values.

## Actual build identification rules

Use these signals together:

1. App launch logs:
   - `[BuildInfo] version=... build=... scheme=... configuration=... environment=...`
   - `[BuildInfo] apiBaseURL=...`
   - `[BuildInfo] THIS BUILD TARGETS ...`
2. Home API logs:
   - `[HomeAPI][staging] ...`
   - `[HomeAPI][production] ...`
3. Workflow context:
   - `ios-beta.yml` means staging -> TestFlight
   - `ios-main-release.yml` means main -> App Store Connect production upload
   - `ios-main-validate.yml` means production archive validation only

## Operating rules

- Treat staging TestFlight builds as staging verification only.
- Treat main release uploads as production verification candidates.
- Do not infer production behavior from a beta build just because the version number looks newer.
- When checking a reported issue, confirm the app's runtime environment first, then the API base URL, then the workflow that produced the build.
