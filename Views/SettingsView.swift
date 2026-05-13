import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

struct SettingsView: View {
    @EnvironmentObject var meshManager: MeshNetworkManager
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Profile Header
                VStack(spacing: 12) {
                    Circle()
                        .fill(LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 100, height: 100)
                        .overlay(Text(avatarLetter).font(.system(size: 40, weight: .bold)).foregroundColor(.white))
                        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                    
                    Text(displayName).font(.title2.bold())
                    Text("@\(displayUsername)").foregroundColor(.secondary).font(.subheadline)
                }
                .padding(.top, 32)
                
                // Network Status Cards
                VStack(spacing: 0) {
                    NetworkStatusRow(
                        icon: "server.rack",
                        title: "HQ Сервер",
                        status: meshManager.connectionState == .connected ? "В сети" : "Поиск...",
                        statusColor: meshManager.connectionState == .connected ? .green : .orange
                    )
                    
                    Divider().padding(.leading, 56)
                    
                    NetworkStatusRow(
                        icon: "antenna.radiowaves.left.and.right",
                        title: "Mesh P2P",
                        status: "\(meshManager.nearbyNodes.count) узлов",
                        statusColor: .blue
                    )
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .padding(.horizontal)
                
                Spacer()
                
                // Danger Zone
                Button(role: .destructive, action: { meshManager.deleteAccountRequest() }) {
                    Text("Выйти и удалить устройство").bold()
                }
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Профиль")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Helpers
    private var avatarLetter: String {
        meshManager.myNickname.isEmpty ? "H" : String(meshManager.myNickname.prefix(1).uppercased())
    }
    private var displayName: String {
        meshManager.myNickname.isEmpty ? "Узел Империи" : meshManager.myNickname
    }
    private var displayUsername: String {
        meshManager.myUsername.isEmpty ? meshManager.myHQID : meshManager.myUsername
    }
}

struct NetworkStatusRow: View {
    let icon: String
    let title: String
    let status: String
    let statusColor: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(statusColor)
                .cornerRadius(10)
            
            Text(title).font(.body.weight(.medium))
            Spacer()
            Text(status).foregroundColor(.secondary).font(.subheadline)
        }
        .padding()
    }
}
