import Foundation

public struct SwiftPackageValidator {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func validate(
        packageDirectoryPaths: [String],
        outputDirectoryPath: String,
        fileName: String
    ) throws {
        logger.trace("Validating \(packageDirectoryPaths.count) package directories")

        for packageDirectoryPath in packageDirectoryPaths {
            try validate(
                packageDirectoryPath: packageDirectoryPath,
                outputDirectoryPath: outputDirectoryPath,
                fileName: fileName
            )
        }

        logger.info("\(ANSIColor.colored("✓ Validation completed successfully", color: .green))")
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
                launchPath: "/usr/bin/env",
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

    public var errorDescription: String? {
        switch self {
        case .invalidPackagePath:
            "Package.swift could not be found"
        case .outputDirectoryIsEmpty:
            "Output Directory cannot be empty"
        case .fileNameIsEmpty:
            "name option cannot be empty"
        }
    }
}
