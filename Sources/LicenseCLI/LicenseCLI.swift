import ArgumentParser
import LicenseCLICore

@main
struct LicenseCLI: AsyncParsableCommand {
    @Argument(help: "Directories where Package.swift is located")
    var projectDirectory: [String]

    @Option(name: .shortAndLong, help: "Output directory")
    var outputDirectory: String

    @Option(name: .shortAndLong)
    var name: String = "Licenses"

    static let configuration = CommandConfiguration(commandName: "licensecli")

    mutating func run() async throws {
        try await Runner().run(
            packageDirectoryPaths: projectDirectory,
            outputDirectoryPath: outputDirectory,
            fileName: name
        )
    }

    mutating func validate() throws {
        try SwiftPackageValidator().validate(
            packageDirectoryPaths: projectDirectory,
            outputDirectoryPath: outputDirectory,
            fileName: name
        )
    }
}
