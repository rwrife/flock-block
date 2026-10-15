/// One portrait-workspace geometry and touch-mapping seam. UIKit/SwiftUI/scene
/// clients map their coordinate systems to these normalized fractions; no fold API.
/// Future iPhone Duo work can supply new fractions behind this same type.
public struct FlockWorkspaceLayout: Sendable, Equatable {
    public let fieldFraction: Double
    public let trayFraction: Double
    public let laneCount: Int

    public init(fieldFraction: Double = 0.65, laneCount: Int = 4) {
        // ponytail: a second display can supply new fractions when public
        // dual-screen APIs exist; current app always uses one portrait screen.
        let bounded = min(0.85, max(0.55, fieldFraction))
        self.fieldFraction = bounded
        self.trayFraction = 1 - bounded
        self.laneCount = max(1, laneCount)
    }

    /// Top-left-origin workspace point (e.g. a SwiftUI drag location).
    /// Points outside the field or width map to nil so tray chrome never
    /// steals a placement.
    public func lane(atX x: Double, y: Double, width: Double, height: Double) -> Int? {
        guard width.isFinite, height.isFinite, x.isFinite, y.isFinite,
              width > 0, height > 0,
              y >= 0, y < height * fieldFraction,
              x >= 0, x < width
        else { return nil }
        let lane = Int(x / (width / Double(laneCount)))
        return min(max(lane, 0), laneCount - 1)
    }
}
