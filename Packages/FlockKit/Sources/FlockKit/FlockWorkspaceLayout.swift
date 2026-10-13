/// One portrait-workspace geometry seam. UIKit/SwiftUI/scene clients map
/// their own coordinate systems to these normalized fractions; no fold API.
public struct FlockWorkspaceLayout: Sendable, Equatable {
    public let fieldFraction: Double
    public let trayFraction: Double

    public init(fieldFraction: Double = 0.72) {
        // ponytail: a second display can supply new fractions when public
        // dual-screen APIs exist; current app always uses one portrait screen.
        let bounded = min(0.85, max(0.55, fieldFraction))
        self.fieldFraction = bounded
        self.trayFraction = 1 - bounded
    }
}
