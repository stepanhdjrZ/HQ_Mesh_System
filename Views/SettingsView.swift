import SwiftUI
import CoreImage.CIFilterBuiltins

struct SettingsView: View {
    @EnvironmentObject var meshManager: MeshNetworkManager
    @State private var showQR = false
    @State private var showDeleteAlert = false

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            
            VStack(spacing: 20) {
                // PREMIUM PROFILE HEADER
                VStack {
                    Circle()
                        .fill(LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 90, height: 90)
                        .overlay(Text(String(meshManager.myHQID.prefix(1))).font(.system(size: 40, weight: .bold)).foregroundColor(.white))
                        .shadow(color: .black.opacity(0.1), radius: 10)
                    
                    Text("Основатель HQ").font(.title2).bold()
                    Text("ID: \(meshManager.myHQID)").font(.subheadline).foregroundColor(.gray)
                }
                .padding(.top, 40)
                
                // cards
                VStack(spacing: 0) {
                    StatusCardRow(title: "Центральный Ryzen", status: meshManager.connectionState == .connected ? "В сети" : "Поиск Штаба", color: meshManager.connectionState == .connected ? .green : .orange)
                    Divider().padding(.leading, 60)
                    StatusCardRow(title: "Локальный Mesh", status: meshManager.nearbyNodes.isEmpty ? "Один узел" : "\(meshManager.nearbyNodes.count) узлов рядом", color: .blue)
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(18)
                .padding(.horizontal)
                
                // Button QR
                Button(action: { showQR = true }) {
                    HStack {
                        Image(systemName: "qrcode").font(.title3)
                        Text("Мой Mesh QR-код").bold()
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray)
                    }
                    .padding().background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(12)
                }.padding(.horizontal).padding(.top, 10)
                
                // DELETE ACCOUNT (Apple Requirement)
                Button(role: .destructive, action: { showDeleteAlert = true }) {
                    Text("Удалить аккаунт и данные").bold()
                }
                .padding(.top, 30)
                .alert("Удаление Империи", isPresented: $showDeleteAlert) {
                    Button("Отмена", role: .cancel) { }
                    Button("Удалить всё", role: .destructive) { meshManager.deleteAccountRequest() }
                } message: { Text("Это действие безвозвратно удалит ваш ID и данные из сети HQ.") }
                
                Spacer()
            }
        }
        .navigationTitle("Настройки")
        .sheet(isPresented: $showQR) { QRView(hqID: meshManager.myHQID) }
    }
}

struct StatusCardRow: View {
    let title: String; let status: String; let color: Color
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .foregroundColor(.white).padding(10).background(color).cornerRadius(10)
            
            Text(title).font(.body)
            Spacer()
            Text(status).font(.subheadline).foregroundColor(.gray)
        }
        .padding()
    }
}

struct QRView: View {
    let hqID: String
    var body: some View {
        VStack(spacing: 25) {
            Text("Твой Mesh-код").font(.title3).bold().padding(.top, 40)
            Image(uiImage: generateQRCode(from: hqID))
                .interpolation(.none).resizable().scaledToFit().frame(width: 250, height: 250).cornerRadius(15)
                .background(Color.white).cornerRadius(15).shadow(radius: 10)
            Text(hqID).font(.monospaced(.title3)()).bold()
            Spacer()
        }
    }
    func generateQRCode(from string: String) -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(Data(string.utf8), forKey: "inputMessage")
        if let outputImage = filter.outputImage, let cgImage = context.createCGImage(outputImage, from: outputImage.extent) { return UIImage(cgImage: cgImage) }
        return UIImage()
    }
}
