import SwiftUI

struct ContentView: View {
    @StateObject var meshManager = MeshNetworkManager()
    @State private var showingScanner = false
    @State private var scannedID: String? = nil
    
    var body: some View {
        TabView {
            // --- ЧАТЫ ---
            NavigationView {
                ZStack {
                    Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all)
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            if meshManager.contacts.isEmpty {
                                EmptyStateView()
                            } else {
                                ForEach(meshManager.contacts) { contact in
                                    NavigationLink(destination: ChatView(contactID: contact.hqId).environmentObject(meshManager)) {
                                        ChatRow(contact: contact)
                                    }
                                    Divider().padding(.leading, 80)
                                }
                            }
                        }
                        .background(Color(UIColor.systemBackground))
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        VStack {
                            Text("Чаты").font(.headline)
                            Text(meshManager.connectionState == .connected ? "в сети" : "обновление...")
                                .font(.caption2)
                                .foregroundColor(meshManager.connectionState == .connected ? .blue : .gray)
                        }
                    }
                    ToolbarItem(placement: .navigationBarLeading) { Button("Изм.") {}.foregroundColor(.blue) }
                    ToolbarItem(placement: .navigationBarTrailing) { Image(systemName: "square.and.pencil").foregroundColor(.blue) }
                }
            }
            .tabItem { Label("Чаты", systemImage: "message.fill") }
            
            // --- КОНТАКТЫ ---
            NavigationView {
                List {
                    Button(action: { showingScanner = true }) {
                        HStack(spacing: 15) {
                            Image(systemName: "qrcode.viewfinder").font(.title2)
                            Text("Добавить узел по QR").font(.headline)
                        }
                    }.foregroundColor(.blue)
                    
                    Section(header: Text("МОИ КОНТАКТЫ")) {
                        ForEach(meshManager.contacts) { contact in
                            HStack {
                                ContactAvatar(id: contact.hqId, size: 35)
                                Text(contact.hqId)
                            }
                        }
                    }
                }
                .navigationTitle("Контакты")
            }
            .tabItem { Label("Контакты", systemImage: "person.circle.fill") }
            
            // --- НАСТРОЙКИ ---
            SettingsView().environmentObject(meshManager)
                .tabItem { Label("Настройки", systemImage: "gearshape.fill") }
        }
        .onAppear {
            // Делаем таб-бар полупрозрачным как в ТГ
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

// Красивая строка чата
struct ChatRow: View {
    let contact: Contact
    var body: some View {
        HStack(spacing: 15) {
            ContactAvatar(id: contact.hqId, size: 60)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(contact.hqId).font(.system(size: 17, weight: .semibold)).foregroundColor(.primary)
                    Spacer()
                    Text("17:42").font(.system(size: 14)).foregroundColor(.gray)
                }
                Text("Зашифрованный пакет доставлен...").font(.system(size: 15)).foregroundColor(.gray).lineLimit(1)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
    }
}

struct ContactAvatar: View {
    let id: String
    let size: CGFloat
    var body: some View {
        Circle()
            .fill(LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
            .overlay(Text(String(id.prefix(1))).foregroundColor(.white).font(.system(size: size/2, weight: .bold)))
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bolt.shield.fill").font(.system(size: 80)).foregroundColor(.blue.opacity(0.2))
            Text("HQ Mesh Global").font(.title2).bold()
            Text("Ваша сеть пуста. Добавьте первый узел через QR-код друга.").multilineTextAlignment(.center).foregroundColor(.gray).padding(.horizontal, 50)
        }
        .padding(.top, 100)
    }
}
