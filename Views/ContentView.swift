import SwiftUI

struct ContentView: View {
    @EnvironmentObject var manager: MeshNetworkManager
    
    var body: some View {
        if !manager.hasAccess {
            AuthView()
        } else {
            TabView {
                NavigationView {
                    VStack(spacing: 0) {
                        // Анонимный радар сверху
                        RadarView(activeNodesCount: manager.nearbyNodes.count)
                            .padding()
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        // Только твои закрытые ЛС-контакты
                        List(manager.contacts) { contact in
                            NavigationLink(destination: ChatView(contact: contact)) {
                                ContactRow(contact: contact)
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                    .navigationTitle("Защищенные ЛС")
                    .background(AppConstants.UI.mainBackground.ignoresSafeArea())
                }
                .tabItem { Label("Связь", systemImage: "lock.shield.fill") }
                
                NavigationView {
                    SettingsView()
                }
                .tabItem { Label("Узел", systemImage: "cpu") }
            }
            .accentColor(.cyan)
        }
    }
}
