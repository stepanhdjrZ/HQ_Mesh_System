import SwiftUI

@main
struct HQApp: App {
    // Подключаем наш менеджер сети из папки Services
    @StateObject var meshManager = MeshNetworkManager()
    
    var body: some Scene {
        WindowGroup {
            // Запускаем главный экран из папки Views
            ContentView()
                .environmentObject(meshManager)
        }
    }
}
