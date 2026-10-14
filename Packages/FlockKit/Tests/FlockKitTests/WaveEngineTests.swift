import Testing
@testable import FlockKit

@Suite("Deterministic wave engine")
struct WaveEngineTests {
    private static func engine(_ birds: [Bird], energy: Int = 12) throws -> WaveEngine {
        try WaveEngine(plan: WavePlan(birds: birds), energy: energy)
    }

    @Test("wall, trampoline and tar bonk with documented scores")
    func collisionPolicies() throws {
        for (kind, points) in [(BlockerKind.wall, 10), (.trampoline, 15), (.tar, 20)] {
            var subject = try Self.engine([try Bird(id: 1, lane: 2, spawnTick: 0, speed: 1)])
            try subject.place(kind, in: 2)
            #expect(subject.advance().isEmpty) // tick 0 -> row 1
            #expect(subject.advance().isEmpty) // tick 1 -> row 2
            let hit = subject.advance()        // tick 2 -> crosses row 3
            #expect(hit == [WaveEvent(tick: 2, birdID: 1, lane: 2, result: .bonk(kind))])
            #expect(subject.score == points && subject.bonks == 1 && subject.isFinished)
        }
    }

    @Test("blocked and clean lanes bonk in stable (spawnTick, id) order in one tick")
    func simultaneousCollisions() throws {
        var subject = try Self.engine([
            try Bird(id: 2, lane: 0, spawnTick: 0, speed: 3),
            try Bird(id: 1, lane: 1, spawnTick: 0, speed: 3),
        ])
        try subject.place(.wall, in: 0)
        try subject.place(.wall, in: 1)
        let hits = subject.advance()
        #expect(hits.map(\.birdID) == [1, 2])
        #expect(hits.allSatisfy { $0.tick == 0 && $0.result == .bonk(.wall) })
    }

    @Test("cooldown lets a second same-lane bird through and it escapes")
    func sameLaneCooldown() throws {
        var subject = try Self.engine([
            try Bird(id: 1, lane: 0, spawnTick: 0, speed: 3),
            try Bird(id: 2, lane: 0, spawnTick: 0, speed: 3),
        ])
        try subject.place(.wall, in: 0) // wall cooldown keeps lane down at tick 1
        _ = subject.advance()
        let second = subject.advance()
        #expect(second == [WaveEvent(tick: 1, birdID: 2, lane: 0, result: .escape)])
        #expect(subject.bonks == 1 && subject.escapes == 1 && subject.score == 10 && subject.isFinished)
    }

    @Test("full four-lane board accepts one blocker per lane and rejects occupation")
    func fullLanes() throws {
        var subject = try Self.engine([try Bird(id: 1, lane: 0, spawnTick: 0, speed: 1)], energy: 100)
        for lane in 0..<4 { try subject.place(.wall, in: lane) }
        #expect([0, 1, 2, 3].map(subject.blocker) == Array(repeating: BlockerKind.wall, count: 4))
        #expect(throws: WaveError.occupiedLane) { try subject.place(.tar, in: 0) }
    }

    @Test("invalid plan, lane and negative balance are rejected without mutation")
    func placementLegality() throws {
        #expect(throws: WaveError.invalidPlan) { try WaveEngine(plan: WavePlan(birds: []), energy: 10) }
        #expect(throws: WaveError.invalidPlan) {
            try WaveEngine(plan: WavePlan(birds: [try Bird(id: 1, lane: 2, spawnTick: 0, speed: 1)]), energy: -1)
        }
        var subject = try Self.engine([try Bird(id: 1, lane: 3, spawnTick: 0, speed: 1)], energy: 3)
        let before = (subject.tick, subject.energy, subject.score, subject.events)
        #expect(throws: WaveError.invalidLane) { try subject.place(.wall, in: 4) }
        #expect(throws: WaveError.insufficientEnergy) { try subject.place(.tar, in: 3) } // tar costs 4
        #expect((subject.tick, subject.energy, subject.score, subject.events) == before)
        #expect(throws: WaveError.invalidPlan) { try Bird(id: 1, lane: 4, spawnTick: 0, speed: 1) }
        #expect(throws: WaveError.invalidPlan) { try Bird(id: 1, lane: 0, spawnTick: 0, speed: 4) }
    }

    @Test("unblocked flocks escape at the far row with explicit timing")
    func speedsAndMisses() throws {
        var subject = try Self.engine([
            try Bird(id: 1, lane: 0, spawnTick: 0, speed: 3),
            try Bird(id: 2, lane: 1, spawnTick: 2, speed: 1),
        ])
        while !subject.isFinished { _ = subject.advance() }
        #expect(subject.events.map(\.birdID) == [1, 2])
        #expect(subject.events[0] == WaveEvent(tick: 1, birdID: 1, lane: 0, result: .escape))
        #expect(subject.events[1] == WaveEvent(tick: 7, birdID: 2, lane: 1, result: .escape))
        #expect(subject.escapes == 2 && subject.score == 0 && subject.tick == 8 && subject.isFinished)
    }

    @Test("identical seeded replays produce identical events")
    func seededReplayIsDeterministic() throws {
        func replay(_ seed: UInt64) throws -> (Int, [WaveEvent]) {
            var subject = try WaveEngine(plan: WavePlan(seed: seed, count: 16))
            try subject.place(.wall, in: 0)
            try subject.place(.trampoline, in: 2)
            while !subject.isFinished { _ = subject.advance() }
            return (subject.score, subject.events)
        }
        let first = try replay(1234)
        let second = try replay(1234)
        let other = try replay(1235)
        #expect(first == second)
        #expect(first.1 != other.1)
    }

    @Test("advancing after completion is inert")
    func completedWaveRejectsWork() throws {
        var subject = try Self.engine([try Bird(id: 1, lane: 3, spawnTick: 0, speed: 3)])
        while !subject.isFinished { _ = subject.advance() }
        let before = (subject.tick, subject.energy, subject.events)
        #expect(subject.advance().isEmpty)
        #expect(throws: WaveError.waveFinished) { try subject.place(.wall, in: 0) }
        #expect((subject.tick, subject.energy, subject.events) == before)
    }
}
