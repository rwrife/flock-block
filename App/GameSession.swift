import FlockKit
import Observation
import SwiftUI
import UIKit

enum WavePhase: Equatable {
    case idle, running, finished
}

/// Drives a deterministic wave ladder: engine ticks, scene frames, haptics.
/// Placement funnels through `FlockWorkspaceLayout` so a future iPhone Duo
/// split changes that seam, not the game.
@MainActor
@Observable
final class WaveSession {
    static let tickSeconds: TimeInterval = 0.25

    let layout = FlockWorkspaceLayout()
    private(set) var phase: WavePhase = .idle
    private(set) var score = 0
    private(set) var bonks = 0
    private(set) var escapes = 0
    private(set) var energy = 12
    private(set) var bonusReleases = 0
    private(set) var progress = GameProgress()
    private(set) var settings = GameSettings()
    private(set) var storageLocked = false
    private(set) var storageMessage = ""
    private(set) var announcement = ""
    var selectedKind: BlockerKind?
    weak var scene: FlockFieldScene?

    private var wave: WaveEngine?
    private var runLoop: Task<Void, Never>?
    private let haptics = UIImpactFeedbackGenerator(style: .medium)
    private let store: ProgressStore

    init(store: ProgressStore = .defaultStore()) {
        self.store = store
        if ProcessInfo.processInfo.arguments.contains("-ui-reset") {
            try? store.deleteAll()
        } else {
            do {
                let loaded = try store.load()
                progress = loaded.progress
                settings = loaded.settings
            } catch SaveError.missingFile {
                // First launch: fresh progress, nothing to load.
            } catch {
                // Corrupt/unreadable save: run fresh in memory but refuse to
                // overwrite the file until the user deletes or restores it.
                storageLocked = true
                storageMessage = "Saved data could not be read. Export or delete it in Settings to unlock saving."
            }
        }
    }

    /// Current state as export bytes; nil while storage is being repaired.
    func exportData() -> Data? {
        try? ProgressSave(progress: progress, settings: settings).encode()
    }

    @discardableResult func applyImport(_ save: ProgressSave) -> Bool {
        do {
            try store.restore(save.encode())
            progress = save.progress
            settings = save.settings
            storageLocked = false
            storageMessage = ""
            return true
        } catch {
            storageMessage = "Import failed — current save untouched"
            return false
        }
    }

    @discardableResult func deleteAllData() -> Bool {
        do {
            try store.deleteAll()
            progress = GameProgress()
            settings = GameSettings()
            storageLocked = false
            storageMessage = ""
            phase = .idle
            runLoop?.cancel()
            runLoop = nil
            wave = nil
            selectedKind = nil
            return true
        } catch {
            storageMessage = "Delete failed — nothing changed"
            return false
        }
    }

    func updateSettings(hapticsEnabled: Bool) {
        settings.hapticsEnabled = hapticsEnabled
        persist()
    }

    var statusLine: String {
        if phase == .finished { return resultsSummary }
        if !announcement.isEmpty { return announcement }
        return phase == .idle
            ? "Tap Start wave. Green rings: let them through for a bonus."
            : "Wave running — pick a blocker, then a lane"
    }

    var resultsSummary: String {
        "Wave complete — score \(score) · \(bonks) bonks · \(escapes) escapes"
            + (bonusReleases > 0 ? " · \(bonusReleases) bonus \(bonusReleases == 1 ? "release" : "releases")" : "")
            + " · +\(coinsEarned) coins"
    }

    var coinsEarned: Int { score / 5 }

    var hudLine: String {
        "Wave \(progress.level) · Energy \(energy) · Score \(score) · Coins \(progress.coins)"
    }

    func isUnlocked(_ kind: BlockerKind) -> Bool { progress.unlocked.contains(kind) }

    func laneSummary(_ lane: Int) -> String {
        guard let wave else { return "No active wave" }
        let blocker = wave.blocker(in: lane)?.displayName ?? "empty"
        let birds = wave.activeBirds.filter { $0.lane == lane }.count
        let incoming = wave.incomingBirds.filter { $0.lane == lane }.count
        return "\(blocker) blocker, \(birds) birds, \(incoming) incoming"
    }

    var selectionSummary: String {
        selectedKind.map { "Selected \($0.displayName); tap a lane to place it" }
            ?? "Select a blocker, then tap a lane"
    }

    func toggleSelection(_ kind: BlockerKind) {
        guard phase == .running, isUnlocked(kind) else { return }
        selectedKind = selectedKind == kind ? nil : kind
    }

