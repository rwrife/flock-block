import Testing
@testable import FlockKit

@Suite("Deterministic wave engine")
struct WaveEngineTests {
    private static func engine(_ birds: [Bird], energy: Int = 12) throws -> WaveEngine {
        try WaveEngine(plan: WavePlan(birds: birds), energy: energy)
    }

    @Test("all six blockers score their documented bonk points")
    func collisionPolicies() throws {
        for (kind, points) in [(BlockerKind.wall, 10), (.trampoline, 15), (.tar, 20),
                               (.fan, 12), (.balloonNet, 18), (.decoyFeeder, 8)] {
            var subject = try Self.engine([try Bird(id: 1, lane: 2, spawnTick: 0, speed: 1)])
            try subject.place(kind, in: 2)
            #expect(subject.advance().isEmpty) // tick 0 -> row 1
            #expect(subject.advance().isEmpty) // tick 1 -> row 2
            let hit = subject.advance()        // tick 2 -> crosses row 3
            #expect(hit == [WaveEvent(tick: 2, birdID: 1, lane: 2, result: .bonk(kind))])
            #expect(subject.bonks == 1)
            while !subject.isFinished { _ = subject.advance() } // fan/decoy survive the hit
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

    @Test("tutorial fixture starts, accepts a blocker, resolves collisions and completes replay")
    func tutorialFlow() throws {
        func play() throws -> WaveEngine {
            var wave = try WaveEngine(plan: .tutorialFixture)
            #expect(wave.plan.birds.count == 5)
            #expect(Set(wave.plan.birds.map(\.lane)) == Set(0..<4))
            try wave.place(.wall, in: 0)
            #expect(wave.energy == 10)
            while !wave.isFinished {
                #expect(wave.tick < 80)
                wave.advance()
            }
            return wave
        }
        let first = try play()
        let replay = try play()
        #expect(first.events == replay.events)
        #expect(first.score == 10)
        #expect(first.bonks == 1 && first.escapes == 4)
        #expect(first.isFinished && replay.isFinished)
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

    @Test("fan blows a bird back to row 0 once, then cooldown lets it through")
    func fanPushBack() throws {
        var subject = try Self.engine([try Bird(id: 1, lane: 1, spawnTick: 0, speed: 3)])
        try subject.place(.fan, in: 1)
        let hit = subject.advance() // speed 3 crosses row 3 on the first tick
        #expect(hit == [WaveEvent(tick: 0, birdID: 1, lane: 1, result: .bonk(.fan))])
        // Bird sits at row 0; fan is cooling, so it sails past and escapes.
        while !subject.isFinished { _ = subject.advance() }
        #expect(subject.escapes == 1 && subject.bonks == 1 && subject.score == 12)
        // Second pass can never be pushed again: touched birds stay immune.
        #expect(subject.events.filter { $0.birdID == 1 }.count == 2)
    }

    @Test("balloon net catches two birds then pops")
    func netCapacity() throws {
        var subject = try Self.engine([
            try Bird(id: 1, lane: 2, spawnTick: 0, speed: 1),
            try Bird(id: 2, lane: 2, spawnTick: 4, speed: 1),
            try Bird(id: 3, lane: 2, spawnTick: 8, speed: 1),
        ])
        try subject.place(.balloonNet, in: 2)
        while !subject.isFinished { _ = subject.advance() }
        #expect(subject.bonks == 2 && subject.escapes == 1)
        #expect(subject.score == 36 && subject.blocker(in: 2) == .balloonNet)
    }

    @Test("decoy feeder stalls a bird for exactly stallTicks then it escapes")
    func decoyStall() throws {
        var subject = try Self.engine([try Bird(id: 1, lane: 0, spawnTick: 0, speed: 1)])
        try subject.place(.decoyFeeder, in: 0)
        _ = subject.advance() // row 1
        _ = subject.advance() // row 2
        let hit = subject.advance() // crosses 3, pushed back to 2, stalls 3
        #expect(hit == [WaveEvent(tick: 2, birdID: 1, lane: 0, result: .bonk(.decoyFeeder))])
        for _ in 0..<BlockerKind.stallTicks { #expect(subject.advance().isEmpty) }
        // Released at row 2, speed 1: rows 3,4,5 then escape.
        #expect(subject.advance().isEmpty)
        #expect(subject.advance().isEmpty)
        #expect(subject.advance().isEmpty)
        let gone = subject.advance()
        #expect(gone == [WaveEvent(tick: 9, birdID: 1, lane: 0, result: .escape)])
        #expect(subject.bonks == 1 && subject.score == 8)
    }

    @Test("release-for-bonus gate pays only for an untouched gated bird")
    func gatedBonus() throws {
        func run(blocked: Bool) throws -> WaveEngine {
            var subject = try Self.engine([
                try Bird(id: 1, lane: 0, spawnTick: 0, speed: 1, gated: true),
                try Bird(id: 2, lane: 1, spawnTick: 0, speed: 1),
            ], energy: 12)
            if blocked { try subject.place(.wall, in: 0) }
            while !subject.isFinished { _ = subject.advance() }
            return subject
        }
        let released = try run(blocked: false)
        #expect(released.bonusReleases == 1)
        #expect(released.events.contains(WaveEvent(tick: 5, birdID: 1, lane: 0, result: .bonusRelease)))
        #expect(released.score == WaveEngine.releaseBonus) // gated bird also counts as an escape
        #expect(released.escapes == 2 && released.bonusReleases == 1)
        let bonked = try run(blocked: true)
        #expect(bonked.bonusReleases == 0)
        #expect(bonked.score == 10) // the wall ate the gate
        #expect(bonked.events.contains(WaveEvent(tick: 2, birdID: 1, lane: 0, result: .bonk(.wall))))
        #expect(!bonked.events.contains { $0.birdID == 1 && $0.result == .escape })
    }

    @Test("a wave that is nothing but bonus gates is rejected as unwinnable pressure")
    func gateShareCap() throws {
        #expect(throws: WaveError.invalidPlan) {
            try WavePlan(birds: [
                try Bird(id: 1, lane: 0, spawnTick: 0, speed: 1, gated: true),
                try Bird(id: 2, lane: 1, spawnTick: 0, speed: 1, gated: true),
            ])
        }
        // Half gated is the documented maximum and is accepted.
        let ok = try WavePlan(birds: [
            try Bird(id: 1, lane: 0, spawnTick: 0, speed: 1, gated: true),
            try Bird(id: 2, lane: 1, spawnTick: 0, speed: 1),
        ])
        #expect(ok.birds.filter(\.gated).count == 1)
    }

    @Test("ladder is deterministic, bounded and every wave terminates")
    func ladderFixtures() throws {
        for level in 1...16 {
            func replay() throws -> (Int, Int, [WaveEvent]) {
                var subject = try WaveEngine(plan: WaveLadder.plan(for: level),
                                            energy: WaveLadder.energy(for: level))
                var steps = 0
                while !subject.isFinished {
                    _ = subject.advance()
                    steps += 1
                    #expect(steps < 300, "level \(level) never terminates")
                }
                return (subject.score, subject.coinsEarned, subject.events)
            }
            let first = try replay()
            #expect(first.2.first?.tick ?? 0 >= 35, "level \(level) starts before the one-thumb warm-up")
            let second = try replay()
            #expect(first == second, "level \(level) replay diverged")
        }
        #expect(throws: WaveError.invalidPlan) { try WaveLadder.plan(for: 0) }
        #expect(throws: WaveError.invalidPlan) { try WaveLadder.plan(for: 17) }
    }

    @Test("coins are earn-only: unlocks subtract, never top up")
    func earnOnlyProgress() throws {
        var progress = GameProgress()
        #expect(progress.unlocked == Set(BlockerKind.allCases.filter(\.isStarter)))
        let noCoinsUnlock = progress.unlock(.fan)
        #expect(!noCoinsUnlock) // 0 coins
        #expect(progress.coins == 0)
        let earned = progress.finish(score: 120, coinsEarned: 24)
        #expect(earned)
        #expect(progress.coins == 24 && progress.highScore == 120)
        let rejectedScore = progress.finish(score: -5, coinsEarned: 10)
        #expect(!rejectedScore)
        let rejectedCoins = progress.finish(score: 5, coinsEarned: -10)
        #expect(!rejectedCoins)
        #expect(progress.coins == 24 && progress.highScore == 120)
        let fanUnlocked = progress.unlock(.fan)
        #expect(fanUnlocked)
        #expect(progress.coins == 18 && progress.unlocked.contains(.fan))
        let repeatUnlock = progress.unlock(.fan)
        #expect(!repeatUnlock) // no double purchase, no refund
        #expect(progress.coins == 18)
        let netUnlocked = progress.unlock(.balloonNet)
        #expect(netUnlocked)
        #expect(progress.coins == 8)
        let decoyNoCoins = progress.unlock(.decoyFeeder) // needs 14
        #expect(!decoyNoCoins)
        _ = progress.finish(score: 30, coinsEarned: 6) // +6 -> 14
        let decoyUnlocked = progress.unlock(.decoyFeeder)
        #expect(decoyUnlocked)
        #expect(progress.coins == 0 && progress.unlocked == Set(BlockerKind.allCases))
        for _ in 0..<20 { progress.nextWave() }
        #expect(progress.level == 16)
    }

    @Test("level 3 ladder guarantees a reachable release bonus; gate blocking is tested separately")
    func ladderGateTradeoff() throws {
        let plan = try WaveLadder.plan(for: 3)
        #expect(plan.birds.contains { $0.gated })
        var subject = try WaveEngine(plan: plan, energy: WaveLadder.energy(for: 3))
        while !subject.isFinished { _ = subject.advance() }
        #expect(subject.bonusReleases == plan.birds.filter(\.gated).count)
        #expect(subject.score == subject.bonusReleases * WaveEngine.releaseBonus)
        #expect(subject.events.count == plan.birds.count)
    }
}
