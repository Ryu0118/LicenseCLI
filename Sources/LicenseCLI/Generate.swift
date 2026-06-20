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

    @Option(name: .shortAndLong, help: "Output directory", completion: .directory)
    var outputDirectory: String

    @Option(name: .shortAndLong)
    var name: String = "Licenses"

    @Flag(name: .long, help: "Enable verbose logging")
    var verbose: Bool = false

    mutating func run() async throws {
        try await Runner().run(
            packageDirectoryPaths: projectDirectory,
            githubRepoURLs: githubRepo,
            packageDependenciesURLs: packageDeps,
            outputDirectoryPath: outputDirectory,
            fileName: name
        )
    }

    mutating func validate() throws {
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
