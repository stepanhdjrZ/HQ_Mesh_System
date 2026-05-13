import SwiftUI

@main
struct HQApp: App {
    // Инициализируем наши сервисы один раз на всю жизнь приложения
    @StateObject private var meshManager = MeshNetworkManager()
    @StateObject private var firebaseManager = FirebaseManager.shared
    
    init() {
        // Точка входа для настройки системных сервисов
        LoggerService.log("Инициализация HQ Global Protocol...", level: .security)
        firebaseManager.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(meshManager)
                .environmentObject(firebaseManager)
                .preferredColorScheme(.dark)
                .onAppear {
                    // Синхронизация аналитики при запуске
                    if meshManager.hasAccess {
                        firebaseManager.syncNodeAnalytics(
                            nodeID: meshManager.myHQID,
                            stats: ["last_online": Date(), "status": "active"]
                        )
                    }
                }
        }
    }
}
