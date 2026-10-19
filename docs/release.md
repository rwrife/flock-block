# Flock Block — Release Runbook (TestFlight)

Issue #7 pipeline: a green `main` + a version tag produces a signed TestFlight
build via the App Store Connect API. No fastlane/npm is pinned — the pipeline
is `.github/workflows/release.yml` plus `Tools/asc_jwt.rb` (dependency-free
ES256 JWT minter using the runner's stock openssl/Ruby).

## Secrets (names only — values must never appear in any log)

| Secret | Purpose |
|---|---|
| `ASC_KEY_ID` | App Store Connect API key ID (JWT `kid`) |
| `ASC_ISSUER_ID` | ASC issuer UUID (JWT `iss`) |
| `ASC_KEY_P8` | PKCS#8 EC private key body; written to `$RUNNER_TEMP/asc-api-key.p8` (mode 600), deleted in an `always()` step |
| `ASC_TEAM_ID` | Developer team for automatic signing (`DEVELOPMENT_TEAM`) |

The workflow's first step verifies each secret NAME is present (checking
presence only — it never echoes a value). GitHub's log masking additionally
redacts registered secrets; the pipeline's own rule is "secret variables are
consumed as env inputs only, never interpolated into echo statements."

## Versioning + changelog convention

- `VERSION` (repo root) holds the marketing version `x.y.z` (semver).
- `VERSION` is matched against `MARKETING_VERSION` in
  `FlockBlock.xcodeproj/project.pbxproj`; `scripts/check_release_contract.sh`
  fails Linux CI if the two ever drift apart.
- **Build number = the Actions run number** of the release workflow. It is
  strictly monotonic across every release ever run, so ASC never sees a
  recycled `CFBundleVersion`. `CURRENT_PROJECT_VERSION` in the project is
  only a local baseline (1); the workflow overrides it.
- The tag must equal `v$VERSION`. Mismatch = instant failure, no upload.
- Changelog: `gh release create --generate-notes` anchors each tag with the
  commit history since the previous release; the TestFlight "What to test"
  note is seeded from the tag commit's subject line.

## Icon + launch screen

- App icon: single 1024×1024 universal master at
  `AppStore/icon.png` (byte-identical in `App/Assets.xcassets/AppIcon.appiconset/icon.png`).
  It is a plain square, opaque edge-to-edge graphic; iOS applies the superellipse
  mask itself (no alpha). `scripts/check_icon.py` and CI enforce these constraints.
- Launch screen: `INFOPLIST_KEY_UILaunchScreen_Generation = YES` (system
  default launch screen matching the app background) — no custom storyboard.

## Cutting a release (internal TestFlight group)

1. On `main` (must be green in CI):
   `echo 0.1.1 > VERSION` and update `MARKETING_VERSION` in
   `FlockBlock.xcodeproj/project.pbxproj`, then merge via PR.
   (The initial release uses `v0.1.0`.)
2. Tag and push: `git tag v0.1.0 && git push origin v0.1.0`.
3. Watch `Actions → Release (TestFlight)`:
   archive (pinned iOS 26 SDK, signed `com.infinityball.flockblock`) →
   verify `UIDeviceFamily == [1]` → export (`method=app-store-connect`,
   `manageAppVersionAndBuildNumber=false`) → upload → ASC polling until
   the build is `VALID` or `COMPLETE` → build attached to the **Internal**
   beta group with release notes → GitHub release created.
4. TestFlight: within minutes the build appears for internal testers; the
   run log prints the exact `BUILD_ID` (ASC evidence) and the release
   page links the tag.

`workflow_dispatch` exists for re-runs; it refuses any version that doesn't
match the `VERSION` file, so it can only redo the *current* release.

## Manual checks with the same JWT minter

```bash
export ASC_KEY_FILE=~/private/AuthKey_XXXX.p8 ASC_KEY_ID=XXXX ASC_ISSUER_ID=...
JWT=$(ruby Tools/asc_jwt.rb)
curl -g -sS -H "Authorization: Bearer $JWT" \
  "https://api.appstoreconnect.apple.com/v1/builds?limit=1" | jq '.data[0].id'
```
