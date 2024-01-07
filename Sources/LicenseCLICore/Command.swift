import Foundation

enum Command {
    @discardableResult
    static func run(
        launchPath: String,
        currentDirectoryPath: String? = nil,
        arguments: [String]
    ) throws -> String? {
        let process = Process()
        process.launchPath = launchPath
        if let currentDirectoryPath {
            process.currentDirectoryPath = currentDirectoryPath
        }
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()

        let data = try? pipe.fileHandleForReading.readToEnd()
        
        if let data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
}
