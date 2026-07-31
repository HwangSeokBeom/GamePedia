#!/usr/bin/env bash
#
# Product 2.2 contract gate.
#
# Fails if the OpenAPI document shipped in the local generated-client package
# is not the exact document the server team published, if the contract lost an
# operation or a schema the app depends on, or if the generated client stops
# building cleanly.
#
# Usage:
#   scripts/verify-product22-contract.sh            # full run
#   SKIP_BUILD=1 scripts/verify-product22-contract.sh   # checks only, no build
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="$REPO_ROOT/Packages/GamePediaProduct22API"
OPENAPI="$PACKAGE_DIR/Sources/GamePediaProduct22API/openapi.json"
CONFIG="$PACKAGE_DIR/Sources/GamePediaProduct22API/openapi-generator-config.yaml"

EXPECTED_SHA256="c0c5c0287879b4139306d59ef4951afc2d81d409ba34f24bdc7233e3c0612e27"
EXPECTED_SERVER_HEAD="ce083aa9d873c4f9338c0f926cc2cea647c455bf"
EXPECTED_OPERATION_COUNT=26

failures=0
pass() { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; failures=$((failures + 1)); }

echo "Product 2.2 contract verification"
echo "---------------------------------"

# ---------------------------------------------------------------- 1. SHA-256
if [ ! -f "$OPENAPI" ]; then
  fail "openapi.json missing at $OPENAPI"
  exit 1
fi
actual_sha="$(shasum -a 256 "$OPENAPI" | awk '{print $1}')"
if [ "$actual_sha" = "$EXPECTED_SHA256" ]; then
  pass "openapi.json SHA-256 matches the published contract"
else
  fail "openapi.json SHA-256 mismatch: expected $EXPECTED_SHA256, got $actual_sha"
fi

# ------------------------------------------------- 2. provenance consistency
if grep -q "$EXPECTED_SHA256" "$PACKAGE_DIR/PROVENANCE.md" \
  && grep -q "$EXPECTED_SERVER_HEAD" "$PACKAGE_DIR/PROVENANCE.md"; then
  pass "PROVENANCE.md records the same server HEAD and SHA-256"
else
  fail "PROVENANCE.md does not record the expected server HEAD / SHA-256"
fi

# ------------------------------------------------- 3. generator configuration
if grep -q '^accessModifier: public' "$CONFIG" \
  && grep -q '^namingStrategy: defensive' "$CONFIG" \
  && grep -q '^  - types' "$CONFIG" \
  && grep -q '^  - client' "$CONFIG"; then
  pass "generator config pins types+client / public / defensive"
else
  fail "generator config drifted from types+client / public / defensive"
fi

# ------------------------------------- 4. pinned generator + runtime versions
if grep -q 'swift-openapi-generator", exact: "1.11.1"' "$PACKAGE_DIR/Package.swift" \
  && grep -q 'swift-openapi-runtime", exact: "1.12.0"' "$PACKAGE_DIR/Package.swift" \
  && grep -q 'swift-openapi-urlsession", exact: "1.3.0"' "$PACKAGE_DIR/Package.swift"; then
  pass "generator/runtime/urlsession pinned exactly (1.11.1 / 1.12.0 / 1.3.0)"
else
  fail "swift-openapi package pins drifted from 1.11.1 / 1.12.0 / 1.3.0"
fi

# --------------------------------------------- 5. contract structural content
python3 - "$OPENAPI" "$EXPECTED_OPERATION_COUNT" <<'PY'
import json, sys

path, expected_count = sys.argv[1], int(sys.argv[2])
doc = json.load(open(path))
problems = []
notes = []

METHODS = ("get", "post", "put", "patch", "delete")
ops = {
    op["operationId"]
    for item in doc["paths"].values()
    for method, op in item.items()
    if method in METHODS
}
if len(ops) == expected_count:
    notes.append(f"{len(ops)} operationIds present in the generation input")
else:
    problems.append(f"expected {expected_count} operations, found {len(ops)}")

REQUIRED_OPS = {
    # user-facing surface the app implements
    "searchCatalogGames", "getCatalogGame", "previewCatalogSubmission",
    "confirmCatalogSubmission", "getCatalogSubmission", "submitCatalogCorrections",
    "followCatalogGame", "unfollowCatalogGame", "listPlaySessions",
    "createPlaySession", "updatePlaySession", "deletePlaySession",
    "getPlayCalendar", "getGameDna", "recommendPlayCompass",
    "recordPlayCompassEvent", "getMonthlyReplay", "getTodayFeed", "getArticle",
    "getProductConfig", "submitProductEvents",
    # editor-only surface: present in the contract, deliberately not built into
    # the consumer app, but its absence would still mean the contract changed
    "listEditorialArticles", "createEditorialArticle", "updateEditorialArticle",
    "publishEditorialArticle", "retractEditorialArticle",
}
missing = REQUIRED_OPS - ops
if missing:
    problems.append("missing operations: " + ", ".join(sorted(missing)))
else:
    notes.append("every expected operationId is declared")

