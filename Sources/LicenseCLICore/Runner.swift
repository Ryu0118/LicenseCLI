import Foundation

public struct Runner {
    private let dependenciesLoader: DependenciesLoader
    private let licenseLoader: LicenseLoader

    public init(
        fileManager: FileManager = .default,
        jsonDecoder: JSONDecoder = .init(),
        urlSession: URLSession = .shared
    ) {
        self.dependenciesLoader = DependenciesLoader(fileManager: fileManager, jsonDecoder: jsonDecoder)
        self.licenseLoader = LicenseLoader(urlSession: urlSession)
    }

    public func run(
        packageDirectoryPaths: [String],
        githubRepoURLs: [String],
        outputDirectoryPath: String,
        fileName: String
    ) async throws {
        logger.info("\(ANSIColor.colored("🚀 Starting license generation", color: .cyan))")
        logger.trace("Package directories: \(packageDirectoryPaths)")
        logger.trace("GitHub repository URLs: \(githubRepoURLs)")
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
