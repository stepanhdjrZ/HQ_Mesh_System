import SwiftUI

struct ContentView: View {
    @StateObject var meshManager = MeshNetworkManager()
    
    var body: some View {
        // NavigationStack + TabView без рамок
        NavigationStack {
            TabView {
                NavigationStack {
                    List {
                        Section("Активные диалоги") {
                            Text("У вас пока нет чатов").foregroundColor(.gray)
                        }
                    }
                    .navigationTitle("HQ Mesh")
                }
                .tabItem { Label("Чаты", systemImage: "message.fill") }
                
                NavigationStack {
                    SettingsView()
                        .environmentObject(meshManager)
                }
                .tabItem { Label("Настройки", systemImage: "gear") }
            }
            .accentColor(.blue)
        }
        .ignoresSafeArea() // Растягиваем на 100% экрана
    }
}
