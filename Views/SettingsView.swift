import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

struct SettingsView: View {
    @EnvironmentObject var meshManager: MeshNetworkManager
    @State private var showQR = false
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.02, green: 0.05, blue: 0.1), .black], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    ZStack {
                        Circle().fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 110, height: 110).shadow(color: .cyan.opacity(0.4), radius: 20)
                        Text(avatarLetter).font(.system(size: 46, weight: .black)).foregroundColor(.white)
                    }
                    VStack(spacing: 4) {
                        Text(displayName).font(.title2.weight(.bold)).foregroundColor(.white)
                        Text("@\(displayUsername)").foregroundColor(.cyan).font(.subheadline.monospaced())
                    }
                }.padding(.top, 40)
                
                VStack(spacing: 0) {
                    NetworkStatusRowGlass(icon: "server.rack", title: "HQ Сервер", status: meshManager.connectionState == .connected ? "В сети" : "Поиск Штаба", statusColor: meshManager.connectionState == .connected ? .green : .orange)
                    Divider().background(Color.white.opacity(0.1)).padding(.leading, 64)
                    NetworkStatusRowGlass(icon: "antenna.radiowaves.left.and.right", title: "Mesh P2P", status: "\(meshManager.nearbyNodes.count) узлов", statusColor: .cyan)
                }
                .background(RoundedRectangle(cornerRadius: 24).fill(Color.white.opacity(0.05)).background(Material.ultraThinMaterial))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1)).padding(.horizontal, 20)
                
                Button(action: { UIImpactFeedbackGenerator(style: .light).impactOccurred(); showQR = true }) {
                    HStack {
                        Image(systemName: "qrcode.viewfinder").font(.title3).foregroundColor(.cyan)
                        Text("Показать координаты узла").font(.headline).foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(.gray)
                    }.padding(18).background(Color.white.opacity(0.05).background(Material.ultraThinMaterial)).cornerRadius(20).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
                }.padding(.horizontal, 20)
                
                Spacer()
                
                Button(role: .destructive, action: { UIImpactFeedbackGenerator(style: .heavy).impactOccurred(); meshManager.deleteAccountRequest() }) {
                    Text("Уничтожить узел и выйти").font(.headline).foregroundColor(.red).frame(maxWidth: .infinity).padding().background(Color.red.opacity(0.1)).cornerRadius(18)
                }.padding(.horizontal, 20).padding(.bottom, 30)
            }
        }
        .navigationTitle("Управление Штабом").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showQR) { QRViewGlass(hqID: meshManager.myHQID) }
    }
    
    private var avatarLetter: String { meshManager.myNickname.isEmpty ? "H" : String(meshManager.myNickname.prefix(1).uppercased()) }
    private var displayName: String { meshManager.myNickname.isEmpty ? "Узел Империи" : meshManager.myNickname }
    private var displayUsername: String { meshManager.myUsername.isEmpty ? meshManager.myHQID : meshManager.myUsername }
}

struct NetworkStatusRowGlass: View {
    let icon: String; let title: String; let status: String; let statusColor: Color
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(statusColor.opacity(0.2)).frame(width: 40, height: 40)
                Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundColor(statusColor)
            }
            Text(title).font(.body.weight(.medium)).foregroundColor(.white)
            Spacer()
            Text(status).foregroundColor(.gray).font(.subheadline)
        }.padding(16)
    }
}

struct QRViewGlass: View {
    let hqID: String
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
            VStack(spacing: 30) {
                Text("Сканируй для прямого P2P").font(.title2.bold()).foregroundColor(.white).padding(.top, 40)
                ZStack {
                    RoundedRectangle(cornerRadius: 30).fill(Color.white).frame(width: 280, height: 280).shadow(color: .cyan.opacity(0.5), radius: 30)
                    Image(uiImage: generateQRCode(from: hqID)).interpolation(.none).resizable().scaledToFit().frame(width: 240, height: 240)
                }
                Text(hqID).font(.system(.title3, design: .monospaced)).fontWeight(.bold).foregroundColor(.cyan).padding(.horizontal, 20).padding(.vertical, 10).background(Color.cyan.opacity(0.1)).cornerRadius(12)
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
