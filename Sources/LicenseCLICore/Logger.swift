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
        let formattedMessage: String

        switch level {
        case .trace:
            formattedMessage = "\(ANSIColor.gray.code)🔍 [TRACE] \(message)\(ANSIColor.reset.code)"
        case .debug:
            formattedMessage = "\(ANSIColor.cyan.code)🐛 [DEBUG] \(message)\(ANSIColor.reset.code)"
        case .info:
            // For info level, the message should already contain the emoji, no fixed color
            formattedMessage = "\(message)"
        case .notice:
            formattedMessage = "\(ANSIColor.blue.code)📢 [NOTICE] \(message)\(ANSIColor.reset.code)"
        case .warning:
            formattedMessage = "\(ANSIColor.yellow.code)⚠️ [WARNING] \(message)\(ANSIColor.reset.code)"
        case .error:
            formattedMessage = "\(ANSIColor.red.code)❌ [ERROR] \(message)\(ANSIColor.reset.code)"
        case .critical:
            formattedMessage = "\(ANSIColor.magenta.code)🔥 [CRITICAL] \(message)\(ANSIColor.reset.code)"
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
        case .black: return "\u{001B}[30m"
        case .red: return "\u{001B}[31m"
        case .green: return "\u{001B}[32m"
        case .yellow: return "\u{001B}[33m"
        case .blue: return "\u{001B}[34m"
        case .magenta: return "\u{001B}[35m"
        case .cyan: return "\u{001B}[36m"
        case .white: return "\u{001B}[37m"
        case .gray: return "\u{001B}[90m"
        case .reset: return "\u{001B}[0m"
        }
    }

    package static func colored(_ message: String, color: ANSIColor) -> String {
        "\(color.code)\(message)\(ANSIColor.reset.code)"
    }
}
