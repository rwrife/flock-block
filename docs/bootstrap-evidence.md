# Bootstrap verification ledger

Issue #1: https://github.com/rwrife/flock-block/issues/1

Current scaffold: SwiftUI one-screen field/tray split; static SpriteKit four-lane markers. No playable wave, placement, bonks, coins, save, icon, signed build, or TestFlight claim. `FlockWorkspaceLayout` is a normalized geometry seam, not dual-screen API support.

Linux verification commands (results reported in PR body):

- `python3 -m unittest discover -s Scripts/tests -v`
- `docker run --rm --user "$(id -u):$(id -g)" -v "$PWD:/work" -w /work swift:6.2-noble swift test --package-path Packages/FlockKit`
- `bash scripts/check_zero_network.sh`
- `bash scripts/check_native_only.sh`
- `bash -n Scripts/ci.sh scripts/check_zero_network.sh scripts/check_native_only.sh`

Native proof: exact-head macos-26 CI run URL and artifact `ios-ci-<SHA>`. Script selects Xcode 26.0.1 (17A400) with iOS SDK 26.0, installs exact matching simulator runtime if missing, builds and tests app on iPhone simulator, then checks built `UIDeviceFamily == [1]` and bundle identifier. No Linux command substitutes for this Apple proof. If native job red, inspect phase and job logs; leave issue/PR open.
