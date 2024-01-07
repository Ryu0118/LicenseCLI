import ArgumentParser
import LicenseCLICore

@main
struct LicenseCLI: AsyncParsableCommand {
    @Argument(help: "Directory where Package.swift is located") 
    var projectDirectory: String

    @Argument(help: "Output directory")
    var outputDirectory: String

    @Option(name: .shortAndLong)
    var name: String = "Licenses"

    static let configuration = CommandConfiguration(commandName: "licensecli")

    mutating func run() async throws {
        try await Runner().run(
            packageDirectoryPath: projectDirectory,
            outputDirectoryPath: outputDirectory,
            fileName: name
        )
    }

    mutating func validate() throws {
        try SwiftPackageValidator().validate(
            packageDirectoryPath: projectDirectory,
            outputDirectoryPath: outputDirectory,
            fileName: name
        )
    }
}