    func startWave() {
        guard let plan = try? WaveLadder.plan(for: progress.level),
              let engine = try? WaveEngine(plan: plan, energy: WaveLadder.energy(for: progress.level))
        else { return }
        wave = engine
        score = 0
        bonks = 0
        escapes = 0
        bonusReleases = 0
        energy = engine.energy
        announcement = ""
        selectedKind = nil
        scene?.resetWave()
        phase = .running
        render()
        runLoop?.cancel()
        runLoop = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(WaveSession.tickSeconds))
                guard !Task.isCancelled, let self, self.phase == .running else { break }
                self.tick()
            }
        }
    }

    /// Tray unlock button. Coins come only from finished waves — no purchase API.
    func unlock(_ kind: BlockerKind) {
        guard phase != .running else { return }
        if progress.unlock(kind) {
            persist()
            announcement = "\(kind.displayName) unlocked — \(progress.coins) coins left"
            haptic(style: .rigid)
        } else {
            announcement = "\(kind.displayName) needs \(kind.unlockCost) coins — finish waves to earn"
        }
    }

    func replayWave() {
        startWave()
    }

    func playNextWave() {
        guard phase == .finished else { return }
        progress.nextWave()
        persist()
        startWave()
    }

    func placeBlocker(_ kind: BlockerKind, lane: Int) {
        guard phase == .running, isUnlocked(kind), var engine = wave else { return }
        do {
            try engine.place(kind, in: lane)
            wave = engine
            announcement = "\(kind.displayName) in lane \(lane + 1)"
            haptic(style: .light)
            render()
        } catch {
            announcement = "Lane blocked — pick another"
        }
    }

    /// Drag-release from the tray: the layout seam decides whether the drop
    /// point is a field lane at all, so tray chrome never steals placements.
    func drop(kind: BlockerKind, at point: CGPoint, in size: CGSize) {
        guard phase == .running else { return }
        guard let lane = layout.lane(atX: Double(point.x), y: Double(point.y),
                                     width: Double(size.width), height: Double(size.height))
        else {
            announcement = "Drop on a field lane"
            return
        }
        if selectedKind != kind { selectedKind = kind }
        placeBlocker(kind, lane: lane)
    }

    func tapLane(_ lane: Int) {
        guard phase == .running else { return }
        guard let kind = selectedKind else {
            announcement = "Pick a blocker first"
            return
        }
        placeBlocker(kind, lane: lane)
    }

    private func tick() {
        guard phase == .running, var engine = wave else { return }
        let events = engine.advance()
        wave = engine
        score = engine.score
        bonks = engine.bonks
        escapes = engine.escapes
        energy = engine.energy
        bonusReleases = engine.bonusReleases
        if events.contains(where: {
            if case .bonk = $0.result { return true }
            return false
        }) {
            haptic(style: .medium)
        }
        render()
        if engine.isFinished {
            progress.finish(score: engine.score, coinsEarned: engine.coinsEarned)
            persist()
            phase = .finished
            selectedKind = nil
            announcement = ""
            runLoop?.cancel()
            runLoop = nil
        }
    }

    /// Settings-gated haptics: off means silence, never vibration.
    private func haptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard settings.hapticsEnabled else { return }
        if style == .medium {
            haptics.impactOccurred()
        } else {
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
    }

    /// Durability path: called after every persisted-progress mutation. A
    /// corrupt-save lock blocks writes so repair (import/delete) is explicit.
    private func persist() {
        guard !storageLocked else { return }
        do {
            try store.save(ProgressSave(progress: progress, settings: settings))
        } catch {
            storageLocked = true
            storageMessage = "Could not write your save. Data stays in memory; export or delete it in Settings."
        }
    }

    private func render() {
        guard let engine = wave else { return }
        // Row 6 is the escape line; normalise so a blocker sits mid-field.
        let escapeRow = 6
        let birds = engine.activeBirds.map { bird in
            FlockBirdView(id: bird.id, lane: bird.lane, speed: bird.speed, gated: bird.gated,
                          progress: Double(bird.position + bird.speed) / Double(escapeRow))
        }
        let blockers = engine.blockedLanes.map {
            FlockBlockerView(kindRaw: $0.kind.rawValue, lane: $0.lane, cooling: $0.cooling)
        }
        let incoming = engine.incomingBirds.map { ($0.lane, $0.ticksAway, $0.gated) }
        scene?.updateWave(birds: birds, blockers: blockers, incoming: incoming)
    }
}
