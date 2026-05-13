import SwiftUI

@main
struct HQApp: App {
    // Создаем единственный источник истины для всего приложения
    @StateObject private var meshManager = MeshNetworkManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(meshManager) // Прокидываем менеджер во все вложенные файлы
                .preferredColorScheme(.dark)
        }
    }
}
