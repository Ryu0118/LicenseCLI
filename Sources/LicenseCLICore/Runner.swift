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
        outputDirectoryPath: String,
        fileName: String
    ) async throws {
        let licenses = try await withThrowingTaskGroup(of: [License].self, returning: [License].self) { group in
            for packageDirectoryPath in packageDirectoryPaths {
                group.addTask {
                    let dependencies = try dependenciesLoader.load(packageDirectoryPath: packageDirectoryPath)
                    return try await licenseLoader.load(for: dependencies)
                }
            }

            return try await group.reduce(into: [License]()) { partialResult, license in
                partialResult.append(contentsOf: license)
            }
        }
        try SourceWriter.write(
            licenses: licenses,
            outputURL: URL(fileURLWithPath: outputDirectoryPath)
                .appendingPathComponent(fileName)
                .appendingPathExtension("swift")
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
