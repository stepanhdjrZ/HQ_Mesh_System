import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var meshManager = MeshNetworkManager()
    
    // Принудительно делаем всё приложение темным и премиальным
    init() {
        UITabBar.appearance().backgroundColor = UIColor(red: 0.02, green: 0.02, blue: 0.05, alpha: 0.9)
        UITabBar.appearance().unselectedItemTintColor = UIColor.systemGray
    }
    
    var body: some View {
        Group {
            if !meshManager.hasAccess {
                AuthView().environmentObject(meshManager)
            } else {
                MainTabView().environmentObject(meshManager)
            }
        }
        .preferredColorScheme(.dark) // Фиксируем темную тему Империи
    }
}

struct MainTabView: View {
    @EnvironmentObject var meshManager: MeshNetworkManager
    
    var body: some View {
        TabView {
            NavigationStack {
                ChatListView().environmentObject(meshManager)
            }
            .tabItem { Label("Связь", systemImage: "bolt.horizontal.circle.fill") }
            
            NavigationStack {
                SettingsView().environmentObject(meshManager)
            }
            .tabItem { Label("Штаб", systemImage: "cpu") }
        }
        .tint(.cyan)
    }
}

struct ChatListView: View {
    @EnvironmentObject var meshManager: MeshNetworkManager
    
    var body: some View {
        ZStack {
            // Фон списков
            LinearGradient(colors: [Color(red: 0.02, green: 0.05, blue: 0.1), .black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            if meshManager.contacts.isEmpty && meshManager.nearbyNodes.isEmpty {
                EmptyNetworkState(hqID: meshManager.myHQID)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(meshManager.contacts) { contact in
                            NavigationLink(destination: ChatView(contactID: contact.hqId).environmentObject(meshManager)) {
                                ContactRowGlass(contact: contact)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
            }
        }
        .navigationTitle("HQ Global")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Премиальная карточка контакта
struct ContactRowGlass: View {
    let contact: Contact
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 56, height: 56)
                    .shadow(color: .cyan.opacity(0.4), radius: 8)
                
                Text(String(contact.name.prefix(1).capitalized))
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(contact.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("ID: \(contact.hqId)")
                    .font(.caption)
                    .foregroundColor(.cyan.opacity(0.8))
                    .fontDesign(.monospaced)
            }
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray.opacity(0.5))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.05))
                .background(Material.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct EmptyNetworkState: View {
    let hqID: String
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle().fill(Color.blue.opacity(0.1)).frame(width: 120, height: 120)
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 50))
                    .foregroundColor(.cyan)
                    .shadow(color: .cyan.opacity(0.5), radius: 10)
            }
            
            Text("Сектор пуст")
                .font(.title.bold())
                .foregroundColor(.white)
            
            Text("Рядом нет активных узлов.\nРазверните сеть для локальной связи.")
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding(.horizontal, 32)
            
            ShareLink(item: "Присоединяйся к HQ Global. Мой Mesh ID: \(hqID)") {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Координаты для инвайта")
                }
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.cyan)
                .cornerRadius(18)
                .shadow(color: .cyan.opacity(0.4), radius: 10, y: 5)
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
        }
    }
}
