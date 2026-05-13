import SwiftUI

struct ContentView: View {
    @EnvironmentObject var manager: MeshNetworkManager
    
    var body: some View {
        if !manager.hasAccess {
            AuthView()
        } else {
            TabView {
                NavigationView {
                    List(manager.contacts) { contact in
                        NavigationLink(destination: ChatView(contact: contact)) {
                            ContactRow(contact: contact)
                        }
                    }
                    .navigationTitle("HQ Global")
                }
                .tabItem { Label("Сеть", systemImage: "bolt.fill") }
                
                NavigationView {
                    SettingsView()
                }
                .tabItem { Label("Штаб", systemImage: "cpu") }
            }
            .accentColor(.cyan)
        }
    }
}
