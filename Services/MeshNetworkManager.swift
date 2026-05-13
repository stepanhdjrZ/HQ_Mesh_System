import Foundation
import MultipeerConnectivity
import SwiftUI
import Combine

// Профессиональный менеджер сетевого взаимодействия
final class MeshNetworkManager: NSObject, ObservableObject {
    
    // MARK: - Published States (UI Sync)
    @Published var connectionState: ConnectionState = .disconnected
    @Published var messages: [ChatMessage] = []
    @Published var contacts: [Contact] = []
    @Published var nearbyNodes: [String] = []
    
    @Published var myHQID: String = ""
    @Published var myNickname: String = ""
    @Published var hasAccess: Bool = false
    @Published var authStep: MeshAuthStep = .enterEmail
    @Published var isProcessing: Bool = false
    @Published var lastError: String = ""
    
    // Телеметрия реального времени
    @Published var statsSent: Int64 = 0
    @Published var statsReceived: Int64 = 0
    
    enum MeshAuthStep { case enterEmail, enterCode, setupProfile }

    // MARK: - Infrastructure
    private var webSocket: URLSessionWebSocketTask?
    private var myPeerID: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!
    
    private var cancellables = Set<AnyCancellable>()
    private var reconnectTimer: Timer?
    
    // MARK: - Lifecycle
    override init() {
        super.init()
        self.bootstrapNode()
    }
    
    private func bootstrapNode() {
        self.loadIdentity()
        self.configureMeshStack()
        
        if hasAccess {
            self.activateGlobalLink()
        }
    }

    // MARK: - Identity Management
    private func loadIdentity() {
        let storage = UserDefaults.standard
        self.hasAccess = storage.bool(forKey: "hq_access_granted")
        self.myNickname = storage.string(forKey: "hq_nick") ?? ""
        
        if let savedID = storage.string(forKey: "hq_node_id") {
            self.myHQID = savedID
        } else {
            let newID = "HQ-" + UUID().uuidString.prefix(8).uppercased()
            storage.set(newID, forKey: "hq_node_id")
            self.myHQID = newID
        }
    }

    // MARK: - Authentication Protocol (v7)
    func initiateAuth(email: String) {
        guard !isProcessing else { return }
        self.isProcessing = true
        self.lastError = ""
        
        // Отправка через зашифрованный канал
        let payload = ["type": "auth_request", "email": email.lowercased(), "node": myHQID]
        self.transmitToHQ(payload)
    }
    
    func completeRegistration(nick: String, user: String) {
        self.isProcessing = true
        let storage = UserDefaults.standard
        storage.set(nick, forKey: "hq_nick")
        storage.set(user, forKey: "hq_user")
        storage.set(true, forKey: "hq_access_granted")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.myNickname = nick
            self.hasAccess = true
            self.isProcessing = false
            self.activateGlobalLink()
        }
    }

    // MARK: - Global HQ Connection (WebSockets)
    private func activateGlobalLink() {
        guard let url = URL(string: AppConstants.serverURL) else { return }
        
        let request = URLRequest(url: url)
        webSocket = URLSession.shared.webSocketTask(with: request)
        webSocket?.resume()
        
        self.listenForInboundTraffic()
        self.sendHandshake()
    }
    
    private func sendHandshake() {
        let handshake = ["type": "node_online", "id": myHQID, "ver": AppConstants.serviceType]
        self.transmitToHQ(handshake)
    }

    private func listenForInboundTraffic() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                self.recordTraffic(received: true, size: 512)
                if case .string(let text) = message { self.handleProtocolJSON(text) }
                self.listenForInboundTraffic()
                DispatchQueue.main.async { self.connectionState = .connected }
            case .failure(let error):
                print("[SECURITY] Global Link Interrupted: \(error)")
                DispatchQueue.main.async { self.connectionState = .meshOnly }
                self.triggerReconnection()
            }
        }
    }

    // MARK: - Messaging & Encryption Layer
    func broadcastData(to target: String, content: String) {
        // Применяем SecurityEngine v7
        let encryptedBody = SecurityEngine.encrypt(content)
        
        let packet: [String: Any] = [
            "type": "secure_msg",
            "from": myHQID,
            "to": target,
            "body": encryptedBody,
            "ts": Date().timeIntervalSince1970
        ]
        
        // Дублированная маршрутизация: Server + P2P
        self.transmitToHQ(packet)
        self.transmitToMesh(packet)
        
        // Локальное обновление
        let uiMsg = ChatMessage(text: content, isMe: true, partnerId: target, timestamp: Date())
        DispatchQueue.main.async {
            self.messages.append(uiMsg)
            self.sortContacts(lastId: target)
        }
    }

    private func handleProtocolJSON(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }
        
        DispatchQueue.main.async {
            self.isProcessing = false
            switch type {
            case "auth_code_sent": self.authStep = .enterCode
            case "secure_msg": self.processInboundPacket(json)
            default: break
            }
        }
    }

    private func processInboundPacket(_ json: [String: Any]) {
        guard let from = json["from"] as? String,
              let encryptedBody = json["body"] as? String else { return }
        
        // Дешифровка
        let decryptedBody = SecurityEngine.decrypt(encryptedBody)
        
        let newMsg = ChatMessage(text: decryptedBody, isMe: false, partnerId: from, timestamp: Date())
        self.messages.append(newMsg)
        self.sortContacts(lastId: from)
        
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    // MARK: - Low-Level Transport
    private func transmitToHQ(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else { return }
        
        webSocket?.send(.string(str)) { error in
            if error == nil { self.recordTraffic(received: false, size: Int64(str.count)) }
        }
    }
    
    private func transmitToMesh(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    private func triggerReconnection() {
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: AppConstants.reconnectDelay, repeats: false) { [weak self] _ in
            self?.activateGlobalLink()
        }
    }
    
    private func recordTraffic(received: Bool, size: Int64) {
        DispatchQueue.main.async {
            if received { self.statsReceived += size }
            else { self.statsSent += size }
        }
    }

    // MARK: - Mesh P2P Configuration
    private func configureMeshStack() {
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
    
    private func sortContacts(lastId: String) {
        if let index = contacts.firstIndex(where: { $0.hqId == lastId }) {
            var contact = contacts.remove(at: index)
            contact.lastMessageDate = Date()
            contacts.insert(contact, at: 0)
        } else {
            let newContact = Contact(hqId: lastId, name: "Node " + String(lastId.suffix(4)), lastMessageDate: Date())
            contacts.insert(newContact, at: 0)
        }
    }
}

// MARK: - MPC Delegates
extension MeshNetworkManager: MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 15)
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.nearbyNodes = session.connectedPeers.map { $0.displayName }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            DispatchQueue.main.async { self.processInboundPacket(json) }
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {}
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {}
}
