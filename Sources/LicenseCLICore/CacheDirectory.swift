import Foundation

/// Where package dependency clones should be cached for a run.
public enum CacheLocation: Equatable {
    /// The global, OS-managed cache (the default).
    case global
    /// A user-supplied directory used directly (`--package-deps-cache-dir`).
    case custom(path: String)
    /// No caching; clones go to a temporary directory discarded after the run (`--no-cache`).
    case disabled

    /// The cache to use, or `nil` when caching is disabled.
    public func cacheDirectory(fileManager: FileManager = .default) -> CacheDirectory? {
        switch self {
        case .global:
            CacheDirectory(fileManager: fileManager)
        case let .custom(path):
            CacheDirectory(customPath: path, fileManager: fileManager)
        case .disabled:
            nil
        }
    }
}

/// Manages a cache directory for package dependency clones.
///
/// Clones are keyed only by `owner-name@version` (not by project path), so the same
/// library at the same version is shared across runs — similar to a pnpm-style store.
///
/// Two layouts exist:
/// - **global** (the default): the OS cache directory with a `LicenseCLI` subdirectory
///   appended — `~/Library/Caches/LicenseCLI` on macOS, `~/.cache/LicenseCLI` on Linux
///   (via `FileManager`'s `.cachesDirectory`). Eligible for automatic TTL garbage
///   collection.
/// - **custom** (`--package-deps-cache-dir`): the user-supplied path used directly,
///   with no subdirectory appended and no TTL garbage collection, preserving the prior
///   behavior of that option.
public struct CacheDirectory {
    /// Number of days a cached clone may remain unused before it is eligible for
    /// automatic time-to-live (TTL) garbage collection.
    static let timeToLiveDays = 30

    let fileManager: FileManager

    /// Whether this is the global, OS-managed cache. Only the global cache is subject
    /// to automatic TTL garbage collection.
    let isGlobal: Bool

    /// Resolves the root cache directory (already including any `LicenseCLI` subdir).
    /// Overridable for testing.
    private let resolveRootURL: () throws -> URL

    /// The global OS cache (`<OS caches>/LicenseCLI`).
    public init(fileManager: FileManager = .default) {
        self.init(fileManager: fileManager, isGlobal: true) {
            try fileManager.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            .appendingPathComponent("LicenseCLI")
        }
    }

    /// A custom cache at `path`, used directly without a `LicenseCLI` subdirectory and
    /// exempt from TTL garbage collection (preserving the prior `--package-deps-cache-dir`
    /// behavior).
    public init(customPath: String, fileManager: FileManager = .default) {
        self.init(fileManager: fileManager, isGlobal: false) {
            URL(fileURLWithPath: customPath)
        }
    }

    init(fileManager: FileManager, isGlobal: Bool, resolveRootURL: @escaping () throws -> URL) {
        self.fileManager = fileManager
        self.isGlobal = isGlobal
        self.resolveRootURL = resolveRootURL
    }

    /// The root cache directory, created if needed.
    func rootURL() throws -> URL {
        let rootURL = try resolveRootURL()
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
    /// Only applies to the global cache; a custom cache directory is left untouched.
    /// Called automatically on each run. Failures are logged and ignored — GC must
    /// never break a license-generation run.
    func collectGarbage() {
        guard isGlobal else { return }
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
