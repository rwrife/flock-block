import Foundation
import Testing
@testable import FlockKit

@Suite struct ProgressSaveTests {
    @Test func currentRoundTrip() throws {
        var progress = GameProgress()
        let finished = progress.finish(score: 50, coinsEarned: 10)
        #expect(finished)
        progress.nextWave()
        let unlocked = progress.unlock(.fan)
        #expect(unlocked)
        let save = ProgressSave(progress: progress, settings: .init(hapticsEnabled: false))
        #expect(try ProgressSave.decode(save.encode()) == save)
    }

    @Test func migratesVersionOne() throws {
        let old = Data(#"{"version":1,"level":2,"coins":9,"highScore":40,"unlocked":[0,1,2]}"#.utf8)
        let restored = try ProgressSave.decode(old)
        #expect(restored.progress.level == 2)
        #expect(restored.progress.coins == 9)
        #expect(restored.settings.hapticsEnabled)
        #expect(try ProgressSave.decode(restored.encode()) == restored)
    }

    @Test func rejectsBadBalancesAndUnknownVersions() throws {
        let negative = Data(#"{"version":2,"level":1,"coins":-1,"highScore":0,"unlocked":[0,1,2],"settings":{"hapticsEnabled":true}}"#.utf8)
        #expect(throws: SaveError.invalidData) { try ProgressSave.decode(negative) }
        let future = Data(#"{"version":3,"level":1,"coins":0,"highScore":0,"unlocked":[0,1,2]}"#.utf8)
        #expect(throws: SaveError.unsupportedVersion) { try ProgressSave.decode(future) }
        let incomplete = Data(#"{"version":2,"level":1,"coins":0,"highScore":0,"unlocked":[0,1],"settings":{"hapticsEnabled":true}}"#.utf8)
        #expect(throws: SaveError.invalidData) { try ProgressSave.decode(incomplete) }
        let extras = Data(#"{"version":2,"level":1,"coins":0,"highScore":0,"unlocked":[0,1,2],"settings":{"hapticsEnabled":true},"token":"secret"}"#.utf8)
        #expect(throws: SaveError.invalidData) { try ProgressSave.decode(extras) }
    }

    @Test func failedWriteKeepsPreviousSave() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("save.json")
        let store = ProgressStore(url: url)
        let original = ProgressSave()
        try store.save(original)
        let bytes = try Data(contentsOf: url)
        // Interrupted write: parent becomes unwritable, so the temp sibling
        // can never be created. Previous save must stay byte-identical.
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directory.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path) }
        // uid 0 (container CI lanes) bypasses POSIX permissions; prove DAC is
        // enforced before asserting, and skip otherwise. Non-root runners —
        // the macOS package lane and local Docker probes — run the real check.
        let probe = directory.appendingPathComponent("probe.tmp")
        if (try? Data().write(to: probe)) != nil {
            try? FileManager.default.removeItem(at: probe)
            return
        }
        #expect(throws: Error.self) { try store.save(ProgressSave(progress: { var p = GameProgress(); p.nextWave(); return p }())) }
        #expect(try Data(contentsOf: url) == bytes)
    }

    @Test func replacementIsDurableAndDeletionRemovesSave() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProgressStore(url: directory.appendingPathComponent("save.json"))
        try store.save(ProgressSave())
        var progress = GameProgress()
        progress.nextWave()
        let changed = ProgressSave(progress: progress)
        try store.save(changed)
        let loaded = try store.load()
        #expect(loaded == changed)
        try store.deleteAll()
        #expect(throws: SaveError.missingFile) { try store.load() }
    }

    @Test func corruptImportPreservesExistingSave() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProgressStore(url: directory.appendingPathComponent("save.json"))
        try store.save(ProgressSave())
        let before = try Data(contentsOf: store.url)
        let corrupt = Data(#"{"version":2,"coins":-2}"#.utf8)
        #expect(throws: Error.self) { try store.restore(corrupt) }
        #expect(try Data(contentsOf: store.url) == before)
    }
}
