import Foundation

struct DependenciesLoader {
    let fileManager: FileManager
    let jsonDecoder: JSONDecoder

    func load(packageDirectoryPath: String) throws -> Dependencies {
        let packageResolvedURL = URL(fileURLWithPath: packageDirectoryPath).appendingPathComponent("Package.resolved")
        logger.trace("Loading Package.resolved from: \(packageResolvedURL.path)")

        guard let packageResolvedData = fileManager.contents(atPath: packageResolvedURL.path)
        else {
            logger.error("Failed to read Package.resolved at: \(packageResolvedURL.path)")
            throw RunnerError.cannotReadPackageResolved
        }

        let dependencies = try jsonDecoder.decode(Dependencies.self, from: packageResolvedData)
        logger.info("📚 Loaded \(dependencies.pins.count) dependencies from Package.resolved")
        logger.trace("Dependencies: \(dependencies.pins.map { $0.identity }.joined(separator: ", "))")

        return dependencies
    }
}
