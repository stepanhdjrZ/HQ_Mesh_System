import Foundation
import SwiftUI

public struct AppConstants {
    // MARK: - Сетевые параметры
    public static let serviceType = "hq-mesh-v10"
    
    // Твой живой туннель к серверу
    public static let serverDomain = "hq-mesh-server.loca.lt"
    
    public static let apiURL = "https://\(serverDomain)"
    public static let serverURL = "wss://\(serverDomain)/ws"
    
    public static let reconnectInterval: TimeInterval = 7.0
    
    // MARK: - Дизайн-система (Премиум)
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
