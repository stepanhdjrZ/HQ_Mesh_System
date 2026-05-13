import Foundation
import MultipeerConnectivity
import SwiftUI
import Combine

final class MeshNetworkManager: NSObject, ObservableObject {
    // MARK: - Архитектурные слои
    private let persistence = PersistenceManager()
    private let queue = QueueManager()
    
    @Published var connectionState: ConnectionState = .disconnected
    @Published var messages: [ChatMessage] = []
    @Published var contacts: [Contact] = []
    
    @Published var myHQID: String = ""
    @Published var myNickname: String = ""
    @Published var hasAccess: Bool = false
    @Published var authStep: MeshAuthStep = .enterEmail
    @Published var isProcessing: Bool = false
    
    @Published var statsSent: Int64 = 0
    @Published var statsReceived: Int64 = 0
    
    enum MeshAuthStep { case enterEmail, enterCode, setupProfile }
    
    private var webSocket: URLSessionWebSocketTask?
    private var session: MCSession!
    private var myPeerID: MCPeerID!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!
    
    override init() {
        super.init()
        LoggerService.log("Запуск протокола v8.0 Enterprise...", level: .security)
        self.setupIdentity()
        self.initMesh()
        if hasAccess { self.connectToHQ() }
    }
    
    private func setupIdentity() {
        self.hasAccess = persistence.fetchBool(forKey: .accessGranted)
        if let id = persistence.fetchString(forKey: .nodeID) {
            self.myHQID = id
        } else {
            let newID = "HQ-" + UUID().uuidString.prefix(8).uppercased()
            persistence.save(newID, forKey: .nodeID)
            self.myHQID = newID
        }
        self.myNickname = persistence.fetchString(forKey: .nickname) ?? "Shadow Node"
    }

    // MARK: - Глобальная связь (Штаб)
    func connectToHQ() {
        guard let url = URL(string: AppConstants.serverURL) else { return }
        self.connectionState = .connecting
        
        let request = URLRequest(url: url)
        webSocket = URLSession.shared.webSocketTask(with: request)
        webSocket?.resume()
        
        self.listen()
        self.ping()
        
        // Когда Штаб онлайн — пытаемся выплюнуть очередь
        self.queue.processQueue { msg in
            self.transmit(msg.payload)
            return true
        }
    }

    private func listen() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                self.record(received: true, size: 1024)
                if case .string(let text) = message { self.handleJSON(text) }
                self.listen()
                DispatchQueue.main.async { self.connectionState = .connected }
            case .failure(let error):
                LoggerService.log("Разрыв связи: \(error.localizedDescription)", level: .error)
                DispatchQueue.main.async { self.connectionState = .meshOnly }
                DispatchQueue.global().asyncAfter(deadline: .now() + 5) { self.connectToHQ() }
            }
        }
    }

    // MARK: - Маршрутизация (Уровень ТГ)
    func broadcastData(to target: String, content: String) {
        let encrypted = SecurityEngine.encrypt(content)
        let packet: [String: Any] = [
            "type": "secure_msg",
            "from": myHQID,
            "to": target,
            "body": encrypted,
            "ts": Date().timeIntervalSince1970
        ]
        
        // 1. Прямой Mesh (Bluetooth) — самый быстрый
        let meshSent = self.sendToMesh(packet)
        
        // 2. Через Штаб (WebSocket)
        if connectionState == .connected {
            self.transmit(packet)
        } else if !meshSent {
            // 3. Если всё упало — в очередь!
            self.queue.addToQueue(target: target, data: packet)
        }
        
        // Локальное отображение
        let msg = ChatMessage(text: content, isMe: true, partnerId: target, timestamp: Date())
        self.messages.append(msg)
    }

    private func transmit(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else { return }
        webSocket?.send(.string(str)) { _ in 
            self.record(received: false, size: Int64(str.count))
        }
    }

    private func handleJSON(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }
        
        DispatchQueue.main.async {
            switch type {
            case "secure_msg": self.processInbound(json)
            case "auth_code_ok": self.authStep = .enterCode
            default: break
            }
        }
    }

    private func processInbound(_ json: [String: Any]) {
        guard let from = json["from"] as? String, let body = json["body"] as? String else { return }
        let decrypted = SecurityEngine.decrypt(body)
        let newMsg = ChatMessage(text: decrypted, isMe: false, partnerId: from, timestamp: Date())
        self.messages.append(newMsg)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    // MARK: - Вспомогательные функции
    private func record(received: Bool, size: Int64) {
        DispatchQueue.main.async {
            if received { self.statsReceived += size }
            else { self.statsSent += size }
        }
    }

    func logout() {
        persistence.wipeAllData()
        self.hasAccess = false
        self.authStep = .enterEmail
    }

    private func initMesh() {
        myPeerID = MCPeerID(displayName: myHQID)
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: AppConstants.serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: AppConstants.serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
    }
    
    private func sendToMesh(_ dict: [String: Any]) -> Bool {
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return false }
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            return true
        } catch { return false }
    }
    
    private func ping() {
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            self.webSocket?.sendPing { _ in }
        }
    }
}

// MARK: - MPC Delegates (Стандарт Apple)
extension MeshNetworkManager: MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) { invitationHandler(true, session) }
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) { browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10) }
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) { }
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            DispatchQueue.main.async { self.processInbound(json) }
        }
    }
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
