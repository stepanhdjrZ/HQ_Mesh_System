import Foundation

enum LogLevel {
    case info
    case debug
    case warning
    case error
    case security // 🎯 Тот самый уровень, который искал компилятор
}

final class LoggerService {
    static func log(_ message: String, level: LogLevel = .info) {
        let prefix: String
        switch level {
        case .info: prefix = "ℹ️ INFO"
        case .debug: prefix = "🐛 DEBUG"
        case .warning: prefix = "⚠️ WARNING"
        case .error: prefix = "❌ ERROR"
        case .security: prefix = "🛡 SECURITY"
        }
        
        print("\(prefix) | \(message)")
    }
}
