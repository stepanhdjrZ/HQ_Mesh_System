import Foundation

/// Системный регистратор событий HQ
public final class LoggerService {
    public enum EventType: String {
        case info = "🔵 INFO"
        case mesh = "🌐 MESH"
        case cloud = "☁️ CLOUD"
        case error = "🔴 ERROR"
        case safety = "🛡 SAFETY"
    }
    
    /// Запись события в системный лог
    public static func log(_ message: String, type: EventType = .info) {
        #if DEBUG
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [\(type.rawValue)] \(message)")
        #endif
    }
}
