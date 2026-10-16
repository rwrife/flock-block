/// Fixed, reproducible level inputs. Level 1 is the tutorial; each later wave
/// scales from eight to at most 64 birds, with at least one non-gated bird.
public enum WaveLadder {
    public static func plan(for level: Int) throws -> WavePlan {
        guard (1...16).contains(level) else { throw WaveError.invalidPlan }
        if level == 1 { return .tutorialFixture }
        let count = min(64, 8 + (level - 2) * 4)
        let pattern = try WavePlan(seed: UInt64(level) &* 0x9E3779B97F4A7C15, count: count)
        return try WavePlan(birds: try pattern.birds.map { bird in
            try Bird(id: bird.id, lane: bird.lane,
                     spawnTick: 35 + bird.spawnTick, speed: bird.speed,
                     gated: bird.id % 4 == 0)
        })
    }

    public static func energy(for level: Int) -> Int {
        min(40, 12 + max(0, level - 1) * 2)
    }
}

/// In-memory run progress. Issue #6 adds versioned local storage; no purchase path.
public struct GameProgress: Equatable, Sendable {
    public private(set) var level = 1
    public private(set) var coins = 0
    public private(set) var highScore = 0
    public private(set) var unlocked: Set<BlockerKind> = Set(BlockerKind.allCases.filter(\.isStarter))

    public init() {}

    @discardableResult public mutating func finish(score: Int, coinsEarned: Int) -> Bool {
        guard (0...100_000).contains(score), (0...20_000).contains(coinsEarned) else { return false }
        highScore = max(highScore, score)
        coins += coinsEarned
        return true
    }

    public mutating func nextWave() { level = min(16, level + 1) }

    @discardableResult public mutating func unlock(_ kind: BlockerKind) -> Bool {
        guard !unlocked.contains(kind), coins >= kind.unlockCost else { return false }
        coins -= kind.unlockCost
        unlocked.insert(kind)
        return true
    }
}
