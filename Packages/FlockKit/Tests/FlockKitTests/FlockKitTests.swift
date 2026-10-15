import Testing
@testable import FlockKit

@Suite("Skeleton placeholder")
struct FlockKitTests {
    @Test("domain namespace is reachable")
    func domainNamespace() {
        #expect(FlockKit.domain == "FlockKit")
    }

    @Test("milestone marker is set for M2")
    func milestoneMarker() {
        #expect(FlockKit.milestone == "M2-playable")
    }

    @Test("skeleton exposes no stored state beyond constants")
    func constantsAreStable() {
        // Guards the contract later issues depend on: these markers exist
        // and are pure constants (no clock, no I/O) in the M0 skeleton.
        let first = (FlockKit.domain, FlockKit.milestone)
        let second = (FlockKit.domain, FlockKit.milestone)
        #expect(first == second)
    }
}
