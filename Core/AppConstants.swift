import Foundation
import SwiftUI

struct AppConstants {
    // Сетевые идентификаторы
    static let serviceType = "hq-global-v7" // Версия протокола
    static let serverURL = "wss://elevation-strength-authentic.ngrok-free.dev/ws"
    
    // Лимиты и тайминги
    static let heartbeatInterval: TimeInterval = 25.0
    static let maxMessageLength = 4096
    static let reconnectDelay: TimeInterval = 5.0
    
    // Дизайн-система
    struct Colors {
        static let mainBackground = Color(red: 0.01, green: 0.02, blue: 0.06)
        static let accentCyan = Color.cyan
        static let glassBackground = Color.white.opacity(0.06)
    }
}
