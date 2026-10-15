import FlockKit
import SpriteKit
import SwiftUI

/// Single portrait workspace: field above persistent one-thumb blocker tray.
/// No native dual-screen API or tablet surface is used.
struct WorkspaceView: View {
    @State private var session = WaveSession()
    @State private var scene = FlockFieldScene(size: CGSize(width: 320, height: 460))

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
                }
                .frame(height: fieldHeight)

                VStack(spacing: 5) {
                    HStack {
                        Text("Blocker tray")
                            .font(.headline)
                        Spacer()
                        Text("Energy \(session.energy) · Score \(session.score)")
                            .font(.subheadline.monospacedDigit())
                    }
                    HStack(spacing: 4) {
                        ForEach(BlockerKind.allCases, id: \.self) { kind in
                            Button {
                                session.toggleSelection(kind)
                            } label: {
                                VStack(spacing: 1) {
                                    Text(kind.displayName).font(.subheadline.bold())
                                    Text("\(kind.cost) energy").font(.caption2)
                                }
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(session.selectedKind == kind ? Color.orange : Color.blue,
                                            in: RoundedRectangle(cornerRadius: 10))
                                .foregroundStyle(.white)
                            }
                            .accessibilityLabel("\(kind.displayName), \(kind.cost) energy")
                            .accessibilityIdentifier("blocker.\(kind.displayName.lowercased())")
                            .disabled(session.phase != .running || session.energy < kind.cost)
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 8, coordinateSpace: .named("workspace"))
                                    .onEnded { drag in
                                        session.drop(kind: kind, at: drag.location, in: geometry.size)
                                    }
                            )
                        }
                    }
                    Text(session.statusLine)
                        .font(.caption)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("wave.status")
                    Button(session.phase == .idle ? "Start wave" : "Replay wave") {
                        session.startWave()
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(.orange, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.black)
                    .accessibilityIdentifier(session.phase == .idle ? "wave.start" : "wave.replay")
                    .disabled(session.phase == .running)
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
        }
    }
}

struct FlockBirdView {
    let id: Int
    let lane: Int
    let speed: Int
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
    private var incoming: [(lane: Int, ticksAway: Int)] = []

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
                    incoming: [(lane: Int, ticksAway: Int)]) {
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
            let colors: [SKColor] = [.orange, .systemTeal, .systemPurple]
            node.fillColor = blocker.cooling ? .gray : colors[blocker.kindRaw]
            node.strokeColor = .white
            addChild(node)
        }
        for (index, notice) in incoming.enumerated() {
            let x = (CGFloat(notice.lane) + 0.5) * laneWidth
            let dot = SKShapeNode(circleOfRadius: notice.ticksAway == 0 ? 12 : 9)
            dot.fillColor = .yellow
            dot.strokeColor = .white
            dot.position = CGPoint(x: x + CGFloat(index % 2) * 5,
                                   y: size.height - 36 - CGFloat(index / 4) * 26)
            addChild(dot)
        }
        for bird in birds {
            let x = (CGFloat(bird.lane) + 0.5) * laneWidth
            let y = size.height * (0.88 - CGFloat(bird.progress) * 0.78)
            let node = SKShapeNode(circleOfRadius: CGFloat(11 + bird.speed * 2))
            node.fillColor = .init(red: 0.98, green: 0.72, blue: 0.28, alpha: 1)
            node.strokeColor = .white
            node.lineWidth = 2
            node.position = CGPoint(x: x, y: y)
            addChild(node)
        }
    }
}
