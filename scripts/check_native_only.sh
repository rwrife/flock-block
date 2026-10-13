#!/usr/bin/env bash
# Native-framework contract (issue #1): SwiftUI/UIKit/SpriteKit only.
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
for file in pubspec.yaml ProjectVersion.txt Podfile package.json build.gradle build.gradle.kts; do
  found=$(find . \( -name .git -o -name DerivedData -o -name .build -o -name node_modules \) -prune \
    -o -type f -name "$file" -print)
  if [ -n "$found" ]; then
    echo "::error::prohibited cross-platform manifest found: $found"
    fail=1
  fi
done
if grep -RnE --include='*.swift' --exclude-dir=.build \
  '^import[[:space:]]+(Unity|Flutter|React|Expo|Kotlin|Maui)' App UITests Packages; then
  echo "::error::cross-platform import in Swift sources"
  fail=1
fi
[ "$fail" -eq 0 ] || exit 1
echo "Native-only gate: PASS"
