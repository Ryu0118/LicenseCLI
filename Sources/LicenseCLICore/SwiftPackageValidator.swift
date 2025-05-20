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
        for packageDirectoryPath in packageDirectoryPaths {
            try validate(
                packageDirectoryPath: packageDirectoryPath,
                outputDirectoryPath: outputDirectoryPath,
                fileName: fileName
            )
        }
    }

    private func validate(
        packageDirectoryPath: String,
        outputDirectoryPath: String,
        fileName: String
    ) throws {
        let packageSwiftURL = URL(fileURLWithPath: packageDirectoryPath).appendingPathComponent("Package.swift")
        guard fileManager.fileExists(atPath: packageSwiftURL.path) else {
            throw SwiftPackageValidatorError.invalidPackagePath
        }
        guard !outputDirectoryPath.isEmpty else {
            throw SwiftPackageValidatorError.outputDirectoryIsEmpty
        }
        guard !fileName.isEmpty else {
            throw SwiftPackageValidatorError.fileNameIsEmpty
        }

        let packageResolveURL = URL(fileURLWithPath: packageDirectoryPath).appendingPathComponent("Package.resolved")
        if !fileManager.fileExists(atPath: packageResolveURL.path) {
            try Command.run(
                launchPath: "/usr/bin/env",
                currentDirectoryPath: packageDirectoryPath,
                arguments: ["swift", "package", "resolve"]
            )
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
