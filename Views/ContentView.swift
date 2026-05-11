import SwiftUI

struct ContentView: View {
    @StateObject var meshManager = MeshNetworkManager()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 25) {
                    // Статус подключения
                    HStack {
                        Circle()
                            .fill(meshManager.isConnected ? Color.green : Color.orange)
                            .frame(width: 12, height: 12)
                            .shadow(color: meshManager.isConnected ? .green : .orange, radius: 5)
                        
                        Text(meshManager.isConnected ? "HQ Node: Active (Global)" : "Поиск сигнала...")
                            .foregroundColor(.white)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(20)
                    
                    Text("HQ GLOBAL MESH")
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(.white)
                        .tracking(5)
                    
                    // Список чатов (пока один тестовый)
                    NavigationLink(destination: ChatView(contactName: "HQ Server Hub").environmentObject(meshManager)) {
                        HStack {
                            Image(systemName: "cpu.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("Main Server Hub")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Ryzen 7 9800X3D Online")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(25)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.top, 40)
            }
        }
    }
}
