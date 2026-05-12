import SwiftUI

struct ContentView: View {
    @StateObject var meshManager = MeshNetworkManager()
    @State private var showingScanner = false
    @State private var scannedID: String? = nil
    
    var body: some View {
        TabView {
            // --- ВКЛАДКА ЧАТЫ ---
            NavigationView {
                VStack(spacing: 0) {
                    List {
                        if meshManager.contacts.isEmpty {
                            VStack(spacing: 20) {
                                Image(systemName: "message.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray.opacity(0.3))
                                Text("У вас пока нет чатов")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                Text("Отсканируйте QR-код друга в разделе Контакты, чтобы начать.")
                                    .font(.subheadline)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal)
                            }
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .padding(.top, 100)
                        } else {
                            ForEach(meshManager.contacts) { contact in
                                NavigationLink(destination: ChatView(contactID: contact.hqId).environmentObject(meshManager)) {
                                    ChatListRow(contact: contact)
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
                .navigationTitle("")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) { Button("Изм.") {}.foregroundColor(.blue) }
                    ToolbarItem(placement: .navigationBarTrailing) { Image(systemName: "square.and.pencil").foregroundColor(.blue) }
                    
                    // Центральный статус
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 0) {
                            Text("Чаты").font(.system(size: 17, weight: .semibold))
                            Text(meshManager.connectionState == .connected ? "в сети" : "обновление...")
                                .font(.system(size: 12))
                                .foregroundColor(meshManager.connectionState == .connected ? .gray : .blue)
                        }
                    }
                }
            }
            .tabItem { Label("Чаты", systemImage: "message.fill") }
            
            // --- ВКЛАДКА КОНТАКТЫ ---
            NavigationView {
                List {
                    Button(action: { showingScanner = true }) {
                        HStack(spacing: 15) {
                            Image(systemName: "qrcode.viewfinder").font(.title2).foregroundColor(.blue)
                            Text("Добавить контакт по QR").font(.headline).foregroundColor(.blue)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Section(header: Text("МОИ УЗЛЫ")) {
                        ForEach(meshManager.contacts) { contact in
                            HStack {
                                Circle().fill(Color.gray.opacity(0.2)).frame(width: 35, height: 35)
                                    .overlay(Text(String(contact.hqId.prefix(1))).font(.caption).bold())
                                Text(contact.hqId).font(.system(size: 17))
                            }
                        }
                    }
                }
                .navigationTitle("Контакты")
                .sheet(isPresented: $showingScanner) {
                    QRScannerView { result in
                        if result.contains("HQ-") { scannedID = result; showingScanner = false }
                    }
                }
                .background(
                    NavigationLink(destination: ChatView(contactID: scannedID ?? "").environmentObject(meshManager), 
                                   isActive: Binding(get: { scannedID != nil }, set: { if !$0 { scannedID = nil } })) { EmptyView() }
                )
            }
            .tabItem { Label("Контакты", systemImage: "person.circle.fill") }
            
            // --- ВКЛАДКА НАСТРОЙКИ ---
            SettingsView().environmentObject(meshManager)
                .tabItem { Label("Настройки", systemImage: "gearshape.fill") }
        }
    }
}

// Отдельная строка чата в стиле ТГ
struct ChatListRow: View {
    let contact: Contact
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 55, height: 55)
                .overlay(Text(String(contact.hqId.prefix(1))).font(.title3).bold().foregroundColor(.white))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(contact.hqId).font(.system(size: 17, weight: .semibold))
                    Spacer()
                    Text("19:45").font(.system(size: 14)).foregroundColor(.gray)
                }
                Text("Зашифрованный туннель активен...").font(.system(size: 15)).foregroundColor(.gray).lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}
