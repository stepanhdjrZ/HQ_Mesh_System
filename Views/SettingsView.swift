import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var manager: MeshNetworkManager
    @State private var showScanner = false
    
    var body: some View {
        List {
            Section {
                HStack(spacing: 15) {
                    Circle().fill(Color.cyan).frame(width: 60, height: 60)
                        .overlay(Text(String(manager.myNickname.prefix(1))).font(.title.bold()).foregroundColor(.black))
                    
                    VStack(alignment: .leading) {
                        Text(manager.myNickname).font(.headline)
                        Text(manager.myHQID).font(.caption).monospaced().foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 8)
            }
            
            Section("АНАЛИТИКА ТРАФИКА") {
                HStack {
                    Label("Передано", systemImage: "arrow.up.circle").foregroundColor(.cyan)
                    Spacer()
                    Text("\(manager.statsSent) B").monospaced()
                }
                HStack {
                    Label("Получено", systemImage: "arrow.down.circle").foregroundColor(.blue)
                    Spacer()
                    Text("\(manager.statsReceived) B").monospaced()
                }
            }
            
            Section {
                Button(action: { showScanner = true }) {
                    Label("Сканировать новый узел", systemImage: "qrcode.viewfinder")
                }
                Button("Выйти из Империи", role: .destructive) {
                    manager.logout()
                }
            }
        }
        .navigationTitle("Штаб")
        .sheet(isPresented: $showScanner) {
            QRScannerView { code in
                manager.handleExternalQR(code)
                showScanner = false
            }
        }
    }
}
