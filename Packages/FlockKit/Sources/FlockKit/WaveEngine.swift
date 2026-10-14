/// Deterministic, tick-based four-lane rules. Rendering and input live outside this module.
public enum BlockerKind: Int, CaseIterable, Sendable, Codable {
    case wall, trampoline, tar

    public var cost: Int {
        switch self {
        case .wall: 2
        case .trampoline: 3
        case .tar: 4
        }
    }

    /// Ticks after a bonk before this blocker can bonk again.
    public var cooldown: Int {
        switch self {
        case .wall: 2
        case .trampoline: 1
        case .tar: 3
        }
    }

    public var points: Int {
        switch self {
        case .wall: 10
        case .trampoline: 15
        case .tar: 20
        }
    }
}

public struct Bird: Equatable, Sendable {
    public let id: Int
    public let lane: Int
    public let spawnTick: Int
    public let speed: Int

    public init(id: Int, lane: Int, spawnTick: Int, speed: Int) throws {
        guard id >= 0, (0..<4).contains(lane), (0...128).contains(spawnTick),
              (1...3).contains(speed) else { throw WaveError.invalidPlan }
        self.id = id
        self.lane = lane
        self.spawnTick = spawnTick
        self.speed = speed
    }
}

public enum WaveError: Error, Equatable {
    case invalidPlan, invalidLane, occupiedLane, insufficientEnergy, waveFinished
}

public struct WavePlan: Equatable, Sendable {
    public let birds: [Bird]

    public init(birds: [Bird]) throws {
        guard !birds.isEmpty, birds.count <= 64,
              Set(birds.map(\.id)).count == birds.count,
              birds.allSatisfy({ (0..<4).contains($0.lane) && (0...128).contains($0.spawnTick) && (1...3).contains($0.speed) && $0.id >= 0 })
        else { throw WaveError.invalidPlan }
        self.birds = birds.sorted { ($0.spawnTick, $0.id) < ($1.spawnTick, $1.id) }
    }

    public init(seed: UInt64, count: Int) throws {
        guard (1...64).contains(count) else { throw WaveError.invalidPlan }
        var random = seed
        var generated: [Bird] = []
        for id in 0..<count {
            random &+= 0x9E3779B97F4A7C15
            var value = random
            value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
            value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
            value ^= value >> 31
            generated.append(try Bird(id: id, lane: Int(value % 4),
                                      spawnTick: id / 2, speed: Int((value >> 8) % 3) + 1))
        }
        try self.init(birds: generated)
    }
}

public struct WaveEvent: Equatable, Sendable {
    public enum Result: Equatable, Sendable { case bonk(BlockerKind), escape }
    public let tick: Int
    public let birdID: Int
    public let lane: Int
    public let result: Result
}

public struct WaveEngine: Sendable {
    private struct ActiveBird: Sendable {
        let bird: Bird
        var position: Int
    }
    private struct PlacedBlocker: Sendable {
        let kind: BlockerKind
        var readyTick: Int
    }

    public let plan: WavePlan
    public private(set) var tick = 0
    public private(set) var energy: Int
    public private(set) var score = 0
    public private(set) var bonks = 0
    public private(set) var escapes = 0
    public private(set) var events: [WaveEvent] = []
    private var active: [ActiveBird] = []
    private var blockers: [Int: PlacedBlocker] = [:]
    private var nextBird = 0

    public init(plan: WavePlan, energy: Int = 12) throws {
        guard (0...100).contains(energy) else { throw WaveError.invalidPlan }
        self.plan = plan
        self.energy = energy
    }

    public var isFinished: Bool { nextBird == plan.birds.count && active.isEmpty }
    public func blocker(in lane: Int) -> BlockerKind? { blockers[lane]?.kind }

    /// One permanent blocker per lane. Charge energy at placement, never at collision.
    public mutating func place(_ kind: BlockerKind, in lane: Int) throws {
        guard !isFinished else { throw WaveError.waveFinished }
        guard (0..<4).contains(lane) else { throw WaveError.invalidLane }
        guard blockers[lane] == nil else { throw WaveError.occupiedLane }
        guard energy >= kind.cost else { throw WaveError.insufficientEnergy }
        energy -= kind.cost
        blockers[lane] = PlacedBlocker(kind: kind, readyTick: tick)
    }

    /// Spawns, then moves, then resolves crossing row 3 or escaping row 6.
    /// Stable (spawnTick, id) ordering decides simultaneous hits; cooldown skips
    /// the next N ticks, so a second bird crossing in this tick escapes later.
    @discardableResult public mutating func advance() -> [WaveEvent] {
        guard !isFinished else { return [] }
        while nextBird < plan.birds.count && plan.birds[nextBird].spawnTick <= tick {
            active.append(ActiveBird(bird: plan.birds[nextBird], position: 0))
            nextBird += 1
        }
        var survivors: [ActiveBird] = []
        var resolved: [WaveEvent] = []
        for var flying in active {
            let old = flying.position
            flying.position += flying.bird.speed
            let lane = flying.bird.lane
            if old < 3 && flying.position >= 3, var placed = blockers[lane], placed.readyTick <= tick {
                resolved.append(WaveEvent(tick: tick, birdID: flying.bird.id, lane: lane, result: .bonk(placed.kind)))
                score += placed.kind.points
                bonks += 1
                placed.readyTick = tick + placed.kind.cooldown + 1
                blockers[lane] = placed
            } else if flying.position >= 6 {
                resolved.append(WaveEvent(tick: tick, birdID: flying.bird.id, lane: lane, result: .escape))
                escapes += 1
            } else {
                survivors.append(flying)
            }
        }
        active = survivors
        events.append(contentsOf: resolved)
        tick += 1
        return resolved
    }
}
