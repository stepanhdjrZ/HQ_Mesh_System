import SwiftUI
import CoreImage.CIFilterBuiltins

struct SettingsView: View {
    @EnvironmentObject var meshManager: MeshNetworkManager
    @State private var showMyQR = false
    
    var body: some View {
        ZStack {
            Color(red: 0.01, green: 0.02, blue: 0.06).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 35) {
                    // MARK: - Profile Card
                    VStack(spacing: 15) {
                        ZStack {
                            Circle().fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 110, height: 110).shadow(color: .cyan.opacity(0.4), radius: 20)
                            Text(String(meshManager.myNickname.prefix(1)).uppercased()).font(.system(size: 45, weight: .black)).foregroundColor(.white)
                        }
                        
                        VStack(spacing: 5) {
                            Text(meshManager.myNickname).font(.title2.bold()).foregroundColor(.white)
                            Text("@" + meshManager.myUsername).font(.headline).foregroundColor(.cyan)
                        }
                    }.padding(.top, 30)

                    // MARK: - Network Dashboard
                    VStack(spacing: 0) {
                        DashboardItem(icon: "antenna.radiowaves.left.and.right", title: "Состояние Сети", value: meshManager.connectionState == .connected ? "ONLINE" : "P2P ONLY", color: meshManager.connectionState == .connected ? .green : .orange)
                        Divider().background(Color.white.opacity(0.1))
                        DashboardItem(icon: "bolt.circle", title: "Узлов рядом", value: "\(meshManager.activePeerCount)", color: .cyan)
                        Divider().background(Color.white.opacity(0.1))
                        DashboardItem(icon: "arrow.up.arrow.down", title: "Трафик (байт)", value: "\(meshManager.bytesSent) ↑ / \(meshManager.bytesReceived) ↓", color: .gray)
                    }
                    .background(Color.white.opacity(0.05)).cornerRadius(25).padding(.horizontal)

                    // MARK: - Core Tools
                    VStack(spacing: 15) {
                        Button(action: { showMyQR = true }) {
                            HStack {
                                Image(systemName: "qrcode").font(.title2).foregroundColor(.cyan)
                                Text("Мой QR Код Сопряжения").font(.headline)
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray)
                            }.padding(22).background(Color.white.opacity(0.05)).cornerRadius(20)
                        }.foregroundColor(.white)
                        
                        Button(action: { meshManager.destructSelfNode() }) {
                            Text("УНИЧТОЖИТЬ УЗЕЛ").font(.headline.bold()).foregroundColor(.red).frame(maxWidth: .infinity).padding().background(Color.red.opacity(0.1)).cornerRadius(20)
                        }
                    }.padding(.horizontal)
                    
                    Text("HQ GLOBAL PROTOCOL v5.0.1 ALPHA").font(.system(size: 10, design: .monospaced)).foregroundColor(.gray.opacity(0.5))
                }
            }
        }
        .navigationTitle("Управление Штабом")
        .sheet(isPresented: $showMyQR) { QRDetails(id: meshManager.myHQID) }
    }
}

struct DashboardItem: View {
    let icon: String; let title: String; let value: String; let color: Color
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(color).frame(width: 30)
            Text(title).foregroundColor(.white)
            Spacer()
            Text(value).font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(color)
        }.padding(20)
    }
}

struct QRDetails: View {
    let id: String
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 35) {
                Text("Ваш ключ в Империи").font(.title3.bold()).foregroundColor(.white)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 30).fill(Color.white).frame(width: 300, height: 300)
                    Image(uiImage: generateQR(from: id))
                        .interpolation(.none).resizable().scaledToFit().frame(width: 250, height: 250)
                }
                
                Text(id).font(.system(size: 24, weight: .black, design: .monospaced)).foregroundColor(.cyan)
                
                Text("Покажите этот код другому участнику\nдля установления прямой связи.").multilineTextAlignment(.center).foregroundColor(.gray).font(.subheadline)
                
                Spacer()
            }.padding(.top, 50)
        }
    }

    func generateQR(from string: String) -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(Data(string.utf8), forKey: "inputMessage")
        if let output = filter.outputImage, let cg = context.createCGImage(output, from: output.extent) { return UIImage(cgImage: cg) }
        return UIImage()
    }
}