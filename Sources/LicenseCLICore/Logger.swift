import Foundation
import Logging

package let logger = Logger(label: "me.ryu0118.licensecli")

package func setupLogging(verbose: Bool) {
    LoggingSystem.bootstrap { label in
        var handler = ColoredLogHandler(label: label)
        handler.logLevel = verbose ? .trace : .info
        return handler
    }
}

struct ColoredLogHandler: LogHandler {
    private var _logLevel: Logger.Level = .info
    private let label: String

    var logLevel: Logger.Level {
        get { _logLevel }
        set { _logLevel = newValue }
    }

    var metadata: Logger.Metadata = [:]

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    init(label: String) {
        self.label = label
    }

    func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        let formattedMessage = switch level {
        case .trace:
            "\(ANSIColor.gray.code)🔍 [TRACE] \(message)\(ANSIColor.reset.code)"
        case .debug:
            "\(ANSIColor.cyan.code)🐛 [DEBUG] \(message)\(ANSIColor.reset.code)"
        case .info:
            // For info level, the message should already contain the emoji, no fixed color
            "\(message)"
        case .notice:
            "\(ANSIColor.blue.code)📢 [NOTICE] \(message)\(ANSIColor.reset.code)"
        case .warning:
            "\(ANSIColor.yellow.code)⚠️ [WARNING] \(message)\(ANSIColor.reset.code)"
        case .error:
            "\(ANSIColor.red.code)❌ [ERROR] \(message)\(ANSIColor.reset.code)"
        case .critical:
            "\(ANSIColor.magenta.code)🔥 [CRITICAL] \(message)\(ANSIColor.reset.code)"
        }

        print(formattedMessage)
    }
}

package enum ANSIColor {
    case black
    case red
    case green
    case yellow
    case blue
    case magenta
    case cyan
    case white
    case gray
    case reset

    package var code: String {
        switch self {
        case .black: "\u{001B}[30m"
        case .red: "\u{001B}[31m"
        case .green: "\u{001B}[32m"
        case .yellow: "\u{001B}[33m"
        case .blue: "\u{001B}[34m"
        case .magenta: "\u{001B}[35m"
        case .cyan: "\u{001B}[36m"
        case .white: "\u{001B}[37m"
        case .gray: "\u{001B}[90m"
        case .reset: "\u{001B}[0m"
        }
    }

    package static func colored(_ message: String, color: ANSIColor) -> String {
        "\(color.code)\(message)\(ANSIColor.reset.code)"
    }
}
