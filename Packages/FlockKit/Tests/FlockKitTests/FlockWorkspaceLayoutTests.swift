import Testing
@testable import FlockKit

@Suite("Single-screen workspace seam")
struct FlockWorkspaceLayoutTests {
    @Test func defaultPortraitSplit() {
        let layout = FlockWorkspaceLayout()
        #expect(layout.fieldFraction == 0.72)
        #expect(abs(layout.trayFraction - 0.28) < 0.000001)
        #expect(layout.fieldFraction + layout.trayFraction == 1)
    }

    @Test func outOfRangeInputsStayUsable() {
        #expect(abs(FlockWorkspaceLayout(fieldFraction: -1).fieldFraction - 0.55) < 0.000001)
        #expect(abs(FlockWorkspaceLayout(fieldFraction: 2).trayFraction - 0.15) < 0.000001)
    }
}
