# Flock Block

**Pitch:** A pocket arcade game for people who want one-handed, one-more-run action: birds fly in at you and YOU place the obstacles — bonk, bounce, or baffle the flock with silly unlockable defenses before they slip through.

Local-first, offline, no accounts, no cloud, no ads, no trackers. Native Swift + SpriteKit, iPhone-only.

## Overview

Flock Block inverts the endless-runner formula. Instead of steering one
vulnerable thing through gaps, you are the obstacle author: flocks of birds
sweep down named lanes and you place, drag, and timing-tune blockers —
springy trampolines, sticky tar patches, spinning fans, cardboard walls — to
stop them getting past your line. Every flock is a small read-and-react
puzzle: which lane, which blocker, which order. The twist is the dilemma
doors: some gates boost your score if you *let* a tagged bird through, so
greedy plays sometimes beat safe plays.

The original design target is the **iPhone Duo dual-screen phone**: flocks and
incoming lanes render on the top screen while your blocker tray, powerups, and
score stay live on the bottom screen as a persistent control surface, so you
never cover the action to arm a defense. Until foldable SDK APIs ship, the
build is a **standard single-screen portrait iPhone app** with a documented
migration path (see [PLAN.md](PLAN.md)).

## Motivation

Idle/arcade charts are full of Flappy-Bird-likes: one tap, one fragile bird,
punishing gaps. The satisfying half of that loop — reading incoming patterns
and owning the space — is exactly what those games take away. A
placement/deflection game flips the player from victim to architect while
keeping the same one-thumb reachability and 30-second session shape. And the
best version of that layout (threat field above, control surface below) is
precisely what a dual-screen phone gives you for free.

## Target users

- Commuters and queue-standers who want one-handed portrait arcade sessions.
- Players who find reflex-timing games unfair but like pattern-reading puzzles.
- Parents and casual players who want colorful, silly, non-violent chaos.

## Concrete use cases

1. **Bus stop run:** Launch, play one 45-second wave with thumb, quit. Best
   score persists locally.
2. **Dilemma decision:** A golden-crested bird is tagged "BONUS +50 if
   released." You block its two lane-mates and open the gate — risky, fun.
3. **Loadout tinkering:** Between waves you unlock and swap blockers (fan vs.
   trampoline) from earned coins; no purchases, no timers.
4. **Future Duo mode:** On a dual-screen device, top shows the flock field,
   bottom shows the tray — same rules, no fingers over the action.

## How to use (intended end-to-end workflow)

1. Launch → single tap to start (no account, no onboarding wall).
2. Flocks enter from the top in lanes; a block line sits near the bottom.
3. Drag blocker icons from the tray onto lanes; tap a placed blocker to
   rotate/charge; collect bonked birds as coins.
4. Wave ends → results card → swap loadout → next wave, or quit anytime.
5. Progress, coins, unlocks, and settings live only on the device; export/
   delete in Settings.

## MVP feature list

- Portrait iPhone-only native Swift + SpriteKit game; single-hand controls.
- 4-lane flock waves with readable telegraphs (incoming lane, size, speed).
- 6 starter blocker types (wall, trampoline, tar patch, fan, balloon net,
  decoy feeder) with distinct placement/timing behavior.
- Dilemma gates: per-wave "release the tagged bird for bonus" prompts.
- Wave ladder with escalating flock patterns; local high-score + stats.
- Coin economy for unlocking blockers (earned only; no IAP, no ads).
- Haptics, VoiceOver-labelled controls, Dynamic Type in menus, reduce-motion
  option.
- Local save (SwiftData/JSON), export/import of save data, full-delete.

## Non-goals

- No accounts, cloud sync, leaderboards, or analytics (privacy posture below).
- No ads, IAP, energy timers, or loot boxes.
- No multiplayer, no push notifications beyond an optional local "daily
  bonus ready" reminder (opt-in).
- No Android and no native iPad support (iPhone-only; iPad needs explicit
  user opt-in). No cross-platform engines: no Flutter, React Native, Expo,
  Kotlin Multiplatform, .NET MAUI, or Unity. SpriteKit is first-party Apple.
- No violence/gore; birds bonk comically and fly off dizzy.
- No native foldable/dual-screen API usage until Apple ships public APIs.

