import Foundation

struct DependenciesLoader {
    let fileManager: FileManager
    let jsonDecoder: JSONDecoder

    func load(packageDirectoryPath: String) throws -> Dependencies {
        let packageResolvedURL = URL(fileURLWithPath: packageDirectoryPath).appendingPathComponent("Package.resolved")
        guard let packageResolvedData = fileManager.contents(atPath: packageResolvedURL.path)
        else {
            throw RunnerError.cannotReadPackageResolved
        }
        return try jsonDecoder.decode(Dependencies.self, from: packageResolvedData)
    }
}
