import Foundation
import SwiftUI

/// Глобальные константы протокола HQ Global
public struct AppConstants {
    // MARK: - Сетевые параметры
    public static let serviceType = "hq-mesh-v10"
    
    // 🎯 Твой текущий активный мост через Serveo
    // Вставляем ту самую длинную ссылку без https://
    public static let serverDomain = "9b364d966cd3e83e-77-239-126-212.serveousercontent.com"
    
    // Автоматическая сборка URL для разных типов связи
    public static let apiURL = "https://\(serverDomain)"
    public static let serverURL = "wss://\(serverDomain)/ws"
    
    public static let reconnectInterval: TimeInterval = 7.0
    
    // MARK: - Дизайн-система (Премиальный темный интерфейс)
    public struct UI {
        public static let mainBackground = Color(red: 0.01, green: 0.02, blue: 0.06)
        public static let accentColor = Color.cyan
        public static let glassOpacity: Double = 0.08
        public static let cornerRadius: CGFloat = 20.0
    }
    
    // MARK: - Безопасность
    public static let maxMessageLength = 8192
    public static let sessionTimeout: TimeInterval = 3600
}
