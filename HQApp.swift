import SwiftUI

@main
struct HQApp: App {
    @StateObject var meshManager = MeshNetworkManager()
    
    // Проверяем, проходил ли юзер регистрацию
    @AppStorage("isRegistered") var isRegistered: Bool = false
    
    var body: some Scene {
        WindowGroup {
            if isRegistered {
                ContentView()
                    .environmentObject(meshManager)
            } else {
                AuthView(isRegistered: $isRegistered)
                    .environmentObject(meshManager)
            }
        }
    }
}
