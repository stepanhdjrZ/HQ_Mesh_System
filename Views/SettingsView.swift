import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var meshManager: MeshNetworkManager
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                VStack {
                    Circle()
                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 100, height: 100)
                        .overlay(Text(String(meshManager.myHQID.prefix(1))).font(.system(size: 40, weight: .bold)).foregroundColor(.white))
                        .shadow(radius: 10)
                    
                    Text("Основатель HQ").font(.title2).bold()
                    Text("ID: \(meshManager.myHQID)").foregroundColor(.gray)
                }
                .padding(.top, 40)

                // Status Card
                VStack(spacing: 0) {
                    StatusRow(title: "Штаб (Ryzen)", status: meshManager.connectionState == .connected ? "В сети" : "Поиск...", color: meshManager.connectionState == .connected ? .green : .orange)
                    Divider().padding(.leading, 50)
                    StatusRow(title: "Mesh (P2P)", status: "\(meshManager.nearbyDevices.count) узлов рядом", color: .blue)
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(15)
                .padding(.horizontal)

                Spacer()
            }
        }
    }
}

struct StatusRow: View {
    let title: String
    let status: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .foregroundColor(.white)
                .padding(8)
                .background(color)
                .cornerRadius(8)
            
            Text(title)
            Spacer()
            Text(status).foregroundColor(.gray)
        }
        .padding()
    }
}
