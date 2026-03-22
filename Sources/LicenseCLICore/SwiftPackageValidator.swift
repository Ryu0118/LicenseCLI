import Foundation

public struct SwiftPackageValidator {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func validate(
        packageDirectoryPaths: [String],
        githubRepoURLs: [String],
        packageDependenciesURLs: [String],
        outputDirectoryPath: String,
        fileName: String
    ) throws {
        logger.trace("Validating \(packageDirectoryPaths.count) package directories")
        logger.trace("Validating \(githubRepoURLs.count) GitHub repository URLs")
        logger.trace("Validating \(packageDependenciesURLs.count) package dependency URLs")

        guard !packageDirectoryPaths.isEmpty || !githubRepoURLs.isEmpty || !packageDependenciesURLs.isEmpty else {
            logger.error("No package directories, GitHub repository URLs, or package dependency URLs provided")
            throw SwiftPackageValidatorError.noInputProvided
        }

        for packageDirectoryPath in packageDirectoryPaths {
            try validate(
                packageDirectoryPath: packageDirectoryPath,
                outputDirectoryPath: outputDirectoryPath,
                fileName: fileName
            )
        }

        for githubRepoURL in githubRepoURLs {
            try validateGitHubURL(githubRepoURL)
        }

        for packageDepsURL in packageDependenciesURLs {
            try validatePackageDepsURL(packageDepsURL)
        }

        if !packageDependenciesURLs.isEmpty {
            try validateGitAvailability()
        }

        logger.info("\(ANSIColor.colored("✓ Validation completed successfully", color: .green))")
    }

    private func validateGitHubURL(_ urlString: String) throws {
        guard GitHubRepo.parse(urlString: urlString) != nil else {
            logger.error("Invalid GitHub URL: \(urlString)")
            throw SwiftPackageValidatorError.invalidGitHubURL(urlString)
        }

        logger.trace("Valid GitHub URL: \(urlString)")
    }

    private func validatePackageDepsURL(_ urlString: String) throws {
        guard GitHubRepoWithVersion(urlString: urlString) != nil else {
            logger.error("Invalid package dependency URL: \(urlString)")
            throw SwiftPackageValidatorError.invalidPackageDepsURL(urlString)
        }

        logger.trace("Valid package dependency URL: \(urlString)")
    }

    private func validateGitAvailability() throws {
        guard GitOperations.isGitAvailable() else {
            logger.error("git command is not available")
            throw SwiftPackageValidatorError.gitNotAvailable
        }
        logger.trace("git is available")
    }

    private func validate(
        packageDirectoryPath: String,
        outputDirectoryPath: String,
        fileName: String
    ) throws {
        logger.trace("Validating package at: \(packageDirectoryPath)")

        let packageSwiftURL = URL(fileURLWithPath: packageDirectoryPath).appendingPathComponent("Package.swift")
        guard fileManager.fileExists(atPath: packageSwiftURL.path) else {
            logger.error("Package.swift not found at: \(packageSwiftURL.path)")
            throw SwiftPackageValidatorError.invalidPackagePath
        }
        guard !outputDirectoryPath.isEmpty else {
            logger.error("Output directory path is empty")
            throw SwiftPackageValidatorError.outputDirectoryIsEmpty
        }
        guard !fileName.isEmpty else {
            logger.error("File name is empty")
            throw SwiftPackageValidatorError.fileNameIsEmpty
        }

        let packageResolveURL = URL(fileURLWithPath: packageDirectoryPath).appendingPathComponent("Package.resolved")
        if !fileManager.fileExists(atPath: packageResolveURL.path) {
            logger.info("\(ANSIColor.colored("♻️ Resolving package dependencies", color: .yellow))")
            try Command.run(
                launchPath: "/usr/bin/xcrun",
                currentDirectoryPath: packageDirectoryPath,
                arguments: ["swift", "package", "resolve"]
            )
            logger.info("\(ANSIColor.colored("✓ Package resolved successfully", color: .green))")
        } else {
            logger.trace("Package.resolved exists at: \(packageResolveURL.path)")
        }
    }
}

public enum SwiftPackageValidatorError: LocalizedError {
    case invalidPackagePath
    case outputDirectoryIsEmpty
    case fileNameIsEmpty
    case noInputProvided
    case invalidGitHubURL(String)
    case invalidPackageDepsURL(String)
    case gitNotAvailable

    public var errorDescription: String? {
        switch self {
        case .invalidPackagePath:
            "Package.swift could not be found"
        case .outputDirectoryIsEmpty:
            "Output Directory cannot be empty"
        case .fileNameIsEmpty:
            "name option cannot be empty"
        case .noInputProvided:
            "At least one package directory, GitHub repository URL, or package dependency URL must be provided"
        case let .invalidGitHubURL(url):
            "Invalid GitHub URL: \(url). URL must be in format https://github.com/owner/repo[@version] or git@github.com:owner/repo.git[@version]"
        case let .invalidPackageDepsURL(url):
            "Invalid package dependency URL: \(url). URL must be in format https://github.com/owner/repo[@version] or git@github.com:owner/repo.git[@version]"
        case .gitNotAvailable:
            "git command is not available. Please install git to use --package-deps option"
        }
    }
}
