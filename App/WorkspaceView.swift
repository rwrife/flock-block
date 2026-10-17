import FlockKit
import SpriteKit
import SwiftUI

/// Single portrait workspace: field above persistent one-thumb blocker tray.
/// No native dual-screen API or tablet surface is used.
struct WorkspaceView: View {
    @State private var session = WaveSession()
    @State private var scene = FlockFieldScene(size: CGSize(width: 320, height: 460))
    @State private var showingSettings = false

    var body: some View {
        GeometryReader { geometry in
            let fieldHeight = geometry.size.height * session.layout.fieldFraction
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    SpriteView(scene: scene)
                        .accessibilityHidden(true) // SpriteKit art; lane buttons carry actions.
                    HStack(spacing: 0) {
                        ForEach(0..<session.layout.laneCount, id: \.self) { lane in
                            Button {
                                session.tapLane(lane)
                            } label: {
                                Color.clear
                                    .contentShape(Rectangle())
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .accessibilityLabel("Place in lane \(lane + 1)")
                            .accessibilityIdentifier("lane.\(lane + 1)")
                            .disabled(session.phase != .running)
                        }
                    }
                    Text("Four flock lanes")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.black.opacity(0.7), in: Capsule())
                        .allowsHitTesting(false)
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                showingSettings = true
                            } label: {
                                Image(systemName: "gearshape")
                                    .font(.body)
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .background(.black.opacity(0.7), in: Circle())
                            }
                            .accessibilityLabel("Settings and data")
                            .accessibilityIdentifier("settings.open")
                        }
                        Spacer()
                    }
                    .padding(6)
                }
                .frame(height: fieldHeight)

                VStack(spacing: 5) {
                    HStack {
                        Text("Blocker tray")
                            .font(.headline)
                        Spacer()
                        Text("Wave \(session.progress.level) · Energy \(session.energy) · Score \(session.score) · Coins \(session.progress.coins)")
                            .font(.subheadline.monospacedDigit())
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
                        ForEach(BlockerKind.allCases, id: \.self) { kind in
                            trayButton(kind, workspaceSize: geometry.size)
                        }
                    }
                    Text(session.statusLine)
                        .font(.caption)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("wave.status")
                    if session.storageLocked {
                        Text(session.storageMessage)
                            .font(.caption.bold())
                            .foregroundStyle(.red)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("storage.warning")
                    }
                    HStack(spacing: 8) {
                        Button(session.phase == .idle ? "Start wave" : "Replay wave") {
                            session.startWave()
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(.orange, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.black)
                        .accessibilityIdentifier(session.phase == .idle ? "wave.start" : "wave.replay")
                        .disabled(session.phase == .running)
                        if session.phase == .finished {
                            Button("Next wave") {
                                session.playNextWave()
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(.green, in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.black)
                            .accessibilityIdentifier("wave.next")
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.88, green: 0.94, blue: 0.98))
                .frame(height: geometry.size.height * session.layout.trayFraction)
            }
            .coordinateSpace(name: "workspace")
            .onAppear {
                session.scene = scene
            }
            .sheet(isPresented: $showingSettings) {
                SettingsSheet(session: session)
            }
        }
    }
}

extension WorkspaceView {
    /// Unlocked kinds place blockers; locked kinds spend earned coins between
    /// waves. No purchase path exists.
    @ViewBuilder
    private func trayButton(_ kind: BlockerKind, workspaceSize: CGSize) -> some View {
        if session.isUnlocked(kind) {
            Button {
                session.toggleSelection(kind)
            } label: {
                VStack(spacing: 1) {
                    Text(kind.displayName).font(.caption.bold()).minimumScaleFactor(0.7)
                    Text("\(kind.cost) energy").font(.caption2)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(session.selectedKind == kind ? Color.orange : Color.blue,
                            in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.white)
            }
            .accessibilityLabel("\(kind.displayName), \(kind.cost) energy, \(kind.behavior)")
            .accessibilityIdentifier("blocker.\(kind.identifier)")
            .disabled(session.phase != .running || session.energy < kind.cost)
            .simultaneousGesture(
                DragGesture(minimumDistance: 8, coordinateSpace: .named("workspace"))
                    .onEnded { drag in
                        session.drop(kind: kind, at: drag.location, in: workspaceSize)
                    }
            )
        } else {
            Button {
                session.unlock(kind)
            } label: {
                VStack(spacing: 1) {
                    Text(kind.displayName).font(.caption.bold()).minimumScaleFactor(0.7)
                    Text("Unlock \(kind.unlockCost) coins").font(.caption2).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.gray, in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.white)
            }
            .accessibilityLabel("Locked: \(kind.displayName), unlock for \(kind.unlockCost) coins")
            .accessibilityIdentifier("unlock.\(kind.identifier)")
            .disabled(session.phase == .running || session.progress.coins < kind.unlockCost)
        }
    }
}

struct FlockBirdView {
    let id: Int
    let lane: Int
    let speed: Int
    let gated: Bool
    let progress: Double
}

struct FlockBlockerView {
    let kindRaw: Int
    let lane: Int
    let cooling: Bool
}

/// Original geometric field art: no sprite sheets or franchise assets.
/// Deliberately nonisolated like the rest of SpriteKit; the session drives
/// it synchronously from the main actor.
final class FlockFieldScene: SKScene {
    private var birds: [FlockBirdView] = []
    private var blockers: [FlockBlockerView] = []
    private var incoming: [(lane: Int, ticksAway: Int, gated: Bool)] = []

