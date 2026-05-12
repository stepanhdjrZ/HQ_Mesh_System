import SwiftUI
import CoreImage.CIFilterBuiltins

struct SettingsView: View {
    @EnvironmentObject var meshManager: MeshNetworkManager
    @State private var showQR = false

    var body: some View {
        NavigationView {
            List {
                // ШАПКА ПРОФИЛЯ
                Section {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text(String(meshManager.myHQID.prefix(1)))
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Основатель HQ")
                                .font(.title2)
                                .bold()
                            Text("ID: \(meshManager.myHQID)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // СЕТЬ И ПОДКЛЮЧЕНИЕ
                Section(header: Text("Сеть и Ryzen Сервер").font(.caption)) {
                    HStack {
                        Label("Статус сервера", systemImage: "network")
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(meshManager.connectionState == .connected ? Color.green : .orange)
                                .frame(width: 8, height: 8)
                            Text(meshManager.connectionState == .connected ? "Подключено" : "Ожидание")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Button(action: { showQR = true }) {
                        HStack {
                            Label("Мой QR-код для друзей", systemImage: "qrcode")
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.gray).font(.caption)
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                // НАСТРОЙКИ ПРИЛОЖЕНИЯ (Заглушки для будущего)
                Section(header: Text("Настройки").font(.caption)) {
                    NavigationLink(destination: Text("Уведомления и звуки")) {
                        Label("Уведомления и звуки", systemImage: "bell.badge.fill")
                            .foregroundColor(.red)
                    }
                    NavigationLink(destination: Text("Данные и память")) {
                        Label("Данные и память", systemImage: "chart.pie.fill")
                            .foregroundColor(.green)
                    }
                    NavigationLink(destination: Text("Оформление")) {
                        Label("Оформление", systemImage: "paintbrush.fill")
                            .foregroundColor(.blue)
                    }
                }
                
                Section {
                    Button(action: {}) {
                        Text("Очистить кэш сообщений")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle()) // Стиль списков Apple/Telegram
            .navigationTitle("Настройки")
            .sheet(isPresented: $showQR) {
                // Всплывающее окно с QR
                VStack(spacing: 30) {
                    Text("Отсканируй для связи")
                        .font(.title2).bold()
                        .padding(.top, 40)
                    
                    Image(uiImage: generateQRCode(from: meshManager.myHQID))
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                        .cornerRadius(15)
                        .shadow(radius: 10)
                    
                    Text(meshManager.myHQID)
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Button(action: { showQR = false }) {
                        Text("Готово")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 200, height: 50)
                            .background(Color.blue)
                            .cornerRadius(25)
                    }
                    .padding(.bottom, 40)
                }
                .background(Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all))
            }
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
