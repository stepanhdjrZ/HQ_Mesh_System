import SwiftUI
import CoreImage.CIFilterBuiltins

struct SettingsView: View {
    @EnvironmentObject var meshManager: MeshNetworkManager
    @State private var showQR = false

    var body: some View {
        NavigationView {
            List {
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
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Основатель HQ")
                                .font(.title2).bold()
                            Text("ID: \(meshManager.myHQID)")
                                .font(.subheadline).foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Сеть")) {
                    HStack {
                        Label("Статус Ryzen", systemImage: "cpu")
                        Spacer()
                        Circle()
                            .fill(meshManager.connectionState == .connected ? Color.green : .orange)
                            .frame(width: 8, height: 8)
                        Text(meshManager.connectionState == .connected ? "В сети" : "Подключение")
                            .foregroundColor(.gray)
                    }
                    Button(action: { showQR = true }) {
                        Label("Мой QR-код", systemImage: "qrcode")
                    }
                }
                
                Section(header: Text("Приложение")) {
                    Label("Уведомления", systemImage: "bell.fill").foregroundColor(.red)
                    Label("Оформление", systemImage: "paintbrush.fill").foregroundColor(.blue)
                }
            }
            .navigationTitle("Настройки")
            .sheet(isPresented: $showQR) {
                VStack(spacing: 30) {
                    Text("Твой код").font(.title2).bold().padding(.top, 40)
                    Image(uiImage: generateQRCode(from: meshManager.myHQID))
                        .interpolation(.none).resizable().scaledToFit().frame(width: 250, height: 250)
                        .background(Color.white).cornerRadius(15).shadow(radius: 10)
                    Text(meshManager.myHQID).font(.system(.title3, design: .monospaced)).bold()
                    Spacer()
                    Button("Закрыть") { showQR = false }.buttonStyle(.borderedProminent).padding(.bottom, 40)
                }
            }
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
