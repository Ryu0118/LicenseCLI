import Foundation

enum PackageDependenciesResolverError: LocalizedError {
    case invalidURL(String)
    case packageResolveFailed(String)
    case temporaryDirectoryCreationFailed
    case noPackageResolvedGenerated

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid package URL: \(url)"
        case .packageResolveFailed(let message):
            return "Failed to resolve package: \(message)"
        case .temporaryDirectoryCreationFailed:
            return "Failed to create temporary directory"
        case .noPackageResolvedGenerated:
            return "Package.resolved was not generated (package may have no dependencies)"
        }
    }
}

struct PackageDependenciesResolver {
    let fileManager: FileManager
    let dependenciesLoader: DependenciesLoader

    init(
        fileManager: FileManager = .default,
        dependenciesLoader: DependenciesLoader = DependenciesLoader(
            fileManager: .default,
            jsonDecoder: JSONDecoder()
        )
    ) {
        self.fileManager = fileManager
        self.dependenciesLoader = dependenciesLoader
    }

    /// Resolve dependencies for a package from a GitHub repository
    /// Returns the dependencies from Package.resolved, or nil if no dependencies exist
    func resolve(repoWithVersion: GitHubRepoWithVersion) throws -> Dependencies? {
        logger.info("🔍 Resolving dependencies for \(repoWithVersion.repo.identity)")

        // Create temporary directory
        let tempDirectory = try createTemporaryDirectory()
        defer {
            cleanup(directory: tempDirectory)
        }

        logger.trace("Created temporary directory: \(tempDirectory.path)")

        // Clone the repository with the specified version
        try cloneRepository(repoWithVersion: repoWithVersion, to: tempDirectory)

        // Run swift package resolve
        let packageResolvedExists = try runSwiftPackageResolve(at: tempDirectory)

        // If Package.resolved was not generated, the package has no dependencies
        guard packageResolvedExists else {
            logger.info("📦 Package has no dependencies")
            return nil
        }

        // Load and return dependencies
        let dependencies = try dependenciesLoader.load(packageDirectoryPath: tempDirectory.path)
        return dependencies
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

    private func cleanup(directory: URL) {
        do {
            try fileManager.removeItem(at: directory)
            logger.trace("Cleaned up temporary directory: \(directory.path)")
        } catch {
            logger.warning("Failed to cleanup temporary directory: \(error)")
        }
    }
}
