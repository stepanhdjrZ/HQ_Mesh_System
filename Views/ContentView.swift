import SwiftUI

struct ContentView: View {
    @StateObject var meshManager = MeshNetworkManager()
    @State private var showingScanner = false
    @State private var scannedID: String? = nil
    
    var body: some View {
        TabView {
            // ВКЛАДКА 1: КОНТАКТЫ
            NavigationView {
                List {
                    // Кнопка добавления, как в ТГ
                    Button(action: { showingScanner = true }) {
                        HStack(spacing: 15) {
                            Image(systemName: "person.crop.circle.badge.plus").font(.title2)
                            Text("Добавить узел (QR-код)")
                        }
                    }
                    .foregroundColor(.blue)
                    
                    // Список твоих сохраненных узлов
                    Section(header: Text("Сохраненные контакты")) {
                        ForEach(meshManager.contacts) { contact in
                            NavigationLink(destination: ChatView(contactID: contact.hqId).environmentObject(meshManager)) {
                                HStack(spacing: 15) {
                                    Circle()
                                        .fill(LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 45, height: 45)
                                        .overlay(Text(String(contact.hqId.prefix(1))).foregroundColor(.white).bold())
                                    
                                    VStack(alignment: .leading) {
                                        Text(contact.hqId).font(.headline)
                                        Text("Ryzen Node 1 Online").font(.subheadline).foregroundColor(.gray)
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
                            if result.contains("HQ-") {
                                scannedID = result
                                showingScanner = false
                            }
                        }
                    }
                }
                .background(
                    NavigationLink(destination: ChatView(contactID: scannedID ?? "").environmentObject(meshManager), isActive: Binding(get: { scannedID != nil }, set: { if !$0 { scannedID = nil } })) { EmptyView() }
                )
            }
            .tabItem { Label("Контакты", systemImage: "person.2.fill") }
            
            // ВКЛАДКА 2: ЧАТЫ (Основной экран, как в ТГ)
            NavigationView {
                List {
                    ForEach(meshManager.contacts) { contact in
                        NavigationLink(destination: ChatView(contactID: contact.hqId).environmentObject(meshManager)) {
                            HStack(spacing: 15) {
                                Circle().fill(Color.orange.opacity(0.1)).frame(width: 55, height: 55)
                                    .overlay(Image(systemName: "cpu.fill").foregroundColor(.orange))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(contact.hqId).font(.headline)
                                        Spacer()
                                        Text("Только что").font(.caption).foregroundColor(.gray)
                                    }
                                    
                                    HStack {
                                        Text("Нажмите, чтобы открыть защищенный чат...")
                                            .font(.subheadline).foregroundColor(.gray).lineLimit(1)
                                        Spacer()
                                        // Unread бабл!
                                        Text("2").font(.caption2).bold().foregroundColor(.white)
                                            .padding(6).background(Color.blue).clipShape(Circle())
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .navigationTitle("Чаты")
            }
            .tabItem { Label("Чаты", systemImage: "message.fill") }
            
            // ВКЛАДКА 3: НАСТРОЙКИ (Тут твой QR и ID)
            NavigationView {
                VStack(spacing: 30) {
                    Text("Твой HQ ID: \(meshManager.myHQID)")
                        .font(.title2).bold()
                    
                    Image(uiImage: generateQRCode(from: meshManager.myHQID))
                        .interpolation(.none).resizable().scaledToFit().frame(width: 200, height: 200)
                        .cornerRadius(15).shadow(radius: 10)
                    
                    Text("Дай отсканировать этот код другу.")
                        .foregroundColor(.gray)
                }
                .navigationTitle("Мой Узел")
            }
            .tabItem { Label("Настройки", systemImage: "qrcode") }
        }
    }
}
