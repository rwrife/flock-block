import Testing
@testable import FlockKit

@Suite("Single-screen workspace seam")
struct FlockWorkspaceLayoutTests {
    @Test func defaultPortraitSplit() {
        let layout = FlockWorkspaceLayout()
        #expect(layout.fieldFraction == 0.65)
        #expect(abs(layout.trayFraction - 0.35) < 0.000001)
        #expect(layout.fieldFraction + layout.trayFraction == 1)
    }

    @Test func outOfRangeInputsStayUsable() {
        #expect(abs(FlockWorkspaceLayout(fieldFraction: -1).fieldFraction - 0.55) < 0.000001)
        #expect(abs(FlockWorkspaceLayout(fieldFraction: 2).trayFraction - 0.15) < 0.000001)
    }

    @Test func dragMapsOnlyFieldPointsToFourLanes() {
        let layout = FlockWorkspaceLayout()
        #expect(layout.lane(atX: 0, y: 0, width: 320, height: 500) == 0)
        #expect(layout.lane(atX: 79.9, y: 324, width: 320, height: 500) == 0)
        #expect(layout.lane(atX: 80, y: 100, width: 320, height: 500) == 1)
        #expect(layout.lane(atX: 319.9, y: 100, width: 320, height: 500) == 3)
        #expect(layout.lane(atX: 320, y: 100, width: 320, height: 500) == nil)
        #expect(layout.lane(atX: 25, y: 325, width: 320, height: 500) == nil)
        #expect(layout.lane(atX: -1, y: 0, width: 320, height: 500) == nil)
        #expect(layout.lane(atX: .nan, y: 0, width: 320, height: 500) == nil)
        #expect(layout.lane(atX: 5, y: 0, width: 0, height: 500) == nil)
    }
}
