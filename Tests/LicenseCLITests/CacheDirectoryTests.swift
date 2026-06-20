import Foundation
@testable import LicenseCLICore
import Testing

@Suite
final class CacheDirectoryTests {
    let fileManager = FileManager.default
    let baseURL: URL
    let cache: CacheDirectory

    init() throws {
        baseURL = fileManager.temporaryDirectory
            .appendingPathComponent("licensecli-cache-tests-\(UUID().uuidString)")
        try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        cache = CacheDirectory(fileManager: fileManager) { [baseURL] in baseURL }
    }

    deinit {
        try? fileManager.removeItem(at: baseURL)
    }

    private func makeEntry(_ name: String, modifiedDaysAgo days: Int) throws -> URL {
        let root = try cache.rootURL()
        let entry = root.appendingPathComponent(name)
        try fileManager.createDirectory(at: entry, withIntermediateDirectories: true)
        let date = Date(timeIntervalSinceNow: -Double(days) * 24 * 60 * 60)
        try fileManager.setAttributes([.modificationDate: date], ofItemAtPath: entry.path)
        return entry
    }

    @Test
    func rootURLIsCreatedUnderBase() throws {
        let root = try cache.rootURL()
        #expect(root.lastPathComponent == "LicenseCLI")
        #expect(fileManager.fileExists(atPath: root.path))
    }

    @Test
    func collectGarbageRemovesStaleEntriesOnly() throws {
        let fresh = try makeEntry("fresh@1.0.0", modifiedDaysAgo: 1)
        let stale = try makeEntry("stale@1.0.0", modifiedDaysAgo: CacheDirectory.timeToLiveDays + 1)

        cache.collectGarbage()

        #expect(fileManager.fileExists(atPath: fresh.path))
        #expect(!fileManager.fileExists(atPath: stale.path))
    }

    @Test
    func touchKeepsEntryFromBeingCollected() throws {
        let entry = try makeEntry("old@1.0.0", modifiedDaysAgo: CacheDirectory.timeToLiveDays + 5)

        cache.touch(entry)
        cache.collectGarbage()

        #expect(fileManager.fileExists(atPath: entry.path))
    }

    @Test
    func pruneRemovesAllEntriesAndReportsCount() throws {
        _ = try makeEntry("a@1.0.0", modifiedDaysAgo: 1)
        _ = try makeEntry("b@2.0.0", modifiedDaysAgo: 1)

        let removed = try cache.prune()

        #expect(removed == 2)
        let remaining = try fileManager.contentsOfDirectory(atPath: cache.rootURL().path)
        #expect(remaining.isEmpty)
    }
}
