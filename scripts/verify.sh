#!/bin/bash
# CI-equivalent local verification for the GamePedia iOS repository.
#
# Mirrors the Fastlane ci_build lane (GamePedia-Dev, Debug, serialized
# tests, signing disabled) plus the repository's standing static checks.
# Tests stay serialized on purpose: the suite is not parallel-safe and
# CI runs it serialized; do not re-enable parallel execution for speed.
#
# Usage:
#   scripts/verify.sh            full run (build + tests + static checks)
#   scripts/verify.sh --static   static checks only (no xcodebuild)
#
# Requires a normal Xcode environment with an available iOS simulator.

set -u
cd "$(dirname "$0")/.."

DESTINATION="${VERIFY_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"
DERIVED_DATA="${VERIFY_DERIVED_DATA:-DerivedData}"
MODE="${1:-full}"
STATUS=0

step() { echo ""; echo "==== $1 ===="; }

# 1. Whitespace hygiene
step "git diff --check"
if ! git diff --check; then
    STATUS=1
fi

# 2. Architecture rules
step "architecture rules"
if ! bash scripts/check-architecture.sh; then
    STATUS=1
fi

# 3. Sensitive-data scan: flags string interpolation of credential-like
# values into print/log calls. Logging lengths/counts/nil-ness of these
# values is the repository's accepted privacy-safe pattern and does not
# match (a property access like `.count` breaks the raw interpolation).
step "sensitive-log scan"
SENSITIVE=$(grep -rniE 'print\(.*\\\((accessToken|refreshToken|authToken|password|authorizationHeader)[^.)]*\)' \
    GamePedia --include="*.swift" 2>/dev/null \
    | grep -v "GamePediaTests")
if [ -n "$SENSITIVE" ]; then
    echo "Potential sensitive logging found:"
    echo "$SENSITIVE"
    STATUS=1
else
    echo "Sensitive-log scan passed."
fi

if [ "$MODE" = "--static" ]; then
    echo ""
    if [ "$STATUS" -eq 0 ]; then echo "STATIC VERIFY PASSED"; else echo "STATIC VERIFY FAILED"; fi
    exit $STATUS
fi

# 4. Serialized unit tests (CI-equivalent; skips UI test targets like CI)
step "xcodebuild test (serialized, unsigned)"
if ! xcodebuild test \
    -project GamePedia.xcodeproj \
    -scheme GamePedia-Dev \
    -configuration Debug \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA" \
    -parallel-testing-enabled NO \
    -maximum-concurrent-test-simulator-destinations 1 \
    -skip-testing:GamePediaUITests \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""; then
    STATUS=1
fi

echo ""
if [ "$STATUS" -eq 0 ]; then echo "VERIFY PASSED"; else echo "VERIFY FAILED"; fi
exit $STATUS
