import SwiftUI

@main
struct HQApp: App {
    @StateObject private var regManager = RegistrationManager()
    @StateObject private var meshManager = MeshNetworkManager()
    
    var body: some Scene {
        WindowGroup {
            Group {
                // Если статус auth - показываем новый экран с логином/паролем
                if regManager.appState == .auth {
                    AuthView()
                        .environmentObject(regManager)
                } else {
                    // Иначе пускаем в саму Империю
                    MainAppContainer()
                        .environmentObject(meshManager)
                        .environmentObject(regManager)
                }
            }
        }
    }
}
