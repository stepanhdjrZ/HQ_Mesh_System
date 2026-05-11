import SwiftUI

struct ContentView: View {
    @EnvironmentObject var mesh: MeshNetworkManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Статус-бар сети
                HStack {
                    Circle()
                        .fill(mesh.activeNodesNearby > 0 ? Color.green : Color.orange)
                        .frame(width: 10, height: 10)
                    Text(mesh.activeNodesNearby > 0 ? "Mesh-сеть: \(mesh.activeNodesNearby) узел рядом" : "Поиск узлов...")
                        .font(.caption)
                        .bold()
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                
                List {
                    NavigationLink(destination: ChatView(contactName: "HQ Beta")) {
                        HStack {
                            Circle().fill(Color.blue).frame(width: 50, height: 50)
                            VStack(alignment: .leading) {
                                Text("HQ Beta").bold()
                                Text("Тест системы").foregroundColor(.gray)
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Чаты")
        }
    }
}
