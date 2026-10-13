import FlockKit
import SpriteKit
import SwiftUI

/// Read-only foundation: field/tray geometry is ready; gameplay is issue #3.
struct WorkspaceView: View {
    private let layout = FlockWorkspaceLayout()
    @State private var scene: FlockFieldScene?

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    if let scene {
                        SpriteView(scene: scene)
                            .accessibilityHidden(true) // Decorative lanes; no actions yet.
                    } else {
                        Color(red: 0.08, green: 0.17, blue: 0.24)
                    }
                    Text("Four flock lanes")
                        .font(.title2.bold())
                        .padding()
                        .foregroundStyle(.white)
                }
                .onAppear {
                    if scene == nil {
                        scene = FlockFieldScene(size: CGSize(width: 320, height: 460))
                    }
                }
                .frame(height: geometry.size.height * layout.fieldFraction)

                VStack(spacing: 12) {
                    Text("Blocker tray")
                        .font(.title2.bold())
                    Text("Gameplay arrives next. No blockers to place yet.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                    Text("\(FlockKit.milestone) · offline")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .background(.regularMaterial)
                .frame(height: geometry.size.height * layout.trayFraction)
            }
        }
    }
}

/// Static, original lane markers. Wave engine and touch placement follow.
final class FlockFieldScene: SKScene {
    override func didMove(to view: SKView) {
        scaleMode = .resizeFill
        backgroundColor = .init(red: 0.08, green: 0.17, blue: 0.24, alpha: 1)
        removeAllChildren()
        for lane in 0..<4 {
            let marker = SKShapeNode(circleOfRadius: 11)
            marker.fillColor = .init(red: 0.95, green: 0.77, blue: 0.32, alpha: 1)
            marker.strokeColor = .white
            marker.lineWidth = 2
            marker.position = CGPoint(x: CGFloat(lane) * size.width / 4 + size.width / 8,
                                      y: size.height * 0.58)
            addChild(marker)
        }
    }
}
