import SwiftUI

struct ContentView: View {
    @StateObject var meshManager = MeshNetworkManager()
    
    var body: some View {
        NavigationStack {
            TabView {
                // ЭКРАН ЧАТОВ
                NavigationStack {
                    ZStack {
                        if meshManager.messages.isEmpty && meshManager.nearbyNodes == 0 {
                            // ТОТ САМЫЙ "EMPTY STATE"
                            VStack(spacing: 25) {
                                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                                    .font(.system(size: 70))
                                    .foregroundColor(.orange)
                                    .symbolEffect(.pulse)
                                
                                Text("Локальная сеть пуста")
                                    .font(.title2).bold()
                                
                                Text("Чтобы общаться без интернета в этой зоне, рядом должен быть хотя бы один узел HQ.")
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 40)
                                
                                Button(action: {
                                    shareApp() // Функция "Пригласить друга"
                                }) {
                                    Label("Развернуть сеть здесь", systemImage: "plus.square.dashed")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.blue)
                                        .cornerRadius(12)
                                }
                            }
                        } else {
                            // СПИСОК ЧАТОВ (если кто-то есть)
                            List(meshManager.contacts) { contact in
                                NavigationLink(destination: ChatView(contactID: contact.hqId).environmentObject(meshManager)) {
                                    HStack {
                                        Circle().fill(Color.blue).frame(width: 40, height: 40)
                                        VStack(alignment: .leading) {
                                            Text(contact.name).bold()
                                            Text("Node ID: \(contact.hqId)").font(.caption).foregroundColor(.gray)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .navigationTitle("HQ Mesh")
                }
                .tabItem { Label("Чаты", systemImage: "message.fill") }
                
                // НАСТРОЙКИ
                NavigationStack {
                    SettingsView().environmentObject(meshManager)
                }
                .tabItem { Label("Настройки", systemImage: "gear") }
            }
            .accentColor(.blue)
        }
    }
    
    // ФУНКЦИЯ "ПОДЕЛИТЬСЯ"
    func shareApp() {
        let text = "Присоединяйся к моей независимой сети HQ Global. Мой Node ID: \(meshManager.myHQID). Скачай приложение и включи Mesh!"
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(av, animated: true)
        }
    }
}
