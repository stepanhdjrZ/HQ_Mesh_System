import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var meshManager: MeshNetworkManager
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            
            VStack(spacing: 25) {
                VStack(spacing: 10) {
                    Circle()
                        .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 90, height: 90)
                        .overlay(Text(firstLetter).font(.title.bold()).foregroundColor(.white))
                        .shadow(radius: 10)
                    
                    Text(meshManager.myNickname.isEmpty ? "Основатель HQ" : meshManager.myNickname).font(.title3).bold()
                    Text(meshManager.myUsername.isEmpty ? "ID: \(meshManager.myHQID)" : "@\(meshManager.myUsername)").foregroundColor(.blue).font(.subheadline)
                }
                .padding(.top, 40)
                
                VStack(spacing: 0) {
                    StatusItem(title: "Центральный Штаб", status: meshManager.connectionState == .connected ? "В сети" : "Поиск...", color: meshManager.connectionState == .connected ? .green : .orange)
                    Divider().padding(.leading, 60)
                    StatusItem(title: "Локальный Mesh", status: "\(meshManager.nearbyNodes.count) узлов", color: .blue)
                }
                .background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(16).padding(.horizontal)
                
                Spacer()
                
                Button(role: .destructive, action: { meshManager.deleteAccountRequest() }) {
                    Text("Выйти из аккаунта и удалить данные").bold()
                }.padding(.bottom, 20)
            }
        }
        .navigationTitle("Профиль")
    }
    
    private var firstLetter: String {
        return meshManager.myNickname.isEmpty ? "H" : String(meshManager.myNickname.prefix(1))
    }
}

struct StatusItem: View {
    let title: String; let status: String; let color: Color
    var body: some View {
        HStack {
            Image(systemName: "antenna.radiowaves.left.and.right").foregroundColor(.white).padding(8).background(color).cornerRadius(10)
            Text(title)
            Spacer()
            Text(status).foregroundColor(.gray)
        }.padding()
    }
}
