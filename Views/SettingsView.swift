import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var manager: MeshNetworkManager
    @State private var showQR = false
    
    var body: some View {
        ZStack {
            Color(red: 0.01, green: 0.02, blue: 0.05).ignoresSafeArea()
            
            List {
                // MARK: - Node Identity
                Section {
                    HStack(spacing: 20) {
                        ZStack {
                            Circle().fill(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
                                .frame(width: 80, height: 80)
                            Text(String(manager.myNickname.prefix(1)).uppercased())
                                .font(.system(size: 32, weight: .black)).foregroundColor(.black)
                        }
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text(manager.myNickname).font(.title2.bold()).foregroundColor(.white)
                            Text(manager.myHQID).font(.system(size: 14, design: .monospaced)).foregroundColor(.cyan)
                        }
                        
                        Spacer()
                        
                        Button(action: { showQR = true }) {
                            Image(systemName: "qrcode").font(.title2).foregroundColor(.cyan)
                        }
                    }
                    .padding(.vertical, 10)
                    .listRowBackground(Color.white.opacity(0.05))
                }
                
                // MARK: - Telemetry (Live Data)
                Section(header: Text("АНАЛИТИКА ТРАФИКА").foregroundColor(.gray)) {
                    MetricRow(label: "Передано по Mesh", value: "\(manager.statsSent) B", icon: "arrow.up.circle", color: .cyan)
                    MetricRow(label: "Получено из эфира", value: "\(manager.statsReceived) B", icon: "arrow.down.circle", color: .blue)
                    MetricRow(label: "Версия протокола", value: AppConstants.serviceType, icon: "cpu", color: .purple)
                }
                .listRowBackground(Color.white.opacity(0.05))
                
                // MARK: - Empire Management
                Section(header: Text("УПРАВЛЕНИЕ УЗЛОМ").foregroundColor(.gray)) {
                    SettingActionRow(label: "Очистить кэш сообщений", icon: "trash", color: .orange) {
                        manager.messages.removeAll()
                    }
                    
                    SettingActionRow(label: "Деактивировать и выйти", icon: "xmark.shield.fill", color: .red) {
                        manager.destructSelfNode()
                    }
                }
                .listRowBackground(Color.white.opacity(0.05))
            }
            .listStyle(InsetGroupedListStyle())
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Штаб-квартира")
        .sheet(isPresented: $showQR) {
             // Здесь будет твой QRDetailView из прошлого пакета
        }
    }
}

struct MetricRow: View {
    let label: String; let value: String; let icon: String; let color: Color
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(color)
            Text(label).foregroundColor(.white)
            Spacer()
            Text(value).font(.system(size: 14, design: .monospaced)).foregroundColor(.gray)
        }
    }
}

struct SettingActionRow: View {
    let label: String; let icon: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon).foregroundColor(color)
                Text(label).foregroundColor(.white)
            }
        }
    }
}
