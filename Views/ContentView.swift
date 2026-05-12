import SwiftUI
import CoreImage.CIFilterBuiltins

struct ContentView: View {
    @StateObject var meshManager = MeshNetworkManager()
    @State private var showingScanner = false
    @State private var scannedID: String? = nil
    
    var body: some View {
        TabView {
            // --- ВКЛАДКА 1: ЧАТЫ ---
            NavigationView {
                List {
                    // Кнопка запуска сканера (выглядит как в премиум-приложениях)
                    Button(action: { showingScanner = true }) {
                        HStack(spacing: 15) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 24))
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("Сканировать QR-код").font(.headline).foregroundColor(.primary)
                                Text("Добавить узел в сеть").font(.subheadline).foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Список сохраненных контактов
                    Section(header: Text("Сохраненные контакты")) {
                        if meshManager.contacts.isEmpty {
                            Text("Список пуст. Отсканируйте QR друга.")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding()
                        } else {
                            ForEach(meshManager.contacts) { contact in
                                NavigationLink(destination: ChatView(contactID: contact.hqId).environmentObject(meshManager)) {
                                    HStack {
                                        Circle()
                                            .fill(LinearGradient(gradient: Gradient(colors: [.blue, .cyan]), startPoint: .top, endPoint: .bottom))
                                            .frame(width: 40, height: 40)
                                            .overlay(Text(String(contact.hqId.prefix(1))).foregroundColor(.white))
                                        
                                        VStack(alignment: .leading) {
                                            Text(contact.hqId).font(.headline)
                                            Text("Online").font(.caption).foregroundColor(.green)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Чаты")
                .toolbar {
                    // ИСПРАВЛЕННЫЙ ТУЛБАР (статус сети)
                    ToolbarItem(placement: .navigationBarLeading) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 8, height: 8)
                            Text(statusText)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                // Окно сканера
                .sheet(isPresented: $showingScanner) {
                    VStack {
                        HStack {
                            Spacer()
                            Button("Отмена") { showingScanner = false }.padding()
                        }
                        QRScannerView { result in
                            if result.contains("HQ-") {
                                scannedID = result
                                showingScanner = false
                            }
                        }
                    }
                }
                // Скрытая навигация для автоматического открытия чата после скана
                .background(
                    NavigationLink(
                        destination: ChatView(contactID: scannedID ?? "").environmentObject(meshManager),
                        isActive: Binding(
                            get: { scannedID != nil },
                            set: { if !$0 { scannedID = nil } }
                        )
                    ) { EmptyView() }
                )
            }
            .tabItem {
                Label("Чаты", systemImage: "message.fill")
            }
            
            // --- ВКЛАДКА 2: ПРОФИЛЬ ---
            NavigationView {
                VStack(spacing: 30) {
                    Spacer()
                    
                    VStack(spacing: 10) {
                        Text("Твой персональный HQ ID")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text(meshManager.myHQID)
                            .font(.system(size: 32, weight: .black, design: .monospaced))
                    }
                    
                    // Генерация QR
                    Image(uiImage: generateQRCode(from: meshManager.myHQID))
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(24)
                        .shadow(color: Color.black.opacity(0.1), radius: 20)
                    
                    Text("Дай другу отсканировать этот код, чтобы он мог отправить тебе сообщение через твой Ryzen-узел.")
                        .multilineTextAlignment(.center)
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 40)
                    
                    Spacer()
                }
                .navigationTitle("Мой Профиль")
            }
            .tabItem {
                Label("Профиль", systemImage: "person.crop.circle.fill")
            }
        }
    }
    
    // --- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ---
    
    var statusColor: Color {
        switch meshManager.connectionState {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected: return .red
        }
    }
    
    var statusText: String {
        switch meshManager.connectionState {
        case .connected: return "В сети"
        case .connecting: return "Соединение..."
        case .disconnected: return "Ожидание..."
        }
    }

    func generateQRCode(from string: String) -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(Data(string.utf8), forKey: "inputMessage")
        if let outputImage = filter.outputImage,
           let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return UIImage(systemName: "xmark.circle") ?? UIImage()
    }
}
