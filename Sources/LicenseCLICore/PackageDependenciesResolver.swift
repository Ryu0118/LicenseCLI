import Foundation

enum PackageDependenciesResolverError: LocalizedError {
    case invalidURL(String)
    case packageResolveFailed(String)
    case temporaryDirectoryCreationFailed
    case noPackageResolvedGenerated

    var errorDescription: String? {
        switch self {
        case let .invalidURL(url):
            "Invalid package URL: \(url)"
        case let .packageResolveFailed(message):
            "Failed to resolve package: \(message)"
        case .temporaryDirectoryCreationFailed:
            "Failed to create temporary directory"
        case .noPackageResolvedGenerated:
            "Package.resolved was not generated (package may have no dependencies)"
        }
    }
}

struct PackageDependenciesResolver {
    let fileManager: FileManager
    let dependenciesLoader: DependenciesLoader

    /// The cache to use, or `nil` to clone into a temporary directory discarded after
    /// the run (`--no-cache`).
    let cacheDirectory: CacheDirectory?

    init(
        fileManager: FileManager = .default,
        dependenciesLoader: DependenciesLoader = DependenciesLoader(
            fileManager: .default,
            jsonDecoder: JSONDecoder()
        ),
        cacheDirectory: CacheDirectory? = CacheDirectory()
    ) {
        self.fileManager = fileManager
        self.dependenciesLoader = dependenciesLoader
        self.cacheDirectory = cacheDirectory
    }

    /// Resolve dependencies for a package from a GitHub repository.
    ///
    /// When a cache is configured, clones are reused across runs keyed by
    /// `owner-name@version`; otherwise the clone is made in a temporary directory and
    /// discarded. Returns the dependencies from Package.resolved, or nil if none exist.
    func resolve(repoWithVersion: GitHubRepoWithVersion) throws -> Dependencies? {
        logger.info("🔍 Resolving dependencies for \(repoWithVersion.repo.identity)")

        let workDirectory: URL
        let shouldCleanup: Bool

        if let cacheDirectory {
            workDirectory = try cachedClone(repoWithVersion: repoWithVersion, in: cacheDirectory)
            shouldCleanup = false
        } else {
            workDirectory = try createTemporaryDirectory()
            shouldCleanup = true
            logger.trace("Created temporary directory: \(workDirectory.path)")
            try cloneRepository(repoWithVersion: repoWithVersion, to: workDirectory)
        }

        defer {
            if shouldCleanup {
                cleanup(directory: workDirectory)
            }
        }

        // Run swift package resolve
        let packageResolvedExists = try runSwiftPackageResolve(at: workDirectory)

        // If Package.resolved was not generated, the package has no dependencies
        guard packageResolvedExists else {
            logger.info("📦 Package has no dependencies")
            return nil
        }

        // Load and return dependencies
        return try dependenciesLoader.load(packageDirectoryPath: workDirectory.path)
    }

