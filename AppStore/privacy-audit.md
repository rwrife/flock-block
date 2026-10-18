# App Store and Privacy Audit — Flock Block

Generated: 2026-10-18

## Artwork verification
- Prompt and API output are recorded above.
- Numerical gate: `scripts/check_icon.py` PASS (1024x1024, no alpha, edge/corner variety).
- Byte comparison: catalog icon SHA-256 matches `AppStore/icon.png` PASS.
- Text / marketing inspection: visual review of rendered PNG is required and cannot be performed by automated pixel scripts alone. Manual review during review cycle.

## 1. App Privacy Declarations (App Store Connect)
- **Data Not Collected**: Flock Block collects, tracks, and transmits NO user data.
- Zero network requests (checked by `scripts/check_zero_network.sh`).
- Zero tracking frameworks or third-party SDKs.
- Zero accounts, logins, telemetry, crash reporters, or analytics.
- Zero in-app purchases, advertisements, or external web views.
- Local saves are stored strictly within the app's local sandbox, with explicit user-initiated JSON export, import, and full deletion.

## 2. Listing Copy Audit (`AppStore/description.txt`)
- Verified against shipping features:
  - Six blockers: wall, trampoline, tar, fan, balloon net, decoy feeder.
  - Four lanes, one-thumb tap controls, wave ladder, earn-only coins, dilemmas.
  - Offline local save with export/import/delete confirmations.
  - VoiceOver labels, Dynamic Type scaling, Reduce Motion static cues, Increased Contrast chrome.
  - Future dual-screen speculation removed; iPad disabled (`TARGETED_DEVICE_FAMILY = 1`).

## 3. App Store Icon
- Source: Generated via `spark-media` OpenAI Images API (`gpt-image-2.5-flare`), prompt brief from issue #5.
- Specs: 1024x1024 square, 8-bit RGB, opaque (no alpha channel / no tRNS chunk), edge-to-edge illustration.
- SHA-256: `846d347e140ab09a07ad25593fb1f6761d7579678fe836659119b31088115a56`
- Wired to:
  - `AppStore/icon.png` (App Store marketing asset)
  - `App/Assets.xcassets/AppIcon.appiconset/icon.png` (Xcode asset catalog)
  - PBXResourcesBuildPhase `Assets.xcassets in Resources`
  - Target build setting `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`
- Validation: Verified by `scripts/check_icon.py` on Linux and Apple CI lanes.
