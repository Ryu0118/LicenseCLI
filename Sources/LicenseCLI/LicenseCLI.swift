import ArgumentParser
import LicenseCLICore

@main
struct LicenseCLI: AsyncParsableCommand {
    @Argument(help: "Directories where Package.swift is located")
    var projectDirectory: [String] = []

    @Option(name: .long, parsing: .upToNextOption, help: "GitHub repository URLs (e.g., https://github.com/owner/repo)")
    var githubRepo: [String] = []

    @Option(name: .long, parsing: .upToNextOption, help: "GitHub repository URLs with dependencies (e.g., https://github.com/owner/repo@1.0.0)")
    var packageDeps: [String] = []

    @Option(name: .long, help: "Cache directory for package dependencies clones (reuses existing clones if revision matches)")
    var packageDepsCacheDir: String?

    @Option(name: .shortAndLong, help: "Output directory")
    var outputDirectory: String

    @Option(name: .shortAndLong)
    var name: String = "Licenses"

    @Flag(name: .long, help: "Enable verbose logging")
    var verbose: Bool = false

    static let configuration = CommandConfiguration(commandName: "licensecli")

    mutating func run() async throws {
        try await Runner().run(
            packageDirectoryPaths: projectDirectory,
            githubRepoURLs: githubRepo,
            packageDependenciesURLs: packageDeps,
            packageDepsCacheDirectory: packageDepsCacheDir,
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
