import Foundation
import SwiftUI

/// Глобальные константы протокола HQ Global
public struct AppConstants {
    // MARK: - Сетевые параметры
    public static let serviceType = "hq-mesh-v10"
    public static let serverURL = "wss://elevation-strength-authentic.ngrok-free.dev/ws"
    public static let reconnectInterval: TimeInterval = 7.0
    
    // MARK: - Дизайн-система
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
