#!/usr/bin/env bash
# Release-contract gate (issue #7, Linux side).
#
# Mirrors — without an Apple toolchain — the invariants the TestFlight
# release workflow asserts on macOS:
#   1. VERSION file == MARKETING_VERSION in every app build configuration.
#   2. App bundle id is exactly com.infinityball.flockblock everywhere
#      (UITests runner may carry the .uitests suffix).
#   3. TARGETED_DEVICE_FAMILY is 1 in every configuration (iPhone only).
#   4. release.yml exists, triggers on v* tags + dispatch, runs macos-26,
#      references the four ASC secret NAMES, and never interpolates a
#      secret value into an echo/run string beyond the sanctioned patterns.
#   5. Tools/asc_jwt.rb exists and is the JWT minter the workflow calls.
set -euo pipefail
cd "$(dirname "$0")/.."

PBX=FlockBlock.xcodeproj/project.pbxproj
fail=0
err() { echo "::error::$*"; fail=1; }

# 1. VERSION vs MARKETING_VERSION
[ -f VERSION ] || err "VERSION file missing"
version="$(tr -d '[:space:]' < VERSION)"
marketing=$(grep -o 'MARKETING_VERSION = [^;]*;' "$PBX" | sed 's/MARKETING_VERSION = //; s/;//' | sort -u)
if [ "$marketing" != "$version" ]; then
  err "VERSION ($version) != MARKETING_VERSION in project ($marketing)"
fi

# 2. Bundle id
ids=$(grep -o 'PRODUCT_BUNDLE_IDENTIFIER = [^;]*;' "$PBX" | sed 's/PRODUCT_BUNDLE_IDENTIFIER = //; s/;//' | sort -u)
for id in $ids; do
  case "$id" in
    com.infinityball.flockblock|com.infinityball.flockblock.uitests) ;;
    *) err "unexpected PRODUCT_BUNDLE_IDENTIFIER: $id" ;;
  esac
done

# 3. iPhone-only
bad=$(grep -E 'TARGETED_DEVICE_FAMILY = [^1;]' "$PBX" || true)
[ -z "$bad" ] || err "non-iPhone TARGETED_DEVICE_FAMILY found: $bad"
count=$(grep -c 'TARGETED_DEVICE_FAMILY = 1;' "$PBX")
# app Debug+Release and UITests Debug+Release = 4
[ "$count" -ge 4 ] || err "expected >=4 configs declaring family 1, found $count"

# 4. Workflow shape
WF=.github/workflows/release.yml
[ -f "$WF" ] || err "missing $WF"
grep -q "runs-on: macos-26" "$WF" || err "release workflow must run on macos-26"
grep -q "'v\\*'" "$WF" || err "release workflow must trigger on v* tags"
grep -q "workflow_dispatch" "$WF" || err "release workflow must support workflow_dispatch"
for name in ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_P8 ASC_TEAM_ID; do
  grep -q "secrets.$name" "$WF" || err "release workflow must use secrets.$name"
done
# Secret bodies must never be interpolated into printable strings; only
# presence checks (${!name:-}) and the sanctioned $ASC_KEY_P8 write are legal.
if grep -nE 'echo[^#]*\$\{\{[[:space:]]*secrets\.' "$WF"; then
  err "secret value interpolated into an echo statement"
fi
grep -q 'com.infinityball.flockblock' "$WF" || err "release workflow must target com.infinityball.flockblock"

# 5. JWT minter
[ -f Tools/asc_jwt.rb ] || err "missing Tools/asc_jwt.rb"
grep -q 'Tools/asc_jwt.rb' "$WF" || err "release workflow must call Tools/asc_jwt.rb"

[ "$fail" -eq 0 ] || exit 1
echo "Release-contract gate: PASS (VERSION=$version, bundle ids + iPhone-only + workflow shape verified)"
