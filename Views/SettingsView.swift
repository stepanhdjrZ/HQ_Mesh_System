import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

struct SettingsView: View {
    @EnvironmentObject var meshManager: MeshNetworkManager
    @State private var showQR = false
    @State private var showDeleteAlert = false
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.01, green: 0.02, blue: 0.06), .black], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle().fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 120, height: 120).shadow(color: .cyan.opacity(0.5), radius: 30)
                            Text(avatarLetter).font(.system(size: 50, weight: .black)).foregroundColor(.white)
                        }
                        VStack(spacing: 4) {
                            Text(displayName).font(.title.weight(.bold)).foregroundColor(.white)
                            Text("@\(displayUsername)").foregroundColor(.cyan).font(.headline.monospaced())
                        }
                    }.padding(.top, 20)
                    
                    // Live Telemetry Dashboard
                    VStack(spacing: 0) {
                        HQDashboardRow(icon: "server.rack", title: "Состояние Штаба", value: meshManager.connectionState == .connected ? "ONLINE" : "ПОИСК", valueColor: meshManager.connectionState == .connected ? .green : .orange)
                        Divider().background(Color.white.opacity(0.1)).padding(.leading, 64)
                        HQDashboardRow(icon: "network", title: "Локальный Mesh", value: "\(meshManager.nearbyNodes.count) УЗЛОВ", valueColor: .cyan)
                        Divider().background(Color.white.opacity(0.1)).padding(.leading, 64)
                        HQDashboardRow(icon: "arrow.up.arrow.down", title: "Трафик", value: "\(formatBytes(meshManager.bytesSent)) ↑ \(formatBytes(meshManager.bytesReceived)) ↓", valueColor: .gray)
                        Divider().background(Color.white.opacity(0.1)).padding(.leading, 64)
                        HQDashboardRow(icon: "shield.fill", title: "Блок-лист", value: "\(meshManager.blockedUsers.count)", valueColor: .red)
                    }
                    .background(RoundedRectangle(cornerRadius: 24).fill(Color.white.opacity(0.04)).background(Material.ultraThinMaterial))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.08), lineWidth: 1)).padding(.horizontal, 20)
                    
                    // Tools
                    Button(action: { UIImpactFeedbackGenerator(style: .light).impactOccurred(); showQR = true }) {
                        HStack {
                            Image(systemName: "qrcode.viewfinder").font(.title3).foregroundColor(.cyan)
                            Text("Протокол сопряжения (QR)").font(.headline).foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.gray)
                        }.padding(20).background(Color.white.opacity(0.05).background(Material.ultraThinMaterial)).cornerRadius(20).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }.padding(.horizontal, 20)
                    
                    // Self Destruct
                    Button(action: { showDeleteAlert = true }) {
                        Text("Уничтожить узел").font(.headline).foregroundColor(.red).frame(maxWidth: .infinity).padding().background(Color.red.opacity(0.1)).cornerRadius(20)
                    }
                    .padding(.horizontal, 20).padding(.top, 20)
                    .alert("ВНИМАНИЕ", isPresented: $showDeleteAlert) {
                        Button("Отмена", role: .cancel) { }
                        Button("Уничтожить", role: .destructive) {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            meshManager.destructEmpireNode()
                        }
                    } message: { Text("Все криптографические ключи, связи и локальные данные будут безвозвратно удалены с устройства.") }
                }
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Управление Штабом").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showQR) { HQQRScanner(hqID: meshManager.myHQID) }
    }
    
    private var avatarLetter: String { meshManager.myNickname.isEmpty ? "H" : String(meshManager.myNickname.prefix(1).uppercased()) }
    private var displayName: String { meshManager.myNickname.isEmpty ? "Узел Империи" : meshManager.myNickname }
    private var displayUsername: String { meshManager.myUsername.isEmpty ? meshManager.myHQID : meshManager.myUsername }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter(); formatter.allowedUnits = [.useKB, .useMB]; formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct HQDashboardRow: View {
    let icon: String; let title: String; let value: String; let valueColor: Color
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)).frame(width: 44, height: 44)
                Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundColor(valueColor)
            }
            Text(title).font(.body.weight(.semibold)).foregroundColor(.white)
            Spacer()
            Text(value).font(.subheadline.weight(.heavy)).foregroundColor(valueColor).fontDesign(.monospaced)
        }.padding(16)
    }
}

struct HQQRScanner: View {
    let hqID: String
    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.02, blue: 0.05).ignoresSafeArea()
            VStack(spacing: 40) {
                Text("Протокол сопряжения").font(.title.bold()).foregroundColor(.white).padding(.top, 50)
                ZStack {
                    RoundedRectangle(cornerRadius: 40).fill(Color.white).frame(width: 320, height: 320).shadow(color: .cyan.opacity(0.6), radius: 40)
                    Image(uiImage: generateQRCode(from: hqID)).interpolation(.none).resizable().scaledToFit().frame(width: 280, height: 280)
                }
                Text(hqID).font(.system(.title2, design: .monospaced)).fontWeight(.black).foregroundColor(.cyan).padding(.horizontal, 24).padding(.vertical, 16).background(Color.cyan.opacity(0.15)).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cyan.opacity(0.5), lineWidth: 2))
                Spacer()
            }
        }
    }
    
    func generateQRCode(from string: String) -> UIImage {
        let context = CIContext(); let filter = CIFilter.qrCodeGenerator()
        filter.setValue(Data(string.utf8), forKey: "inputMessage")
        if let outputImage = filter.outputImage, let cgImage = context.createCGImage(outputImage, from: outputImage.extent) { return UIImage(cgImage: cgImage) }
        return UIImage()
    }
}
