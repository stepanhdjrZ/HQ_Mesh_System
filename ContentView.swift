import SwiftUI
import MultipeerConnectivity

// 1. Точка входа в приложение
@main
struct MessengerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// 2. Модель сообщения с поддержкой аватарок
struct ChatMessage: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let senderID: String // Ghost-1234
    let isMe: Bool
}

// 3. Ядро Меш-сети (Анонимное)
class MeshManager: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    @Published var messages: [ChatMessage] = []
    @Published var connectedNodesCount: Int = 0
    @Published var isOfflineOnly: Bool = true 
    
    var session: MCSession!
    var advertiser: MCNearbyServiceAdvertiser!
    var browser: MCNearbyServiceBrowser!
    
    // Генерируем анонимный позывной раз и навсегда при запуске
    let myGhostID = "Ghost-\(Int.random(in: 1000...9999))"
    var myPeerID: MCPeerID!
    
    // Защита от зацикливания сообщений
    private var processedMessageIDs = Set<UUID>()

    override init() {
        super.init()
        myPeerID = MCPeerID(displayName: myGhostID)
        
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self
        
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: "hq-mesh")
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: "hq-mesh")
        browser.delegate = self
        browser.startBrowsingForPeers()
    }

    func send(_ text: String) {
        if !isOfflineOnly {
            let msg = ChatMessage(id: UUID(), text: "[ТГ] " + text, senderID: myGhostID, isMe: true)
            DispatchQueue.main.async { withAnimation { self.messages.append(msg) } }
            return
        }
        
        let msg = ChatMessage(id: UUID(), text: text, senderID: myGhostID, isMe: true)
        DispatchQueue.main.async { withAnimation { self.messages.append(msg) } }
        processedMessageIDs.insert(msg.id) 
        
        if let data = try? JSONEncoder().encode(msg) {
            broadcast(data)
        }
    }

    private func broadcast(_ data: Data) {
        guard !session.connectedPeers.isEmpty else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    // --- ЛОГИКА HOP (ПРЫЖКА) ---
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let receivedData = try? JSONDecoder().decode(ChatMessage.self, from: data) {
            if !processedMessageIDs.contains(receivedData.id) {
                processedMessageIDs.insert(receivedData.id)
                
                // Создаем сообщение для экрана, указывая, что оно не наше
                let msgForUI = ChatMessage(id: receivedData.id, text: receivedData.text, senderID: receivedData.senderID, isMe: false)
                
                DispatchQueue.main.async {
                    withAnimation { self.messages.append(msgForUI) }
                }
                
                // РЕТРАНСЛЯЦИЯ ДАЛЬШЕ
                broadcast(data)
            }
        }
    }

    // Технические методы
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { self.connectedNodesCount = session.connectedPeers.count }
    }
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
