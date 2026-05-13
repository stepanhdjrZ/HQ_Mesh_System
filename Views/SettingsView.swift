import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

struct SettingsView: View {
    @EnvironmentObject var meshManager: MeshNetworkManager
    @State private var showQR = false
    @State private var showDeleteAlert = false
    
    var body: some View {
        ZStack {
            Color(red: 0.01, green: 0.02, blue: 0.06).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        ZStack {
                            Circle().fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 120, height: 120)
                            Text(avatarLetter).font(.system(size: 50, weight: .black)).foregroundColor(.white)
                        }
                        VStack(spacing: 4) {
                            Text(displayName).font(.system(size: 24, weight: .bold)).foregroundColor(.white)
                            Text("@\(displayUsername)").foregroundColor(.cyan).font(.system(size: 15, design: .monospaced))
                        }
                    }.padding(.top, 20)
                    
                    VStack(spacing: 0) {
                        HQDashboardRow(icon: "server.rack", title: "Состояние Штаба", value: meshManager.connectionState == .connected ? "ONLINE" : "ПОИСК", valueColor: meshManager.connectionState == .connected ? .green : .orange)
                        Divider().background(Color.white.opacity(0.1)).padding(.leading, 64)
                        HQDashboardRow(icon: "network", title: "Локальный Mesh", value: "\(meshManager.nearbyNodes.count) УЗЛОВ", valueColor: .cyan)
                        Divider().background(Color.white.opacity(0.1)).padding(.leading, 64)
                        HQDashboardRow(icon: "arrow.up.arrow.down", title: "Трафик", value: "\(meshManager.bytesSent) ↑ \(meshManager.bytesReceived) ↓", valueColor: .gray)
                    }.background(Color.white.opacity(0.05)).cornerRadius(24).padding(.horizontal, 20)
                    
                    // Хакерский Терминал
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ТЕРМИНАЛ ЯДРА").font(.system(size: 12, weight: .bold)).foregroundColor(.gray).padding(.horizontal, 30)
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(meshManager.systemLogs) { log in
                                        HStack(alignment: .top) {
                                            Text(">").foregroundColor(.gray)
                                            Text(log.message).foregroundColor(colorForLog(log.type))
                                            Spacer()
                                        }.font(.system(size: 12, design: .monospaced)).id(log.id)
                                    }
                                }.padding(16)
                            }
                            .frame(height: 150).background(Color.black).cornerRadius(20)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    Button(action: { showQR = true }) {
                        HStack {
                            Image(systemName: "qrcode.viewfinder").font(.title3).foregroundColor(.cyan)
                            Text("Показать QR-код").font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.gray)
                        }.padding(20).background(Color.white.opacity(0.05)).cornerRadius(20)
                    }.padding(.horizontal, 20)
                    
                    Button(action: { showDeleteAlert = true }) {
                        Text("Уничтожить узел").font(.system(size: 17, weight: .bold)).foregroundColor(.red).frame(maxWidth: .infinity).padding().background(Color.red.opacity(0.1)).cornerRadius(20)
                    }.padding(.horizontal, 20).padding(.top, 10)
                }
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Управление Штабом").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showQR) { HQQRScanner(hqID: meshManager.myHQID) }
        .alert(isPresented: $showDeleteAlert) {
            Alert(title: Text("ВНИМАНИЕ"), message: Text("Все данные будут удалены."), primaryButton: .destructive(Text("Уничтожить")) { meshManager.destructEmpireNode() }, secondaryButton: .cancel(Text("Отмена")))
        }
    }
    
    private func colorForLog(_ type: SystemLog.LogType) -> Color {
        switch type { case .info: return .gray; case .success: return .green; case .error: return .red; case .warning: return .orange }
    }
    
    private var avatarLetter: String { meshManager.myNickname.isEmpty ? "H" : String(meshManager.myNickname.prefix(1).uppercased()) }
    private var displayName: String { meshManager.myNickname.isEmpty ? "Узел Империи" : meshManager.myNickname }
    private var displayUsername: String { meshManager.myUsername.isEmpty ? meshManager.myHQID : meshManager.myUsername }
}

struct HQDashboardRow: View {
    let icon: String; let title: String; let value: String; let valueColor: Color
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)).frame(width: 44, height: 44)
                Image(systemName: icon).foregroundColor(valueColor)
            }
            Text(title).font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
            Spacer()
            Text(value).font(.system(size: 14, weight: .heavy, design: .monospaced)).foregroundColor(valueColor)
        }.padding(16)
    }
}

struct HQQRScanner: View {
    let hqID: String
    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.02, blue: 0.05).ignoresSafeArea()
            VStack(spacing: 40) {
                Text("Протокол сопряжения").font(.system(size: 28, weight: .bold)).foregroundColor(.white).padding(.top, 50)
                ZStack {
                    RoundedRectangle(cornerRadius: 40).fill(Color.white).frame(width: 320, height: 320)
                    Image(uiImage: generateQRCode(from: hqID)).interpolation(.none).resizable().scaledToFit().frame(width: 280, height: 280)
                }
                Text(hqID).font(.system(size: 22, weight: .black, design: .monospaced)).foregroundColor(.cyan).padding().background(Color.cyan.opacity(0.15)).cornerRadius(16)
                Spacer()
            }
        }
    }
    func generateQRCode(from string: String) -> UIImage {
        let context = CIContext(); let filter = CIFilter.qrCodeGenerator(); filter.setValue(Data(string.utf8), forKey: "inputMessage")
        if let outputImage = filter.outputImage, let cgImage = context.createCGImage(outputImage, from: outputImage.extent) { return UIImage(cgImage: cgImage) }
        return UIImage()
    }
}
