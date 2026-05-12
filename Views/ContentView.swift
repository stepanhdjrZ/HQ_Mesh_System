import SwiftUI

struct ContentView: View {
    @StateObject var meshManager = MeshNetworkManager()
    @State private var showingScanner = false
    @State private var scannedID: String? = nil
    
    var body: some View {
        TabView {
            // --- ВКЛАДКА 1: КОНТАКТЫ ---
            NavigationStack {
                List {
                    Button(action: { showingScanner = true }) {
                        HStack(spacing: 15) {
                            Image(systemName: "person.crop.circle.badge.plus").font(.title2)
                            Text("Добавить контакт (QR)")
                        }
                    }
                    .foregroundColor(.blue)
                    
                    Section(header: Text("Сохраненные контакты")) {
                        if meshManager.contacts.isEmpty {
                            Text("Список пуст.").foregroundColor(.gray)
                        } else {
                            ForEach(meshManager.contacts) { contact in
                                NavigationLink(destination: ChatView(contactID: contact.hqId).environmentObject(meshManager)) {
                                    HStack(spacing: 15) {
                                        Circle()
                                            .fill(LinearGradient(gradient: Gradient(colors: [.cyan, .blue]), startPoint: .top, endPoint: .bottom))
                                            .frame(width: 45, height: 45)
                                            .overlay(Text(String(contact.hqId.prefix(1))).foregroundColor(.white).bold())
                                        
                                        VStack(alignment: .leading) {
                                            Text(contact.hqId).font(.headline)
                                            Text("В сети").font(.caption).foregroundColor(.green)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .navigationTitle("Контакты")
                .sheet(isPresented: $showingScanner) {
                    VStack {
                        HStack { Spacer(); Button("Отмена") { showingScanner = false }.padding() }
                        QRScannerView { result in
                            if result.contains("HQ-") { scannedID = result; showingScanner = false }
                        }
                    }
                }
                .navigationDestination(isPresented: Binding(get: { scannedID != nil }, set: { if !$0 { scannedID = nil } })) {
                    if let targetID = scannedID {
                        ChatView(contactID: targetID).environmentObject(meshManager)
                    }
                }
            }
            .tabItem { Label("Контакты", systemImage: "person.2.fill") }
            
            // --- ВКЛАДКА 2: ЧАТЫ ---
            NavigationStack {
                List {
                    if meshManager.contacts.isEmpty {
                        Text("Нет активных чатов").foregroundColor(.gray).padding(.top, 20)
                    } else {
                        ForEach(meshManager.contacts) { contact in
                            NavigationLink(destination: ChatView(contactID: contact.hqId).environmentObject(meshManager)) {
                                HStack(spacing: 15) {
                                    Circle()
                                        .fill(LinearGradient(gradient: Gradient(colors: [.purple, .blue]), startPoint: .top, endPoint: .bottom))
                                        .frame(width: 55, height: 55)
                                        .overlay(Text(String(contact.hqId.prefix(1))).font(.title3).foregroundColor(.white).bold())
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(contact.hqId).font(.headline)
                                            Spacer()
                                            Text("Только что").font(.caption).foregroundColor(.gray)
                                        }
                                        Text("Нажмите, чтобы открыть чат...")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                            .lineLimit(1)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .navigationTitle("Чаты")
            }
            .tabItem { Label("Чаты", systemImage: "message.fill") }
            
            // --- ВКЛАДКА 3: НАСТРОЙКИ ---
            NavigationStack {
                SettingsView()
                    .environmentObject(meshManager)
            }
            .tabItem { Label("Настройки", systemImage: "gear") }
        }
    }
}