    override func didMove(to view: SKView) {
        scaleMode = .resizeFill
        redraw()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        redraw()
    }

    func resetWave() {
        birds = []
        blockers = []
        incoming = []
        redraw()
    }

    func updateWave(birds: [FlockBirdView], blockers: [FlockBlockerView],
                    incoming: [(lane: Int, ticksAway: Int, gated: Bool)]) {
        self.birds = birds
        self.blockers = blockers
        self.incoming = incoming
        redraw()
    }

    private func redraw() {
        guard size.width > 0, size.height > 0 else { return }
        removeAllChildren()
        backgroundColor = .init(red: 0.07, green: 0.16, blue: 0.23, alpha: 1)
        let laneWidth = size.width / 4
        for lane in 0..<4 {
            let stripe = SKShapeNode(rect: CGRect(x: CGFloat(lane) * laneWidth + 1,
                                                  y: 0, width: laneWidth - 2, height: size.height))
            stripe.fillColor = lane.isMultiple(of: 2)
                ? .init(red: 0.12, green: 0.26, blue: 0.34, alpha: 1)
                : .init(red: 0.09, green: 0.21, blue: 0.3, alpha: 1)
            stripe.strokeColor = .clear
            addChild(stripe)
            let number = SKLabelNode(text: "\(lane + 1)")
            number.fontSize = 16
            number.fontColor = .white
            number.position = CGPoint(x: (CGFloat(lane) + 0.5) * laneWidth, y: 22)
            addChild(number)
        }
        let row = size.height * 0.49
        for blocker in blockers {
            let x = (CGFloat(blocker.lane) + 0.5) * laneWidth
            let node = SKShapeNode(rectOf: CGSize(width: laneWidth * 0.78, height: 26), cornerRadius: 8)
            node.position = CGPoint(x: x, y: row)
            // Colour + glyph so each kind reads without relying on hue alone.
            let colors: [SKColor] = [.orange, .systemTeal, .systemPurple, .systemMint, .systemPink, .systemBrown]
            let glyphs = ["W", "T", "S", "F", "N", "D"]
            node.fillColor = blocker.cooling ? .gray : colors[blocker.kindRaw]
            node.strokeColor = .white
            addChild(node)
            let glyph = SKLabelNode(text: glyphs[blocker.kindRaw])
            glyph.fontSize = 15
            glyph.fontName = "Helvetica-Bold"
            glyph.fontColor = .black
            glyph.verticalAlignmentMode = .center
            glyph.position = node.position
            addChild(glyph)
        }
        for (index, notice) in incoming.enumerated() {
            let x = (CGFloat(notice.lane) + 0.5) * laneWidth
            let dot = SKShapeNode(circleOfRadius: notice.ticksAway == 0 ? 12 : 9)
            // Green + bigger ring = release-for-bonus gate: let it pass for a bonus.
            dot.fillColor = notice.gated ? .systemGreen : .yellow
            dot.strokeColor = .white
            dot.lineWidth = notice.gated ? 4 : 1
            dot.position = CGPoint(x: x + CGFloat(index % 2) * 5,
                                   y: size.height - 36 - CGFloat(index / 4) * 26)
            addChild(dot)
        }
        for bird in birds {
            let x = (CGFloat(bird.lane) + 0.5) * laneWidth
            let y = size.height * (0.88 - CGFloat(bird.progress) * 0.78)
            let node = SKShapeNode(circleOfRadius: CGFloat(11 + bird.speed * 2))
            node.fillColor = bird.gated ? .systemGreen : .init(red: 0.98, green: 0.72, blue: 0.28, alpha: 1)
            node.strokeColor = .white
            node.lineWidth = bird.gated ? 4 : 2
            node.position = CGPoint(x: x, y: y)
            addChild(node)
        }
    }
}
