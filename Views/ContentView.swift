import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var meshManager = MeshNetworkManager()
    
    var body: some View {
        Group {
            if !meshManager.hasAccess {
                AuthView().environmentObject(meshManager)
            } else {
                MainTabView().environmentObject(meshManager)
            }
        }
    }
}

// Разделили UI для чистоты архитектуры
struct MainTabView: View {
    @EnvironmentObject var meshManager: MeshNetworkManager
    
    var body: some View {
        TabView {
            NavigationStack {
                ChatListView().environmentObject(meshManager)
            }
            .tabItem { Label("Чаты", systemImage: "message.fill") }
            
            NavigationStack {
                SettingsView().environmentObject(meshManager)
            }
            .tabItem { Label("Профиль", systemImage: "person.crop.circle.fill") }
        }
        .tint(.blue)
    }
}

struct ChatListView: View {
    @EnvironmentObject var meshManager: MeshNetworkManager
    
    var body: some View {
        ZStack {
            if meshManager.contacts.isEmpty && meshManager.nearbyNodes.isEmpty {
                EmptyNetworkState(meshManager: meshManager)
            } else {
                List(meshManager.contacts) { contact in
                    NavigationLink(destination: ChatView(contactID: contact.hqId).environmentObject(meshManager)) {
                        ContactRow(contact: contact)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("HQ Global")
    }
}

struct ContactRow: View {
    let contact: Contact
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 52, height: 52)
                .overlay(Text(String(contact.name.prefix(1).capitalized)).font(.title2.bold()).foregroundColor(.white))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.name).font(.headline)
                Text("Node ID: \(contact.hqId)").font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

struct EmptyNetworkState: View {
    @ObservedObject var meshManager: MeshNetworkManager
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 72))
                .foregroundColor(.orange)
            
            Text("Сеть Империи пуста")
                .font(.title2.bold())
            
            Text("Пригласите друзей или найдите узел рядом, чтобы активировать Mesh-канал.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
            
            Button(action: shareApp) {
                Label("Пригласить в сеть", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 40)
            .padding(.top, 16)
        }
    }
    
    private func shareApp() {
        let text = "Присоединяйся к HQ Global. Мой Mesh ID: \(meshManager.myHQID)."
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(av, animated: true)
        }
    }
}
