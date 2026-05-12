import SwiftUI

struct ContentView: View {
    @StateObject var meshManager = MeshNetworkManager()
    @State private var showingScanner = false
    @State private var scannedID: String? = nil
    
    var body: some View {
        TabView {
            // КОНТАКТЫ
            NavigationView {
                List {
                    Button(action: { showingScanner = true }) {
                        Label("Добавить по QR", systemImage: "qrcode.viewfinder").font(.headline)
                    }
                    Section(header: Text("Мои узлы")) {
                        ForEach(meshManager.contacts) { contact in
                            NavigationLink(destination: ChatView(contactID: contact.hqId).environmentObject(meshManager)) {
                                Text(contact.hqId).font(.headline)
                            }
                        }
                    }
                }
                .navigationTitle("Контакты")
                .sheet(isPresented: $showingScanner) {
                    VStack {
                        HStack { Spacer(); Button("Отмена") { showingScanner = false }.padding() }
                        QRScannerView { result in
                            if result.contains("HQ-") {
                                scannedID = result
                                showingScanner = false
                            }
                        }
                    }
                }
                .background(
                    NavigationLink(destination: ChatView(contactID: scannedID ?? "").environmentObject(meshManager), 
                                   isActive: Binding(get: { scannedID != nil }, set: { if !$0 { scannedID = nil } })) { EmptyView() }
                )
            }
            .tabItem { Label("Контакты", systemImage: "person.2.fill") }
            
            // ЧАТЫ
            NavigationView {
                List {
                    ForEach(meshManager.contacts) { contact in
                        NavigationLink(destination: ChatView(contactID: contact.hqId).environmentObject(meshManager)) {
                            HStack(spacing: 15) {
                                Circle().fill(Color.blue).frame(width: 50, height: 50)
                                    .overlay(Text(String(contact.hqId.prefix(1))).foregroundColor(.white))
                                VStack(alignment: .leading) {
                                    Text(contact.hqId).font(.headline)
                                    Text("Нажмите, чтобы открыть").font(.subheadline).foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Чаты")
            }
            .tabItem { Label("Чаты", systemImage: "message.fill") }
            
            // НАСТРОЙКИ
            SettingsView()
                .environmentObject(meshManager)
                .tabItem { Label("Настройки", systemImage: "gear") }
        }
    }
}
