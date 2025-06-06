import Foundation

enum Command {
    @discardableResult
    static func run(
        launchPath: String,
        currentDirectoryPath: String? = nil,
        arguments: [String]
    ) throws -> String? {
        let data: Data? = try run(
            launchPath: launchPath,
            currentDirectoryPath: currentDirectoryPath,
            arguments: arguments
        )

        if let data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    @_disfavoredOverload
    static func run(
        launchPath: String,
        currentDirectoryPath: String? = nil,
        arguments: [String]
    ) throws -> Data? {
        let process = Process()
        process.launchPath = launchPath
        if let currentDirectoryPath {
            process.currentDirectoryPath = currentDirectoryPath
        }
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()

        return try? pipe.fileHandleForReading.readToEnd()
    }
}
