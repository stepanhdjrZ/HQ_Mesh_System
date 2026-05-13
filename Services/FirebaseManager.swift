import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

/// Профессиональный менеджер облачной инфраструктуры
final class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    
    @Published var isInitialized = false
    
    private init() {
        // Приватный инициализатор для Singleton-паттерна (как в лучших домах)
    }
    
    func configure() {
        // Предотвращаем двойную инициализацию, которая крашит приложение
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("[FIREBASE] Инфраструктура развернута успешно.")
            DispatchQueue.main.async {
                self.isInitialized = true
            }
        }
    }
    
    // В будущем здесь будут методы для Cloud Messaging (Push-уведомления)
    func syncNodeAnalytics(nodeID: String, stats: [String: Any]) {
        // Telegram собирает тонны данных о качестве связи, и мы будем
        let db = Firestore.firestore()
        db.collection("nodes").document(nodeID).setData(stats, merge: true)
    }
}
