import Foundation

/// Manages the global cache directory for package dependency clones.
///
/// Clones are stored in the OS cache directory, keyed only by `owner-name@version`
/// (not by project path), so the same library at the same version is shared across
/// all projects — similar to a pnpm-style global store.
///
/// On macOS this resolves to `~/Library/Caches/LicenseCLI`, and on Linux to
/// `~/.cache/LicenseCLI` (XDG), via `FileManager`'s `.cachesDirectory`.
public struct CacheDirectory {
    /// Number of days a cached clone may remain unused before it is eligible for
    /// automatic time-to-live (TTL) garbage collection.
    static let timeToLiveDays = 30

    let fileManager: FileManager

    /// Resolves the base directory that `LicenseCLI` is appended to. Defaults to the
    /// OS caches directory; overridable for testing.
    private let baseDirectoryURL: () throws -> URL

    public init(fileManager: FileManager = .default) {
        self.init(fileManager: fileManager) {
            try fileManager.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        }
    }

    init(fileManager: FileManager, baseDirectoryURL: @escaping () throws -> URL) {
        self.fileManager = fileManager
        self.baseDirectoryURL = baseDirectoryURL
    }

    /// The root cache directory (`<base>/LicenseCLI`), created if needed.
    func rootURL() throws -> URL {
        let rootURL = try baseDirectoryURL().appendingPathComponent("LicenseCLI")
        // `withIntermediateDirectories: true` is idempotent and does not throw if it exists.
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        return rootURL
    }

    /// The cache directory for a specific repository and version.
    ///
    /// Entries are keyed only by `owner-name@version` (not by project path), so the
    /// same library at the same version is shared across all projects.
    func entryURL(for repoWithVersion: GitHubRepoWithVersion) throws -> URL {
        let repo = repoWithVersion.repo
        let version = repoWithVersion.version.gitReference
        // Sanitize the directory name: replace path separators (/ and :) with -.
        let dirName = "\(repo.owner)-\(repo.name)@\(version)"
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return try rootURL().appendingPathComponent(dirName)
    }

    /// Marks a cache entry as recently used by updating its modification date.
    ///
    /// The TTL garbage collector relies on this timestamp to decide what is stale,
    /// so every cache hit/creation must touch the entry.
    func touch(_ url: URL) {
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
    }

    /// Removes cache entries whose last use is older than `timeToLiveDays`.
    ///
    /// Called automatically on each run. Failures are logged and ignored — GC must
    /// never break a license-generation run.
    func collectGarbage() {
        guard let rootURL = try? rootURL() else { return }

        let cutoff = Date(timeIntervalSinceNow: -Double(Self.timeToLiveDays) * 24 * 60 * 60)
        let entries = (try? fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        for entry in entries {
            let modificationDate = (try? entry.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate
            guard let modificationDate, modificationDate < cutoff else { continue }

            logger.trace("🧹 Removing stale cache entry: \(entry.lastPathComponent)")
            try? fileManager.removeItem(at: entry)
        }
    }

    /// Removes every cache entry (the `prune` command).
    /// Returns the number of entries removed.
    @discardableResult
    public func prune() throws -> Int {
        let rootURL = try rootURL()
        let entries = try fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        for entry in entries {
            try fileManager.removeItem(at: entry)
        }
        return entries.count
    }
}
