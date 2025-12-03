import Foundation

public struct Runner {
    private let dependenciesLoader: DependenciesLoader
    private let licenseLoader: LicenseLoader
    private let packageDependenciesResolver: PackageDependenciesResolver

    public init(
        fileManager: FileManager = .default,
        jsonDecoder: JSONDecoder = .init(),
        urlSession: URLSession = .shared
    ) {
        self.dependenciesLoader = DependenciesLoader(fileManager: fileManager, jsonDecoder: jsonDecoder)
        self.licenseLoader = LicenseLoader(urlSession: urlSession)
        self.packageDependenciesResolver = PackageDependenciesResolver(
            fileManager: fileManager,
            dependenciesLoader: self.dependenciesLoader
        )
    }

    public func run(
        packageDirectoryPaths: [String],
        githubRepoURLs: [String],
        packageDependenciesURLs: [String],
        packageDepsCacheDirectory: String?,
        outputDirectoryPath: String,
        fileName: String
    ) async throws {
        logger.info("\(ANSIColor.colored("🚀 Starting license generation", color: .cyan))")
        logger.trace("Package directories: \(packageDirectoryPaths)")
        logger.trace("GitHub repository URLs: \(githubRepoURLs)")
        logger.trace("Package dependency URLs: \(packageDependenciesURLs)")
        logger.trace("Output directory: \(outputDirectoryPath)")
        logger.trace("File name: \(fileName)")

        var licenses = try await withThrowingTaskGroup(of: [License].self, returning: Set<License>.self) { group in
            for packageDirectoryPath in packageDirectoryPaths {
                logger.trace("Processing package directory: \(packageDirectoryPath)")
                group.addTask {
                    let dependencies = try dependenciesLoader.load(packageDirectoryPath: packageDirectoryPath)
                    return try await licenseLoader.load(for: dependencies)
                }
            }

            return try await group.reduce(into: Set<License>()) { partialResult, licenses in
                partialResult.formUnion(licenses)
            }
        }

        let githubLicenses = try await licenseLoader.load(for: githubRepoURLs)
        licenses.formUnion(githubLicenses)

        // Process package dependencies (--package-deps option)
        let packageDepsLicenses = try await processPackageDependencies(
            packageDependenciesURLs,
            cacheDirectory: packageDepsCacheDirectory
        )
        licenses.formUnion(packageDepsLicenses)

        logger.info("📦 Loaded \(licenses.count) unique licenses")

        let outputURL = URL(fileURLWithPath: outputDirectoryPath)
            .appendingPathComponent(fileName)
            .appendingPathExtension("swift")

        logger.trace("Writing licenses to: \(outputURL.path)")

        try SourceWriter.write(
            licenses: licenses.sorted(by: { $0.name < $1.name }),
            outputURL: outputURL
        )

        logger.info("\(ANSIColor.colored("✅ Successfully generated license file at \(outputURL.path)", color: .green))")
    }

    private func processPackageDependencies(_ packageDependenciesURLs: [String], cacheDirectory: String?) async throws -> Set<License> {
        guard !packageDependenciesURLs.isEmpty else { return [] }

        logger.info("🔧 Processing \(packageDependenciesURLs.count) package dependency URL(s)")

        return try await withThrowingTaskGroup(of: [License].self, returning: Set<License>.self) { group in
            for packageDepsURL in packageDependenciesURLs {
                group.addTask {
                    guard let repoWithVersion = GitHubRepoWithVersion(urlString: packageDepsURL) else {
                        logger.warning("Invalid package dependency URL: \(packageDepsURL)")
                        return []
                    }

                    logger.info("📦 Processing package: \(repoWithVersion.repo.identity) @ \(repoWithVersion.version.gitReference)")

                    var allLicenses: [License] = []

                    // First, fetch the license for the main package itself
                    if let mainPackageLicense = try await self.fetchMainPackageLicense(repoWithVersion: repoWithVersion) {
                        allLicenses.append(mainPackageLicense)
                        logger.trace("Fetched license for main package: \(repoWithVersion.repo.identity)")
                    }

                    // Then resolve and fetch licenses for all dependencies
                    if let dependencies = try self.packageDependenciesResolver.resolve(
                        repoWithVersion: repoWithVersion,
                        cacheDirectory: cacheDirectory
                    ) {
                        let dependencyLicenses = try await self.licenseLoader.load(for: dependencies)
                        allLicenses.append(contentsOf: dependencyLicenses)
                        logger.info("📚 Fetched \(dependencyLicenses.count) dependency licenses for \(repoWithVersion.repo.identity)")
                    } else {
                        logger.info("📦 Package \(repoWithVersion.repo.identity) has no dependencies")
                    }

                    return allLicenses
                }
            }

            return try await group.reduce(into: Set<License>()) { result, licenses in
                result.formUnion(licenses)
            }
        }
    }

    private func fetchMainPackageLicense(repoWithVersion: GitHubRepoWithVersion) async throws -> License? {
        let repo = repoWithVersion.repo
        let version = repoWithVersion.version.gitReference
        
        guard let licenseURL = repo.licenseURL(for: version),
              let licenseTxtURL = repo.licenseTxtURL(for: version),
              let licenseTxtURL2 = repo.licenseTxtURL2(for: version) else {
            return nil
        }

        // Fetch license for the specific version
        return try await licenseLoader.fetchLicense(
            identity: repo.identity,
            name: repo.name,
            licenseURL: licenseURL,
            licenseTxtURL: licenseTxtURL,
            licenseTxtURL2: licenseTxtURL2
        )
    }
}

public enum RunnerError: LocalizedError {
    case cannotReadPackageResolved
    case cannotFindLicenseURL(location: String)

    public var errorDescription: String? {
        switch self {
        case .cannotReadPackageResolved:
            "Package.resolved could not be loaded"
        case .cannotFindLicenseURL(let location):
            "License URL could not be found: (\(location))"
        }
    }
}
