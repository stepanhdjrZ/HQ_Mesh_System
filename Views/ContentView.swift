import SwiftUI
import UIKit // КРИТИЧНО ДЛЯ МЕНЮ ШЕРИНГА

struct ContentView: View {
    @StateObject var meshManager = MeshNetworkManager()
    
    var body: some View {
        if !meshManager.hasAccess {
            AuthView().environmentObject(meshManager)
        } else {
            TabView {
                NavigationStack {
                    ZStack {
                        if meshManager.contacts.isEmpty && meshManager.nearbyNodes.isEmpty {
                            VStack(spacing: 25) {
                                Image(systemName: "antenna.radiowaves.left.and.right.slash").font(.system(size: 70)).foregroundColor(.orange)
                                Text("Сеть HQ Global пуста").font(.title2).bold()
                                Text("Станьте первым узлом: пригласите друга, чтобы общаться без интернета.")
                                    .multilineTextAlignment(.center).foregroundColor(.gray).padding(.horizontal, 40)
                                Button(action: shareApp) {
                                    Label("Развернуть сеть", systemImage: "plus.square.dashed").font(.headline).foregroundColor(.white).padding().background(Color.blue).cornerRadius(12)
                                }
                            }
                        } else {
                            List(meshManager.contacts) { contact in
                                NavigationLink(destination: ChatView(contactID: contact.hqId).environmentObject(meshManager)) {
                                    HStack(spacing: 15) {
                                        Circle().fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 50, height: 50)
                                            .overlay(Text(String(contact.name.prefix(1))).foregroundColor(.white).bold())
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(contact.name).font(.headline)
                                            Text("ID: \(contact.hqId)").font(.caption).foregroundColor(.gray)
                                        }
                                    }.padding(.vertical, 4)
                                }
                            }.listStyle(PlainListStyle())
                        }
                    }.navigationTitle("HQ Mesh")
                }.tabItem { Label("Чаты", systemImage: "message.fill") }
                
                NavigationStack {
                    SettingsView().environmentObject(meshManager)
                }.tabItem { Label("Профиль", systemImage: "person.crop.circle") }
            }.accentColor(.blue)
        }
    }
    
    func shareApp() {
        let text = "Присоединяйся к моей независимой сети HQ Global. Мой ID: \(meshManager.myHQID). Скачай приложение и включи Mesh!"
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(av, animated: true)
        }
    }
}
