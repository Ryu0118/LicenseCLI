import ArgumentParser
import LicenseCLICore

/// Generates a Swift license file from package directories, GitHub repositories,
/// and package dependencies.
///
/// Package dependency clones are cached in a global, project-shared cache directory
/// and reused across runs. Stale entries are pruned automatically; use the
/// `cache-prune` subcommand to clear the cache manually.
struct Generate: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "generate",
        abstract: "Generate a license file (default command)"
    )

    @Argument(help: "Directories where Package.swift is located", completion: .directory)
    var projectDirectory: [String] = []

    @Option(name: .long, parsing: .upToNextOption, help: "GitHub repository URLs (e.g., https://github.com/owner/repo or git@github.com:owner/repo.git)")
    var githubRepo: [String] = []

    @Option(name: .long, parsing: .upToNextOption, help: "GitHub repository URLs with dependencies (e.g., https://github.com/owner/repo@1.0.0 or git@github.com:owner/repo.git@1.0.0)")
    var packageDeps: [String] = []

    @Option(
        name: .long,
        help: "Cache package dependency clones in this directory instead of the global cache (no automatic pruning)",
        completion: .directory
    )
    var packageDepsCacheDir: String?

    @Flag(name: .long, help: "Disable caching; clone package dependencies into a temporary directory discarded after the run")
    var noCache: Bool = false

    @Option(name: .shortAndLong, help: "Output directory", completion: .directory)
    var outputDirectory: String

    @Option(name: .shortAndLong)
    var name: String = "Licenses"

    @Flag(name: .long, help: "Enable verbose logging")
    var verbose: Bool = false

    var cacheLocation: CacheLocation {
        if noCache {
            .disabled
        } else if let packageDepsCacheDir {
            .custom(path: packageDepsCacheDir)
        } else {
            .global
        }
    }

    mutating func run() async throws {
        try await Runner().run(
            packageDirectoryPaths: projectDirectory,
            githubRepoURLs: githubRepo,
            packageDependenciesURLs: packageDeps,
            cacheLocation: cacheLocation,
            outputDirectoryPath: outputDirectory,
            fileName: name
        )
    }

    mutating func validate() throws {
        // Validate cheap, conflicting flags before the side-effecting logging init.
        if noCache, packageDepsCacheDir != nil {
            throw ValidationError("--no-cache and --package-deps-cache-dir cannot be used together")
        }

        LicenseCLICore.setupLogging(verbose: verbose)

        try SwiftPackageValidator().validate(
            packageDirectoryPaths: projectDirectory,
            githubRepoURLs: githubRepo,
            packageDependenciesURLs: packageDeps,
            outputDirectoryPath: outputDirectory,
            fileName: name
        )
    }
}
