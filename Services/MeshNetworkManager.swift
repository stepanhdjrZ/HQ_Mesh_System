import Foundation
import MultipeerConnectivity
import SwiftUI

// Константы для СМС-заглушки
struct MockSMS {
    static let code = "1234" // Любой номер, код 1234
    static let delay: Double = 1.2
}

class MeshNetworkManager: NSObject, ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var messages: [ChatMessage] = []
    @Published var contacts: [Contact] = []
    @Published var nearbyNodes: [String] = [] // Реальные узлы вокруг
    @Published var myHQID: String = ""
    @Published var hasAccess = false

    enum ConnectionState { case disconnected, connecting, connected, meshOnly }
    
    private var webSocket: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    
    // MESH CORE (Apple Multipeer Connectivity)
    private let serviceType = "hq-global-mesh"
    private var myPeerID: MCPeerID!
    private var serviceAdvertiser: MCNearbyServiceAdvertiser!
    private var serviceBrowser: MCNearbyServiceBrowser!
    private var session: MCSession!

    override init() {
        super.init()
        loadData()
        setupMesh() // Запускаем Bluetooth-движок
        if hasAccess { connectToHQ() }
    }
    
    // 1. НАСТРОЙКА РЕАЛЬНОГО MESH (P2P)
    private func setupMesh() {
        myPeerID = MCPeerID(displayName: myHQID)
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        
        serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        serviceAdvertiser.delegate = self
        serviceAdvertiser.startAdvertisingPeer()
        
        serviceBrowser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        serviceBrowser.delegate = self
        serviceBrowser.startBrowsingForPeers()
    }

    // 2. ВХОД И ИМИТАЦИЯ СМС
    func requestSMSCode(for phone: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + MockSMS.delay) { completion(true) }
    }
    
    func verifyCode(_ code: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + MockSMS.delay) {
            let success = code == MockSMS.code
            if success {
                self.hasAccess = true
                UserDefaults.standard.set(true, forKey: "isRegistered")
                self.connectToHQ()
            }
            completion(success)
        }
    }

    // 3. РЕАЛЬНЫЙ WEBSOCKET
    func connectToHQ() {
        DispatchQueue.main.async { self.connectionState = .connecting }
        let url = URL(string: "wss://hq-mesh.site/ws")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
        webSocket = URLSession.shared.webSocketTask(with: request)
        webSocket?.resume()
        
        let registerMsg = "{\"type\": \"register\", \"my_id\": \"\(myHQID)\"}"
        webSocket?.send(.string(registerMsg)) { error in
            if error == nil {
                DispatchQueue.main.async { self.connectionState = .connected }
                self.listen()
                self.startHeartbeat()
            } else { self.handleDisconnect() }
        }
    }
    
    // 4. УПРАВЛЕНИЕ ДАННЫМИ И УДАЛЕНИЕ (Для Apple)
    func sendMessage(to targetID: String, text: String) {
        let msgPayload: [String: Any] = ["type": "private_msg", "to_id": targetID, "text": text]
        
        // Попытка отправить через сервер
        if connectionState == .connected {
            if let data = try? JSONSerialization.data(withJSONObject: msgPayload),
               let string = String(data: data, encoding: .utf8) {
                webSocket?.send(.string(string)) { _ in }
            }
        }
        
        // Попытка отправить через Mesh (Bluetooth)
        if let data = try? JSONSerialization.data(withJSONObject: msgPayload) {
            try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
        }
        
        // Локальное сохранение
        DispatchQueue.main.async {
            let newMsg = ChatMessage(text: text, isMe: true, partnerId: targetID, timestamp: Date())
            self.messages.append(newMsg)
            self.saveContact(id: targetID)
        }
    }
    
    func deleteAccountRequest() {
        let deleteMsg = "{\"type\": \"delete_account\", \"my_id\": \"\(myHQID)\"}"
        webSocket?.send(.string(deleteMsg)) { _ in
            self.webSocket?.cancel(with: .goingAway, reason: nil)
            DispatchQueue.main.async {
                self.connectionState = .disconnected
                self.messages.removeAll()
                self.contacts.removeAll()
                UserDefaults.standard.removeObject(forKey: "myHQID")
                UserDefaults.standard.set(false, forKey: "isRegistered")
                self.loadData() // Генерируем новый ID
            }
        }
    }
    
    // Внутренняя логика (WebSocket parse, loadData, и т.д.)
    private func listen() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let msg):
                if case .string(let text) = msg { self?.parse(text) }
                self?.listen()
            case .failure: self?.handleDisconnect()
            }
        }
    }
    private func startHeartbeat() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            self?.webSocket?.sendPing { error in
                if error != nil { self?.handleDisconnect() }
            }
        }
    }
    private func parse(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String, type == "msg",
              let senderId = json["from_id"] as? String,
              let msgText = json["text"] as? String else { return }
        
        DispatchQueue.main.async {
            let newMsg = ChatMessage(text: msgText, isMe: false, partnerId: senderId, timestamp: Date())
            self.messages.append(newMsg)
            self.saveContact(id: senderId)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
    private func handleDisconnect() {
        DispatchQueue.main.async { self.connectionState = .disconnected }
        pingTimer?.invalidate()
        DispatchQueue.global().asyncAfter(deadline: .now() + 5.0) { [weak self] in self?.connectToHQ() }
    }
    private func saveContact(id: String) {
        if !contacts.contains(where: { $0.hqId == id }) { contacts.append(Contact(hqId: id, name: "Node \(id.prefix(4))", lastMessageDate: Date())) }
    }
    private func loadData() {
        hasAccess = UserDefaults.standard.bool(forKey: "isRegistered")
        if let savedID = UserDefaults.standard.string(forKey: "myHQID") { self.myHQID = savedID }
        else {
            let newID = "HQ-\(UUID().uuidString.prefix(5))"
            UserDefaults.standard.set(newID, forKey: "myHQID")
            self.myHQID = newID
        }
    }
}

// ДЕЛЕГАТЫ MESH-СЕТИ (Bluetooth)
extension MeshNetworkManager: MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) { invitationHandler(true, session) }
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) { browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10) }
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) { DispatchQueue.main.async { self.nearbyNodes = session.connectedPeers.map { $0.displayName } } }
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let text = json["text"] as? String {
            DispatchQueue.main.async { self.messages.append(ChatMessage(text: text, isMe: false, partnerId: peerID.displayName, timestamp: Date())) }
        }
    }
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {}
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {}
}
