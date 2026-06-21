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
        // Treat the temp dir as a global cache root so TTL GC applies in tests.
        cache = CacheDirectory(fileManager: fileManager, isGlobal: true) { [baseURL] in baseURL }
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
    func rootURLIsCreated() throws {
        let root = try cache.rootURL()
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

    @Test
    func entryURLKeysOnOwnerNameAndVersion() throws {
        let repo = GitHubRepoWithVersion(
            repo: GitHubRepo(owner: "apple", name: "swift-nio"),
            version: .tag("2.0.0")
        )

        let entry = try cache.entryURL(for: repo)

        #expect(entry.lastPathComponent == "apple-swift-nio@2.0.0")
        #expect(try entry.deletingLastPathComponent().standardizedFileURL == (cache.rootURL().standardizedFileURL))
    }

    /// Adversarial inputs must stay confined to the cache root: the security review's
    /// no-path-traversal conclusion rests entirely on `entryURL`'s sanitization, so this
    /// turns that claim into a regression test.
    @Test(arguments: [
        "../../etc",
        "foo/../bar",
        "feature/branch",
        "git@host:x",
    ])
    func entryURLConfinesPathTraversalAttempts(version: String) throws {
        let repo = GitHubRepoWithVersion(
            repo: GitHubRepo(owner: "apple", name: "swift-nio"),
            version: .tag(version)
        )

        let entry = try cache.entryURL(for: repo)
        let root = try cache.rootURL()

        // The entry is a single literal component directly under the root — separators
        // are sanitized away, so `..` can never land at a path boundary.
        #expect(!entry.lastPathComponent.contains("/"))
        #expect(entry.standardizedFileURL.path.hasPrefix(root.standardizedFileURL.path))
    }

    @Test
    func customCacheUsesPathDirectlyWithoutSubdirectory() throws {
        let customRoot = baseURL.appendingPathComponent("custom-\(UUID().uuidString)")
        let custom = CacheDirectory(customPath: customRoot.path, fileManager: fileManager)

        let root = try custom.rootURL()

        // The user-supplied path is used directly — no "LicenseCLI" subdirectory.
        #expect(root.standardizedFileURL.path == customRoot.standardizedFileURL.path)
        #expect(root.lastPathComponent != "LicenseCLI")
    }

    @Test
    func customCacheIsExemptFromGarbageCollection() throws {
        let customRoot = baseURL.appendingPathComponent("custom-\(UUID().uuidString)")
        let custom = CacheDirectory(customPath: customRoot.path, fileManager: fileManager)
        let root = try custom.rootURL()

        let stale = root.appendingPathComponent("stale@1.0.0")
        try fileManager.createDirectory(at: stale, withIntermediateDirectories: true)
        let oldDate = Date(timeIntervalSinceNow: -Double(CacheDirectory.timeToLiveDays + 10) * 24 * 60 * 60)
        try fileManager.setAttributes([.modificationDate: oldDate], ofItemAtPath: stale.path)

        custom.collectGarbage()

        // A custom cache is never pruned, even when entries are well past the TTL.
        #expect(fileManager.fileExists(atPath: stale.path))
    }
}
