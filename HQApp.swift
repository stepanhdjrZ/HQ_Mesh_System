import SwiftUI

@main
struct HQApp: App {
    @StateObject private var regManager = RegistrationManager()
    @StateObject private var meshManager = MeshNetworkManager()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if regManager.appState == .auth {
                    AuthView()
                        .environmentObject(regManager)
                } else {
                    MainAppContainer()
                        .environmentObject(meshManager)
                        .environmentObject(regManager)
                }
            }
        }
    }
}
