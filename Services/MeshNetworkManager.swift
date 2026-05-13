import Foundation
import MultipeerConnectivity
import SwiftUI

final class MeshNetworkManager: NSObject, ObservableObject {
    private let queue = QueueManager()
    private let persistence = PersistenceManager()
    
    @Published var connectionState: ConnectionStatus = .searching
    @Published var messages: [ChatMessage] = []
    @Published var myHQID: String = ""
    @Published var hasAccess: Bool = false
    
    enum ConnectionStatus { case searching, connected, meshOnly }

    private var webSocket: URLSessionWebSocketTask?
    private var session: MCSession!
    private var myPeerID: MCPeerID!
    
    override init() {
        super.init()
        self.loadIdentity()
        self.setupMesh()
        if hasAccess { self.connect() }
    }
    
    private func loadIdentity() {
        self.hasAccess = persistence.fetchBool(forKey: .accessGranted)
        self.myHQID = persistence.fetchString(forKey: .nodeID) ?? "HQ-\(UUID().uuidString.prefix(6))"
        persistence.save(self.myHQID, forKey: .nodeID)
    }

    func connect() {
        guard let url = URL(string: AppConstants.serverURL) else { return }
        webSocket = URLSession.shared.webSocketTask(with: url)
        webSocket?.resume()
        
        // Попытка разгрузить очередь при подключении
        queue.flush { packet in
            self.sendRaw(packet.payload, to: packet.recipient)
            return true
        }
    }

    func send(to recipient: String, text: String) {
        let encrypted = SecurityEngine.encrypt(text)
        
        // Пытаемся отправить через Mesh
        if !sendViaMesh(encrypted, to: recipient) {
            if connectionState == .connected {
                sendRaw(encrypted, to: recipient)
            } else {
                queue.push(to: recipient, data: encrypted)
            }
        }
        
        self.messages.append(ChatMessage(text: text, isMe: true, partnerId: recipient, timestamp: Date()))
    }
    
    private func sendRaw(_ data: String, to: String) {
        let json: [String: Any] = ["type": "msg", "from": myHQID, "to": to, "body": data]
        if let raw = try? JSONSerialization.data(withJSONObject: json), let str = String(data: raw, encoding: .utf8) {
            webSocket?.send(.string(str)) { _ in }
        }
    }

    private func setupMesh() {
        myPeerID = MCPeerID(displayName: myHQID)
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        // Добавь здесь стандартные делегаты MCSession...
    }
    
    private func sendViaMesh(_ data: String, to: String) -> Bool {
        // Логика Multipeer Connectivity
        return false 
    }
}
