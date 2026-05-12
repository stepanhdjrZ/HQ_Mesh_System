import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var meshManager: MeshNetworkManager
    @State private var showQR = false
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Circle()
                        .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 90, height: 90)
                        .overlay(Text(String(meshManager.myHQID.prefix(1))).font(.system(size: 40, weight: .bold)).foregroundColor(.white))
                        .shadow(color: .blue.opacity(0.3), radius: 10)
                    
                    Text("Основатель HQ").font(.title3).bold()
                    Text("ID: \(meshManager.myHQID)").font(.subheadline).foregroundColor(.gray)
                }
                .padding(.top, 30)

                // Cards
                VStack(spacing: 1) {
                    StatusRow(icon: "server.rack.fill", title: "Центральный Штаб", status: meshManager.connectionState == .connected ? "В сети" : "Поиск...", color: meshManager.connectionState == .connected ? .green : .orange)
                    StatusRow(icon: "antenna.radiowaves.left.and.right", title: "Mesh-сеть (P2P)", status: meshManager.nearbyNodes == 0 ? "Один в сети" : "\(meshManager.nearbyNodes) узла рядом", color: .blue)
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .padding(.horizontal)

                Button(action: { showQR = true }) {
                    HStack {
                        Image(systemName: "qrcode").font(.title2)
                        Text("Мой Mesh-код").bold()
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }

                Spacer()
            }
        }
        .navigationTitle("Настройки")
    }
}

struct StatusRow: View {
    let icon: String
    let title: String
    let status: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(.white)
                .padding(8)
                .background(color)
                .cornerRadius(10)
            
            Text(title)
            Spacer()
            Text(status).foregroundColor(.gray)
        }
        .padding()
    }
}
