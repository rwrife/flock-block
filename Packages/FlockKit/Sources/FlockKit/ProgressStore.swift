import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public enum SaveError: Error, Equatable, Sendable {
    case unsupportedVersion
    case invalidData
    case missingFile
}

public struct GameSettings: Codable, Equatable, Sendable {
    public var hapticsEnabled: Bool

    public init(hapticsEnabled: Bool = true) {
        self.hapticsEnabled = hapticsEnabled
    }
}

/// Versioned, atomic save representation. Schema changes increment `currentVersion`
/// and handle older payloads in `decode`.
public struct ProgressSave: Equatable, Sendable {
    public static let currentVersion = 2

    public var progress: GameProgress
    public var settings: GameSettings

    public init(progress: GameProgress = GameProgress(), settings: GameSettings = GameSettings()) {
        self.progress = progress
        self.settings = settings
    }

    public func encode() throws -> Data {
        let payload = V2Payload(
            version: Self.currentVersion,
            level: progress.level,
            coins: progress.coins,
            highScore: progress.highScore,
            unlocked: progress.unlocked.map(\.rawValue).sorted(),
            settings: settings
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(payload)
    }

    public static func decode(_ data: Data) throws -> ProgressSave {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = json["version"] as? Int
        else { throw SaveError.invalidData }

        switch version {
        case 1:
            // V1 legacy payload: no settings, raw unlock ints.
            guard let level = json["level"] as? Int,
                  let coins = json["coins"] as? Int,
                  let highScore = json["highScore"] as? Int,
                  let unlockedRaws = json["unlocked"] as? [Int]
            else { throw SaveError.invalidData }
            let unlocked = try parseUnlocked(unlockedRaws)
            let progress = try GameProgress(level: level, coins: coins, highScore: highScore, unlocked: unlocked)
            return ProgressSave(progress: progress, settings: GameSettings())
        case 2:
            // Disallow unexpected top-level fields (e.g. analytics tokens, secrets).
            let allowedKeys: Set<String> = ["version", "level", "coins", "highScore", "unlocked", "settings"]
            guard Set(json.keys) == allowedKeys else { throw SaveError.invalidData }
            let decoder = JSONDecoder()
            let payload: V2Payload
            do {
                payload = try decoder.decode(V2Payload.self, from: data)
            } catch {
                throw SaveError.invalidData
            }
            let unlocked = try parseUnlocked(payload.unlocked)
            let progress = try GameProgress(level: payload.level, coins: payload.coins,
                                           highScore: payload.highScore, unlocked: unlocked)
            return ProgressSave(progress: progress, settings: payload.settings)
        default:
            throw SaveError.unsupportedVersion
        }
    }

    private static func parseUnlocked(_ raws: [Int]) throws -> Set<BlockerKind> {
        var kinds = Set<BlockerKind>()
        for raw in raws {
            guard let kind = BlockerKind(rawValue: raw) else { throw SaveError.invalidData }
            kinds.insert(kind)
        }
        return kinds
    }

    private struct V2Payload: Codable {
        let version: Int
        let level: Int
        let coins: Int
        let highScore: Int
        let unlocked: [Int]
        let settings: GameSettings
    }
}

/// Durable local store: writes via temporary sibling + atomic replace.
public struct ProgressStore: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public static func defaultStore() -> ProgressStore {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = root.appendingPathComponent("FlockBlock", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return ProgressStore(url: directory.appendingPathComponent("progress.json"))
    }

    public func load() throws -> ProgressSave {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SaveError.missingFile
        }
        let data = try Data(contentsOf: url)
        return try ProgressSave.decode(data)
    }

    public func save(_ save: ProgressSave) throws {
        let bytes = try save.encode()
        try writeAtomically(bytes)
    }

    /// Import user-selected JSON: validated first; failure leaves existing file untouched.
    @discardableResult
    public func restore(_ data: Data) throws -> ProgressSave {
        let validated = try ProgressSave.decode(data)
        try save(validated)
        return validated
    }

    /// Delete all user data: removes the file if present.
    public func deleteAll() throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private func writeAtomically(_ data: Data) throws {
        let parent = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let tempURL = parent.appendingPathComponent(".save-\(UUID().uuidString).tmp")
        // Fully close/flush via Data.write before the rename window opens.
        try data.write(to: tempURL, options: .atomic)
        // rename(2) atomically replaces an existing destination on POSIX
        // (Darwin and Linux alike); a failure leaves the old save untouched.
        if rename(tempURL.path, url.path) != 0 {
            try? FileManager.default.removeItem(at: tempURL)
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno),
                          userInfo: [NSFilePathErrorKey: url.path])
        }
    }
}
