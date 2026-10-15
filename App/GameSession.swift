import FlockKit
import Observation
import SwiftUI
import UIKit

enum WavePhase: Equatable {
    case idle, running, finished
}

/// Drives one fixed tutorial wave: engine ticks, scene frames, haptics.
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
    private(set) var announcement = ""
    var selectedKind: BlockerKind?
    weak var scene: FlockFieldScene?

    private var wave: WaveEngine?
    private var runLoop: Task<Void, Never>?
    private let haptics = UIImpactFeedbackGenerator(style: .medium)

    var statusLine: String {
        if phase == .finished { return resultsSummary }
        if !announcement.isEmpty { return announcement }
        return phase == .idle ? "Tap Start wave" : "Wave running — pick a blocker, then a lane"
    }

    var resultsSummary: String {
        "Wave complete — score \(score) · \(bonks) bonks · \(escapes) escapes"
    }

    func toggleSelection(_ kind: BlockerKind) {
        guard phase == .running else { return }
        selectedKind = selectedKind == kind ? nil : kind
    }

    func startWave() {
        guard let engine = try? WaveEngine(plan: .tutorialFixture) else { return }
        wave = engine
        score = 0
        bonks = 0
        escapes = 0
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

    func placeBlocker(_ kind: BlockerKind, lane: Int) {
        guard phase == .running, var engine = wave else { return }
        do {
            try engine.place(kind, in: lane)
            wave = engine
            announcement = "\(kind.displayName) in lane \(lane + 1)"
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
        if events.contains(where: {
            if case .bonk = $0.result { return true }
            return false
        }) {
            haptics.impactOccurred()
        }
        render()
        if engine.isFinished {
            phase = .finished
            selectedKind = nil
            runLoop?.cancel()
            runLoop = nil
        }
    }

    private func render() {
        guard let engine = wave else { return }
        // Row 6 is the escape line; normalise so a blocker sits mid-field.
        let escapeRow = 6
        let birds = engine.activeBirds.map { bird in
            FlockBirdView(id: bird.id, lane: bird.lane, speed: bird.speed,
                          progress: Double(bird.position + bird.speed) / Double(escapeRow))
        }
        let blockers = engine.blockedLanes.map {
            FlockBlockerView(kindRaw: $0.kind.rawValue, lane: $0.lane, cooling: $0.cooling)
        }
        let incoming = engine.incomingBirds.map { ($0.lane, $0.ticksAway) }
        scene?.updateWave(birds: birds, blockers: blockers, incoming: incoming)
    }
}
