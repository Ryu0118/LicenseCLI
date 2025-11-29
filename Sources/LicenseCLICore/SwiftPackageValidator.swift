import Foundation

public struct SwiftPackageValidator {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func validate(
        packageDirectoryPaths: [String],
        githubRepoURLs: [String],
        outputDirectoryPath: String,
        fileName: String
    ) throws {
        logger.trace("Validating \(packageDirectoryPaths.count) package directories")
        logger.trace("Validating \(githubRepoURLs.count) GitHub repository URLs")

        guard !packageDirectoryPaths.isEmpty || !githubRepoURLs.isEmpty else {
            logger.error("No package directories or GitHub repository URLs provided")
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

        logger.info("\(ANSIColor.colored("✓ Validation completed successfully", color: .green))")
    }

    private func validateGitHubURL(_ urlString: String) throws {
        guard let url = URL(string: urlString),
              let host = url.host,
              host == "github.com" || host == "www.github.com" else {
            logger.error("Invalid GitHub URL: \(urlString)")
            throw SwiftPackageValidatorError.invalidGitHubURL(urlString)
        }

        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard pathComponents.count >= 2 else {
            logger.error("GitHub URL must contain owner and repository: \(urlString)")
            throw SwiftPackageValidatorError.invalidGitHubURL(urlString)
        }

        logger.trace("Valid GitHub URL: \(urlString)")
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

    public var errorDescription: String? {
        switch self {
        case .invalidPackagePath:
            "Package.swift could not be found"
        case .outputDirectoryIsEmpty:
            "Output Directory cannot be empty"
        case .fileNameIsEmpty:
            "name option cannot be empty"
        case .noInputProvided:
            "At least one package directory or GitHub repository URL must be provided"
        case .invalidGitHubURL(let url):
            "Invalid GitHub URL: \(url). URL must be in format https://github.com/owner/repo"
        }
    }
}
