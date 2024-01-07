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
        packageDirectoryPath: String,
        outputDirectoryPath: String,
        fileName: String
    ) async throws {
        let dependencies = try dependenciesLoader.load(packageDirectoryPath: packageDirectoryPath)
        let licenses = try await licenseLoader.load(for: dependencies)
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
