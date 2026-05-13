import Foundation

/// Глобальный сервис логирования с поддержкой уровней важности
final class LoggerService {
    enum LogLevel: String {
        case info = "ℹ️ INFO"
        case warning = "⚠️ WARNING"
        case error = "🚨 ERROR"
        case security = "🛡 SECURITY"
    }
    
    static func log(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        let timestamp = Date().hqFormat() // Используем наш Extension
        let logString = "[\(timestamp)] [\(level.rawValue)] [\(fileName) -> \(function)]: \(message)"
        
        // В будущем здесь будет запись в файл для отправки разработчику (как в ТГ)
        print(logString)
        #endif
    }
}
