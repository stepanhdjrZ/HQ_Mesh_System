import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var meshManager = MeshNetworkManager()
    
    init() {
        UITabBar.appearance().backgroundColor = UIColor(red: 0.01, green: 0.01, blue: 0.03, alpha: 1.0)
        UITabBar.appearance().unselectedItemTintColor = UIColor.gray
    }
    
    var body: some View {
        Group {
            if !meshManager.hasAccess {
                AuthView().environmentObject(meshManager)
            } else {
                MainTabView().environmentObject(meshManager)
            }
        }.preferredColorScheme(.dark)
    }
}

struct MainTabView: View {
    @EnvironmentObject var meshManager: MeshNetworkManager
    var body: some View {
        TabView {
            NavigationView {
                ChatListManager().environmentObject(meshManager)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem { Label("Сеть", systemImage: "bolt.horizontal.circle.fill") }
            
            NavigationView {
                SettingsView().environmentObject(meshManager)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem { Label("Штаб", systemImage: "cpu") }
        }.accentColor(.cyan)
    }
}

struct ChatListManager: View {
    @EnvironmentObject var meshManager: MeshNetworkManager
    var body: some View {
        ZStack {
            Color(red: 0.01, green: 0.02, blue: 0.06).ignoresSafeArea()
            
            if meshManager.contacts.isEmpty && meshManager.nearbyNodes.isEmpty {
                RadarEmptyState(hqID: meshManager.myHQID)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(meshManager.contacts) { contact in
                            NavigationLink(destination: ChatView(contactID: contact.hqId).environmentObject(meshManager)) {
                                ContactCard(contact: contact)
                            }.buttonStyle(PlainButtonStyle())
                        }
                    }.padding(.horizontal, 16).padding(.top, 16)
                }
            }
        }
        .navigationTitle("HQ Global")
    }
}

struct ContactCard: View {
    let contact: Contact
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 60, height: 60)
                Text(String(contact.name.prefix(1).capitalized)).font(.system(size: 24, weight: .heavy)).foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(contact.name).font(.headline).foregroundColor(.white)
                Text("ID: \(contact.hqId)").font(.system(size: 12, design: .monospaced)).foregroundColor(.gray)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray)
        }
        .padding(16).background(Color.white.opacity(0.05)).cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

struct RadarEmptyState: View {
    let hqID: String
    var body: some View {
        VStack(spacing: 30) {
            ZStack {
                Circle().fill(LinearGradient(colors: [.blue, .cyan], startPoint: .top, endPoint: .bottom)).frame(width: 80, height: 80)
                Image(systemName: "antenna.radiowaves.left.and.right").font(.system(size: 30, weight: .bold)).foregroundColor(.white)
            }
            VStack(spacing: 8) {
                Text("Сектор чист").font(.system(size: 28, weight: .heavy)).foregroundColor(.white)
                Text("Разверните сеть для локальной связи.").foregroundColor(.gray)
            }
            Button(action: {
                let text = "Присоединяйся к HQ Global. Мой ID: \(hqID)"
                let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let root = scene.windows.first?.rootViewController { root.present(av, animated: true) }
            }) {
                HStack { Image(systemName: "square.and.arrow.up"); Text("Пригласить узел") }
                .font(.system(size: 16, weight: .bold)).foregroundColor(.black).frame(maxWidth: .infinity).padding().background(Color.cyan).cornerRadius(20)
            }.padding(.horizontal, 40).padding(.top, 20)
        }
    }
}
