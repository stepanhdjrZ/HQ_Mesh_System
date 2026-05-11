import Foundation
import Combine

class MeshNetworkManager: ObservableObject {
    @Published var isConnectedToRyzen: Bool = false
    @Published var activeNodesNearby: Int = 0
    
    init() {
        // Здесь позже будет логика подключения к твоему ПК и поиск Bluetooth/Wi-Fi узлов
        startScanning()
    }
    
    func startScanning() {
        // Имитация поиска узлов
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.activeNodesNearby = 1
        }
    }
}
