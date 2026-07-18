#!/bin/bash
# Architecture dependency rules for the GamePedia iOS target.
#
# The app is a single Xcode target, so layering is enforced by convention.
# This script turns the conventions the codebase already follows into
# failing checks. Rules are deliberately narrow and textual: they only
# assert facts that hold today, so a failure always means a new violation.
#
# Layers (dependency direction: top may use bottom, never the reverse):
#   Application / Presentation
#   Domain
#   Data
#   Core (shared infrastructure; UI-facing helpers may use UIKit)
#
# Usage: scripts/check-architecture.sh   (exit 0 = clean)

set -u
cd "$(dirname "$0")/.."

FAILURES=0

fail() {
    echo "ARCH VIOLATION: $1"
    echo "$2"
    FAILURES=$((FAILURES + 1))
}

# Rule 1: Domain must stay UIKit-free (pure entities/use cases).
DOMAIN_UIKIT=$(grep -rln "^import UIKit" GamePedia/Domain 2>/dev/null)
if [ -n "$DOMAIN_UIKIT" ]; then
    fail "Domain imports UIKit" "$DOMAIN_UIKIT"
fi

# Rule 2: Data must stay UIKit-free (network/persistence only).
DATA_UIKIT=$(grep -rln "^import UIKit" GamePedia/Data 2>/dev/null)
if [ -n "$DATA_UIKIT" ]; then
    fail "Data imports UIKit" "$DATA_UIKIT"
fi

# Rule 3: Domain must not reach into Data implementations.
# Default* concrete repositories are Data-layer; Domain sees protocols only.
# (Use-case files may reference them solely as default-argument factories —
# the pattern the codebase already uses everywhere — so this rule targets
# stored-property/inheritance references via the "any Default" and
# ": Default" shapes that would couple Domain types to Data types.)
DOMAIN_DATA=$(grep -rn "any Default[A-Za-z]*Repository\b\|: *Default[A-Za-z]*Repository\b" GamePedia/Domain 2>/dev/null | grep -v "= *Default")
if [ -n "$DOMAIN_DATA" ]; then
    fail "Domain type-couples to Data concrete repositories" "$DOMAIN_DATA"
fi

# Rule 4: Core must not depend on Presentation or feature view models.
CORE_PRESENTATION=$(grep -rn "ViewModel\b\|ViewController\b" \
    GamePedia/Core/RequestCoordination \
    GamePedia/Core/Pagination \
    GamePedia/Core/Images \
    GamePedia/Core/Observability \
    GamePedia/Core/Realtime \
    GamePedia/Core/Sync 2>/dev/null \
    | grep -v "^.*://" | grep -v "\.swift:.*//")
if [ -n "$CORE_PRESENTATION" ]; then
    fail "Core infrastructure references Presentation types" "$CORE_PRESENTATION"
fi

# Rule 5: Presentation features must not import each other's view
# controllers across feature folders via file-scope subclassing.
# Narrow, reliable subset: nothing outside Presentation/Common may
# subclass another feature's ViewController.
CROSS_FEATURE=$(grep -rn "class .*: .*\(Friend\|Search\|Home\|Library\|Profile\|Review\|GameDetail\|Notifications\)[A-Za-z]*ViewController\b" \
    GamePedia/Presentation 2>/dev/null \
    | grep -v "BaseViewController" \
    | awk -F: '{ split($1, path, "/"); feature=path[3]; if (index($0, feature"ViewController") == 0) print }' \
    | grep -v "^$")
# Same-folder subclassing is fine; the awk above keeps only cross-feature hits.
if [ -n "$CROSS_FEATURE" ]; then
    fail "Cross-feature ViewController subclassing" "$CROSS_FEATURE"
fi

# Rule 6: no raw print of URLs with query values in Core request
# coordination (privacy: keys must stay identifier-based).
COORD_URL_LOG=$(grep -rn "print(.*url" GamePedia/Core/RequestCoordination GamePedia/Core/Pagination 2>/dev/null)
if [ -n "$COORD_URL_LOG" ]; then
    fail "Request coordination logs URLs" "$COORD_URL_LOG"
fi

if [ "$FAILURES" -gt 0 ]; then
    echo ""
    echo "Architecture check failed with $FAILURES violation group(s)."
    exit 1
fi

echo "Architecture check passed."
exit 0