    /// Returns a ready-to-use clone in the cache, reusing an existing one when its
    /// revision matches and re-cloning otherwise.
    private func cachedClone(repoWithVersion: GitHubRepoWithVersion, in cacheDirectory: CacheDirectory) throws -> URL {
        let repoCacheDir = try cacheDirectory.entryURL(for: repoWithVersion)

        let workDirectory: URL
        // Check if cached directory exists and has the correct revision
        if let existingDir = try getExistingCacheDirectory(repoWithVersion: repoWithVersion, cacheDir: repoCacheDir) {
            logger.info("♻️ Using cached clone at \(existingDir.path)")
            workDirectory = existingDir
        } else {
            // Remove existing directory if it exists but has wrong revision
            if fileManager.fileExists(atPath: repoCacheDir.path) {
                logger.info("🗑️ Removing outdated cache directory: \(repoCacheDir.path)")
                try? fileManager.removeItem(at: repoCacheDir)
            }

            // Create cache directory and clone
            try fileManager.createDirectory(
                at: repoCacheDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
            logger.info("📥 Cloning to cache directory: \(repoCacheDir.path)")
            try cloneRepository(repoWithVersion: repoWithVersion, to: repoCacheDir)
            workDirectory = repoCacheDir
        }

        // Mark this entry as recently used so the TTL collector keeps it around.
        cacheDirectory.touch(workDirectory)
        return workDirectory
    }

    private func createTemporaryDirectory() throws -> URL {
        let tempDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("licensecli-\(UUID().uuidString)")

        do {
            try fileManager.createDirectory(
                at: tempDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            return tempDirectory
        } catch {
            logger.error("Failed to create temporary directory: \(error)")
            throw PackageDependenciesResolverError.temporaryDirectoryCreationFailed
        }
    }

    private func cleanup(directory: URL) {
        do {
            try fileManager.removeItem(at: directory)
            logger.trace("Cleaned up temporary directory: \(directory.path)")
        } catch {
            logger.warning("Failed to cleanup temporary directory: \(error)")
        }
    }

    private func cloneRepository(repoWithVersion: GitHubRepoWithVersion, to destination: URL) throws {
        let cloneURL = repoWithVersion.cloneURL
        let reference = repoWithVersion.version.gitReference

        logger.info("📥 Cloning \(cloneURL) @ \(reference)")

        do {
            // Clone with the specific reference if not HEAD
            if repoWithVersion.version != .head {
                try GitOperations.clone(
                    repoURL: cloneURL,
                    to: destination,
                    reference: reference
                )
            } else {
                try GitOperations.clone(
                    repoURL: cloneURL,
                    to: destination
                )
            }
        } catch {
            logger.error("Failed to clone repository: \(error)")
            throw error
        }
    }

    private func runSwiftPackageResolve(at directory: URL) throws -> Bool {
        logger.info("♻️ Resolving package dependencies...")

        do {
            try Command.run(
                launchPath: "/usr/bin/xcrun",
                currentDirectoryPath: directory.path,
                arguments: ["swift", "package", "resolve"]
            )
            logger.info("✅ Package resolved successfully")

            // Check if Package.resolved was generated
            let packageResolvedURL = directory.appendingPathComponent("Package.resolved")
            let exists = fileManager.fileExists(atPath: packageResolvedURL.path)

            if !exists {
                logger.trace("Package.resolved not found - package has no dependencies")
            }

            return exists
        } catch {
            logger.error("Failed to resolve package: \(error)")
            throw PackageDependenciesResolverError.packageResolveFailed(error.localizedDescription)
        }
    }

    /// Check if an existing cache directory exists and can be used for the target revision
    /// Returns the directory URL if it's valid, nil otherwise
    private func getExistingCacheDirectory(repoWithVersion: GitHubRepoWithVersion, cacheDir: URL) throws -> URL? {
        guard fileManager.fileExists(atPath: cacheDir.path) else {
            return nil
        }

        // Check if it's a git repository
        guard GitOperations.isGitRepository(at: cacheDir) else {
            logger.trace("Cache directory exists but is not a git repository: \(cacheDir.path)")
            return nil
        }

        let targetReference = repoWithVersion.version.gitReference

        // For HEAD, we need to fetch latest changes first
        if repoWithVersion.version == .head {
            do {
                // Fetch latest changes
                try Command.run(
                    launchPath: "/usr/bin/git",
                    currentDirectoryPath: cacheDir.path,
                    arguments: ["fetch", "origin"]
                )
                // Checkout HEAD
                try GitOperations.checkout(reference: "HEAD", at: cacheDir)
                logger.trace("Updated cached repository to latest HEAD")
                return cacheDir
            } catch {
                logger.trace("Failed to update cached repository for HEAD: \(error.localizedDescription)")
                return nil
            }
        } else {
            // For specific references, try to checkout
            do {
                // First, try to fetch the reference if it's a branch or tag
                _ = try? Command.run(
                    launchPath: "/usr/bin/git",
                    currentDirectoryPath: cacheDir.path,
                    arguments: ["fetch", "origin", targetReference]
                )

                // Checkout the reference
                try GitOperations.checkout(reference: targetReference, at: cacheDir)

                // Verify the current revision matches the target
                if let currentRevision = try? GitOperations.getCurrentRevision(at: cacheDir),
                   let targetRevision = try? GitOperations.getRevision(for: targetReference, at: cacheDir),
                   currentRevision == targetRevision
                {
                    logger.trace("Cache directory has matching revision: \(currentRevision)")
                    return cacheDir
                } else {
                    logger.trace("Cache directory revision does not match target")
                    return nil
                }
            } catch {
                logger.trace("Failed to checkout \(targetReference) in cached repository: \(error.localizedDescription)")
                return nil
            }
        }
    }
}
