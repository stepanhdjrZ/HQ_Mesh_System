import Foundation
import SwiftUI

class MeshNetworkManager: NSObject, ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var messages: [ChatMessage] = []
    @Published var contacts: [Contact] = []
    @Published var myHQID: String = ""
    
    enum ConnectionState { case disconnected, connecting, connected }
    
    private var webSocket: URLSessionWebSocketTask?
    
    override init() {
        super.init()
        loadData()
        connectToHQ()
    }
    
    func connectToHQ() {
        // ... (код подключения wss://hq-mesh.site/ws остается без изменений, он рабочий)
    }
    
    // ... (остальные функции для отсылки сообщений тоже, они правильные)
}
