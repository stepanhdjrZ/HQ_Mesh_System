import SwiftUI
import CoreImage.CIFilterBuiltins

struct SettingsView: View {
    @EnvironmentObject var meshManager: MeshNetworkManager
    @State private var showQR = false
    @State private var showDeleteAlert = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    Circle()
                        .fill(LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 80, height: 80)
                        .overlay(Text(String(meshManager.myHQID.prefix(1))).font(.title.bold()).foregroundColor(.white))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Основатель HQ").font(.title2).bold()
                        Text("ID: \(meshManager.myHQID)").font(.subheadline).foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 8)
            }
            
            Section(header: Text("Сеть")) {
                HStack {
                    Label("Статус Штаба (Ryzen)", systemImage: "cpu")
                    Spacer()
                    Circle().fill(meshManager.connectionState == .connected ? Color.green : .orange).frame(width: 8, height: 8)
                    Text(meshManager.connectionState == .connected ? "В сети" : "Коннект...").foregroundColor(.gray)
                }
                Button(action: { showQR = true }) {
                    Label("Мой QR-код", systemImage: "qrcode")
                }
            }
            
            // СЕКЦИЯ ДЛЯ APP STORE
            Section(header: Text("Управление данными")) {
                Button(role: .destructive, action: { showDeleteAlert = true }) {
                    Label("Удалить аккаунт", systemImage: "trash.fill")
                }
                .alert("Удаление Империи", isPresented: $showDeleteAlert) {
                    Button("Отмена", role: .cancel) { }
                    Button("Удалить всё", role: .destructive) {
                        meshManager.deleteAccountRequest()
                    }
                } message: {
                    Text("Это действие безвозвратно удалит ваш HQ ID и все данные из Штаба. Подписка (50 руб) будет аннулирована.")
                }
            }
            
            Section(header: Text("Приложение")) {
                Label("Уведомления", systemImage: "bell.fill").foregroundColor(.red)
                Label("Оформление", systemImage: "paintbrush.fill").foregroundColor(.blue)
            }
        }
        .navigationTitle("Настройки")
        .sheet(isPresented: $showQR) { QRView(id: meshManager.myHQID) }
    }
}

struct QRView: View {
    let id: String
    var body: some View {
        VStack(spacing: 30) {
            Text("Твой код").font(.title2).bold().padding(.top, 40)
            Image(uiImage: generateQRCode(from: id)).interpolation(.none).resizable().frame(width: 250, height: 250).cornerRadius(15)
            Text(id).font(.monospaced(.title3)()).bold()
            Spacer()
        }
    }
    
    func generateQRCode(from string: String) -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(Data(string.utf8), forKey: "inputMessage")
        if let outputImage = filter.outputImage, let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return UIImage()
    }
}
