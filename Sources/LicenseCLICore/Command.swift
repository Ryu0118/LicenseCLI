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
        let commandString = ([launchPath] + arguments).joined(separator: " ")
        logger.trace("Executing command: \(commandString)")
        if let currentDirectoryPath {
            logger.trace("Working directory: \(currentDirectoryPath)")
        }

        let process = Process()
        process.launchPath = launchPath
        if let currentDirectoryPath {
            process.currentDirectoryPath = currentDirectoryPath
        }
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()

        let result = try? pipe.fileHandleForReading.readToEnd()
        logger.trace("Command completed successfully")

        return result
    }
}
