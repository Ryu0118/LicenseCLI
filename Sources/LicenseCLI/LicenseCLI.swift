import ArgumentParser

@main
struct LicenseCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "licensecli",
        abstract: "Generate a Swift license file from packages and dependencies.",
        subcommands: [Generate.self, CachePrune.self],
        defaultSubcommand: Generate.self
    )
}