schemas = doc["components"]["schemas"]

def deref(node):
    while isinstance(node, dict) and "$ref" in node:
        node = schemas[node["$ref"].split("/")[-1]]
    return node

# Today response -> TodayFeed -> sections -> all eight section schemas
today_ok = doc["paths"]["/api/v1/users/me/today"]["get"]["responses"]["200"]
today_schema = today_ok["content"]["application/json"]["schema"]
data_schema = None
for part in today_schema.get("allOf", []):
    if "properties" in part and "data" in part["properties"]:
        data_schema = part["properties"]["data"]
if data_schema is None:
    problems.append("Today 200 response does not expose a data schema")
else:
    feed = deref(data_schema)
    section_ref = feed["properties"]["sections"]["items"]
    section = deref(section_ref)
    variants = [v["$ref"].split("/")[-1] for v in section.get("oneOf", [])]
    EXPECTED_SECTIONS = [
        "TodayPlayCompassSection", "TodayGameDnaSection", "TodayGameBriefingSection",
        "TodayBacklogRescueSection", "TodaySpoilerFreeStartGuideSection",
        "TodayEditorialCurationSection", "TodayMonthlyReplaySection",
        "TodayFriendActivitySection",
    ]
    missing_sections = [s for s in EXPECTED_SECTIONS if s not in variants]
    if missing_sections:
        problems.append("Today sections unreachable: " + ", ".join(missing_sections))
    elif len(variants) != 8:
        problems.append(f"expected 8 Today section schemas, found {len(variants)}")
    else:
        notes.append("all 8 Today section schemas reachable from the Today response")

    # every section must offer an ok variant and a data:null variant
    for name in EXPECTED_SECTIONS:
        cases = schemas[name]["oneOf"]
        if len(cases) != 2:
            problems.append(f"{name} does not have exactly 2 variants")
            continue
        ok_case, null_case = cases
        if ok_case["properties"]["status"].get("const") != "ok":
            problems.append(f"{name} first variant is not the ok variant")
        null_data = null_case["properties"]["data"]
        if null_data.get("const", "missing") is not None:
            problems.append(f"{name} disabled/unavailable variant does not pin data to null")
    if not problems:
        notes.append("every section has an ok variant and a data:null variant")

# editorialCuration.data.articles must resolve to ArticleSummary
cur_ok = schemas["TodayEditorialCurationSection"]["oneOf"][0]
cur_data = deref(cur_ok["properties"]["data"])
articles_item = cur_data["properties"]["articles"]["items"]
if articles_item.get("$ref", "").endswith("/ArticleSummary"):
    notes.append("editorialCuration.data.articles resolves to ArticleSummary")
else:
    problems.append("editorialCuration.data.articles does not resolve to ArticleSummary")

# ArticleSummary must NOT carry a body: the app fetches it separately
if "bodyMarkdown" in schemas["ArticleSummary"].get("properties", {}):
    problems.append("ArticleSummary unexpectedly carries bodyMarkdown")
else:
    notes.append("ArticleSummary carries no body (detail is a separate fetch)")

# article detail body format must stay CommonMark-with-HTML-disabled
if schemas["PublicArticle"]["properties"]["bodyFormat"].get("const") != "commonmark-no-html":
    problems.append("PublicArticle.bodyFormat is no longer commonmark-no-html")
else:
    notes.append("PublicArticle.bodyFormat pinned to commonmark-no-html")

# Play Compass must stay owned-only and capped at three
compass = schemas["PlayCompassResponse"]
if compass["properties"]["ownedOnly"].get("const") is not True:
    problems.append("PlayCompassResponse.ownedOnly is no longer pinned true")
elif compass["properties"]["recommendations"].get("maxItems") != 3:
    problems.append("PlayCompassResponse.recommendations is no longer capped at 3")
else:
    notes.append("Play Compass stays owned-only with at most 3 recommendations")

for note in notes:
    print(f"  ok    {note}")
for problem in problems:
    print(f"  FAIL  {problem}")
sys.exit(1 if problems else 0)
PY
if [ $? -ne 0 ]; then failures=$((failures + 1)); fi

# ------------------------------------------------------ 6. warning-free build
if [ "${SKIP_BUILD:-0}" != "1" ]; then
  build_log="$(mktemp)"
  if (cd "$PACKAGE_DIR" && swift build 2>&1) > "$build_log"; then
    if grep -qE '^.*: warning: ' "$build_log"; then
      fail "generated client package built with warnings"
      grep -E '^.*: warning: ' "$build_log" | head -10
    else
      pass "generated client package builds with no warnings"
    fi
  else
    fail "generated client package failed to build"
    tail -20 "$build_log"
  fi
  rm -f "$build_log"
else
  echo "  skip  build (SKIP_BUILD=1)"
fi

echo "---------------------------------"
if [ "$failures" -eq 0 ]; then
  echo "PASS: Product 2.2 contract verified"
  exit 0
fi
echo "FAIL: $failures contract check(s) failed"
exit 1
