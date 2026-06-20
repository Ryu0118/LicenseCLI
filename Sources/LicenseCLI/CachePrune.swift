import ArgumentParser
import LicenseCLICore

/// Removes every cached package clone from the global cache directory.
///
/// Cached clones are normally reused across projects and pruned automatically
/// once unused beyond the TTL. This command clears the entire cache on demand.
struct CachePrune: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cache-prune",
        abstract: "Remove all cached package dependency clones"
    )

    @Flag(name: .long, help: "Enable verbose logging")
    var verbose: Bool = false

    func run() throws {
        LicenseCLICore.setupLogging(verbose: verbose)
        let removed = try CacheDirectory().prune()
        print("🧹 Pruned \(removed) cached package clone(s)")
    }
}
