# Flock Block — build plan

## Scope and architecture

Small, original arcade game: one hand places blockers to stop incoming flocks; waves escalate with readable patterns and an occasional release-for-bonus dilemma. No franchise art, names, sound, gameplay clones, or copied assets. Bird impacts are comical, never violent.

**Platform contract:** native Swift + SwiftUI/UIKit menus with first-party SpriteKit gameplay; iPhone-only on iOS 26 SDK or newer, Xcode 26.0.1 (17A400), Swift 6, deployment target 26.0. Android and native iPad support out of scope. Every app target MUST set `TARGETED_DEVICE_FAMILY = 1` and generator equivalents; verify built `UIDeviceFamily = [1]` on Apple CI. Native iPad support is disabled unless user explicitly opts in; iPad compatibility mode is not native iPad support. `PRODUCT_BUNDLE_IDENTIFIER = com.infinityball.flockblock` in every config/target; no other prefix. No Flutter, React Native, Expo, Kotlin Multiplatform, .NET MAUI, Unity, or cross-platform/hybrid engine.

**Core components:** pure Swift `WaveEngine` (deterministic seed, lane/timing rules, collisions, score, unlock thresholds); SpriteKit scene for render/input; SwiftUI shell for menus/settings/results; save model under app container. One `FlockWorkspaceLayout` seam owns game-field bounds, tray bounds, touch-map coordinates so a future Duo mode can split output across screens without changing rules. Do not import imaginary fold APIs now. Accessibility: VoiceOver labels on tray/menus, high-contrast telegraphs, Dynamic Type for menus, reduce-motion mode, haptic alternatives. Touch targets >=44pt. Sound optional/off by default.

**Data:** local save: levels, score, currency, owned blockers, settings. Atomic write and schema version; JSON export/import through share sheet/file importer with confirmation; delete-all. No network calls; `network_allowlist: []`. No accounts, analytics, ads, IAP. Notification permission only if optional local daily reminder added later. No medical claims or data.

## Milestones / dependency order

1. **Foundation (#1):** Xcode project, pin SDK, app target, source-only CI contract gate, simulator build/test lane; enforce bundle/device family.
2. **Wave engine (#2):** seeded 4-lane state machine; spawn patterns, blocker placement, collision/score, replay tests. Start with wall/trampoline/tar.
3. **Playable field (#3):** SpriteKit field and one-thumb placement, touch feedback, results; bounded memory/frame budget.
4. **Depth (#4):** remaining 3 blocker types, dilemma gates, coin unlocks, escalating wave ladder; deterministic rules/tests.
5. **UI/assets/accessibility (#5):** SwiftUI flow, `FlockWorkspaceLayout` seam, VoiceOver/reduce-motion/Dynamic Type. Review `AppStore/description.txt` vs shipped capabilities; generate REAL `AppStore/icon.png` with `hermes-image-gen`, wire into Xcode asset catalog. No placeholder or model substitution.
6. **Save/privacy (#6):** atomic local save, JSON export/import/delete, migration tests, optional reminder permission.
7. **Release (#7):** macos-26 Xcode pinned build/tests, device-family archive check, App Store listing validation, publish Action and TestFlight proof.

## Testing strategy

- Wave engine unit tests: seeded replay, lane bounds, hit/escape scoring, release-for-bonus dilemma, unlock costs, impossible placement/negative balance rejection.
- Save/export tests: schema round trip, corruption leaves previous save untouched, import confirmation, delete-all.
- UI tests: first launch, complete wave, change blocker, VoiceOver menu labels, dynamic type/reduce-motion, resume, export/import.
- CI: pinned macos-26 Apple build and simulator tests. Linux syntax/config checks alone never count as iOS build. Require target build settings and built Info.plist `UIDeviceFamily == [1]`; CI should fail if target becomes universal. No iPad screenshots, iPad UI, or iPad-specific tests for MVP.
- Performance: sample repeatable 2-minute wave on a real iPhone before claiming frame rate; no imagined benchmark.

## Packaging and distribution

`com.infinityball.flockblock` is registered with App Store Connect. `AppStore/description.txt` is scaffolded planned-feature copy; validate every present-tense feature before submission. Real `AppStore/icon.png` required: generate with `hermes-image-gen` after analyzing repo + copy, square opaque edge-to-edge colorful artwork, no text/borders/baked radius; wire into Xcode app-icon asset catalog and inspect output. If model unavailable leave issue open; no placeholder icon.

Port `rwrife/cook-console` `.github/workflows/release.yml` (green in rise-log/split-slip/catch-tally): `v*` tag or manual dispatch on macos-26 → enforce iOS 26+ SDK → install mode-600 ASC key → sign/archive/export IPA with `com.infinityball.flockblock` → upload TestFlight through ASC API → wait for processing → GitHub release. Use repo secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`, `ASC_TEAM_ID` by name; do not log values. No novel signing flow. TestFlight submission is not App Store approval. Do not claim upload until live ASC evidence exists.

## Dual-screen target / risk

Top display threat field + bottom persistent blocker tray makes touching controls independent of flock motion. Current standard iPhone app combines both in portrait; future public fold SDK can split views via `FlockWorkspaceLayout` and preserve wave state across fold/unfold. Native iPad support remains disabled. Risks: Apple dual-screen API unknown; SpriteKit touch coordinates must not drift when geometry changes; playful art must be original; level pacing must be tested with real players. No speculative SDK calls.

## Explicit non-goals

No Android, native iPad, Flutter, React Native, Expo, Kotlin Multiplatform, .NET MAUI, Unity, multiplayer, cloud sync, ads, IAP, subscriptions, hosted accounts, violence, push marketing, or native fold API until public support exists. Keep single-player offline gameplay as entire MVP.