## Privacy, permissions, and data storage

- 100% offline. `network_allowlist: []` — the app makes no network calls.
- No account, no third-party SDKs, no trackers, no advertising identifier.
- All game state (progress, coins, unlocks, scores, settings) stored locally
  via SwiftData/JSON in the app container; visible export (JSON file via the
  share sheet) and full-delete control in Settings.
- Permissions: none required at MVP. Haptics need no permission. Optional
  local notification reminder is opt-in in-app.

## Platform and implementation

- **Native Swift (SwiftUI for menus/settings, SpriteKit for gameplay) — the
  only implementation route.** Prohibited anywhere: Flutter, React Native,
  Expo, Kotlin Multiplatform, .NET MAUI, Unity.
- **iOS 26 SDK or newer** (pinned Xcode 26.0.1, build 17A400, deployment
  target iOS 26.0, Swift language mode 6). Never scaffold against older SDKs.
- **iPhone-only:** `TARGETED_DEVICE_FAMILY = 1` in every app build config;
  built `UIDeviceFamily` must be `[1]`. Native iPad support is disabled;
  Android is out of scope. iPad compatibility mode ≠ native iPad support.
- **Bundle ID:** `com.infinityball.flockblock` — registered in App Store
  Connect (CREATED via ASC API at scaffold time). Matches
  `PRODUCT_BUNDLE_IDENTIFIER` in every target.

## iPhone Duo dual-screen design target and migration path

- **Design target:** top screen = flock field (SpriteKit scene), bottom
  screen = persistent blocker tray, charge meter, score, and dilemma-gate
  prompt. Folded state = today's single-screen portrait layout with tray
  docked over the lower quarter.
- **Current build shape:** standard iPhone app, single portrait scene, tray
  inside the same view. All layout decisions route through a single
  `FlockWorkspaceLayout` seam (scene bounds + tray geometry in one struct),
  so a future dual-screen pass swaps that seam, not the game.
- **Migration path:** when Apple ships public dual-screen/fold APIs, adopt
  them behind the same seam: split scene/tray across displays, preserve
  in-flight wave state across fold transitions, keep folded mode byte-identic
  to today's layout. Until then, no speculative APIs, no iPad idiom, no
  `tablet-friendly` claims.

## Status and milestones

Documentation-only scaffold — no app code exists yet.

1. **M0 Scaffold (this repo):** plan, backlog, toolchain pins. ✔
2. **M1 Playable core:** project skeleton + CI, SpriteKit wave loop, 3
   blockers, block line, score.
3. **M2 Game depth:** 6 blockers, dilemma gates, wave ladder, coins/unlocks.
4. **M3 Polish & assets:** App Store copy + real generated icon
   (`AppStore/icon.png`), haptics, accessibility pass.
5. **M4 Data & release:** save export/import/delete, `.github/workflows/release.yml`
   TestFlight publish Action, App Store submission.
6. **M5 Duo migration (blocked on Apple SDK):** dual-screen layout behind
   `FlockWorkspaceLayout`.

## Development quickstart

Target toolchain (pinned in [`toolchain.json`](toolchain.json)): Xcode
26.0.1 (17A400), iOS 26 SDK, Swift 6, iPhone-only.

```bash
git clone https://github.com/rwrife/flock-block.git
# macOS with the pinned Xcode:
cd flock-block
xcodebuild -project FlockBlock.xcodeproj -scheme FlockBlock \
  -destination 'generic/platform=iOS Simulator' build   # once M1 lands
```

On non-Apple hosts, structural checks and Swift lint only — never claim iOS
build results from Linux.

## Release plan

Signing/TestFlight uses the repo's App Store Connect Actions secrets
(`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`, `ASC_TEAM_ID` — names only,
values never logged). Packaging issue requires porting the proven fleet
template `rwrife/cook-console` `.github/workflows/release.yml`: `v*` tag or
manual dispatch → macos-26 job → iOS 26+ SDK enforcement → signed IPA archive
→ TestFlight upload via the App Store Connect API → ASC processing poll →
GitHub release. No new signing flows.

## License

MIT — see [LICENSE](LICENSE).
