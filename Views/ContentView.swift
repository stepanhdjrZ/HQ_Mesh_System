import SwiftUI

struct ContentView: View {
    @StateObject var meshManager = MeshNetworkManager()
    @State private var showingScanner = false
    @State private var scannedID: String? = nil
    
    var body: some View {
        TabView {
            // --- ВКЛАДКА 1: КОНТАКТЫ ---
            NavigationView {
                List {
                    Button(action: { showingScanner = true }) {
                        HStack(spacing: 15) {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 22))
                                .foregroundColor(.blue)
                            Text("Добавить контакт (QR)")
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Section(header: Text("Сохраненные контакты")) {
                        if meshManager.contacts.isEmpty {
                            Text("Пока никого нет.").foregroundColor(.gray)
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
                .sheet(isPresented: $showingScanner) { ... QRScannerView ... } // Упрощенно для экономии строк, сканер работает
                .sheet(isPresented: $showingScanner) {
                    VStack {
                        HStack { Spacer(); Button("Отмена") { showingScanner = false }.padding() }
                        QRScannerView { result in
                            if result.contains("HQ-") { scannedID = result; showingScanner = false }
                        }
                    }
                }
                .background(
                    NavigationLink(destination: ChatView(contactID: scannedID ?? "").environmentObject(meshManager), isActive: Binding(get: { scannedID != nil }, set: { if !$0 { scannedID = nil } })) { EmptyView() }
                )
            }
            .tabItem { Label("Контакты", systemImage: "person.2.fill") }
            
            // --- ВКЛАДКА 2: ЧАТЫ ---
            NavigationView {
                List {
                    if meshManager.contacts.isEmpty {
                        Text("Нет активных чатов").foregroundColor(.gray)
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
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Text("HQ MESH").font(.headline).foregroundColor(.gray).opacity(0.5)
                    }
                }
            }
            .tabItem { Label("Чаты", systemImage: "message.fill") }
            
            // --- ВКЛАДКА 3: НАСТРОЙКИ ---
            SettingsView()
                .environmentObject(meshManager)
                .tabItem { Label("Настройки", systemImage: "gear") }
        }
    }
}
