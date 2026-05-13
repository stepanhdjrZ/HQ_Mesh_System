import Foundation
import MultipeerConnectivity
import SwiftUI
import UIKit
import Combine

// MARK: - Core Data Architecture
struct ChatMessage: Identifiable, Codable, Hashable {
    var id = UUID()
    let text: String
    let isMe: Bool
    let partnerId: String
    let timestamp: Date
    var isDelivered: Bool = false
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

struct Contact: Identifiable, Codable, Hashable {
    var id = UUID()
    let hqId: String
    let name: String
    var lastMessageDate: Date
    var status: NodeStatus = .offline
    
    enum NodeStatus: String, Codable { case online, offline, mesh }
}

// MARK: - HQ Global Engine
class MeshNetworkManager: NSObject, ObservableObject {
    // Shared States
    @Published var connectionState: ConnectionState = .disconnected
    @Published var messages: [ChatMessage] = []
    @Published var contacts: [Contact] = []
    @Published var nearbyNodes: [String] = []
    @Published var blockedUsers: [String] = []
    
    // User Identity & Security
    @Published var myHQID: String = ""
    @Published var myUsername: String = ""
    @Published var myNickname: String = ""
    @Published var hasAccess: Bool = false
    
    // Auth State Machine
    @Published var authStep: AuthStep = .enterEmail
    @Published var isWaiting: Bool = false
    @Published var authError: String = ""
    
    // Telemetry & Metrics
    @Published var bytesSent: Int64 = 0
    @Published var bytesReceived: Int64 = 0
    @Published var activePeerCount: Int = 0

    enum ConnectionState { case disconnected, connecting, connected, meshOnly }
    enum AuthStep { case enterEmail, enterCode, setupProfile }
    
    // Private Infrastructure
    private var webSocket: URLSessionWebSocketTask?
    private let serviceType = "hq-global-mesh-v5"
    private var myPeerID: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!
    private var heartbeatTimer: Timer?
    private let serverURL = "wss://elevation-strength-authentic.ngrok-free.dev/ws"

    // MARK: - Initialization
    override init() {
        super.init()
        print("[HQ] Запуск системного ядра...")
        self.loadPersistentStorage()
        self.initializeMeshProtocol()
        if hasAccess { self.establishHQLink() }
    }

    // MARK: - Authentication API
    func requestAccessCode(email: String) {
        guard email.contains("@") && email.count > 5 else {
            self.authError = "Критическая ошибка: Неверный формат почты"
            return
        }
        self.isWaiting = true
        self.authError = ""
        self.transmitJSON(["type": "request_code", "email": email.lowercased()])
    }
    
    func registerEmpireNode(email: String, code: String, username: String, nickname: String) {
        self.isWaiting = true
        self.transmitJSON([
            "type": "verify_and_register",
            "email": email,
            "code": code,
            "username": username,
            "nickname": nickname,
            "hq_id": myHQID
        ])
    }

    // MARK: - HQ Global WebSocket Link
    func establishHQLink() {
        guard let url = URL(string: serverURL) else { return }
        DispatchQueue.main.async { self.connectionState = .connecting }
        
        let request = URLRequest(url: url, timeoutInterval: 15)
        webSocket = URLSession.shared.webSocketTask(with: request)
        webSocket?.resume()
        
        if hasAccess { transmitJSON(["type": "register", "my_id": myHQID]) }
        
        self.listenForDataPackets()
        self.startKeepAliveSignal()
    }

    private func listenForDataPackets() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                self.incrementMetric(received: true, size: 512)
                if case .string(let text) = message { self.parseIncomingJSON(text) }
                self.listenForDataPackets()
                DispatchQueue.main.async { self.connectionState = .connected }
            case .failure(let error):
                print("[HQ ERROR] Разрыв связи со Штабом: \(error)")
                DispatchQueue.main.async { self.connectionState = .meshOnly }
                self.scheduleReconnect()
            }
        }
    }

    private func parseIncomingJSON(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }
        
        DispatchQueue.main.async {
            self.isWaiting = false
            switch type {
            case "code_response":
                if json["success"] as? Bool == true { self.authStep = .enterCode }
                else { self.authError = "Ошибка SMTP-шлюза: Письмо не доставлено." }
            case "auth_success":
                self.persistAccess()
            case "auth_error":
                self.authError = json["text"] as? String ?? "Ошибка авторизации"
            case "msg":
                self.processInboundMessage(json)
            default: break
            }
        }
    }

    // MARK: - Message Routing & Mesh Delivery
    func dispatchMessage(to targetID: String, text: String) {
        let payload: [String: Any] = ["type": "private_msg", "to_id": targetID, "text": text]
        let estSize = Int64(text.count * 2 + 128)
        
        // 1. Попытка через Штаб (WebSocket)
        if connectionState == .connected {
            transmitJSON(payload)
            self.incrementMetric(received: false, size: estSize)
        }
        
        // 2. Параллельная доставка через локальный Mesh (P2P)
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            do {
                try session.send(data, toPeers: session.connectedPeers, with: .reliable)
                self.incrementMetric(received: false, size: estSize)
            } catch {
                print("[HQ MESH] Локальная доставка не удалась")
            }
        }
        
        // 3. Обновление UI
        DispatchQueue.main.async {
            let newMsg = ChatMessage(text: text, isMe: true, partnerId: targetID, timestamp: Date())
            self.messages.append(newMsg)
            self.updateContactHierarchy(id: targetID)
        }
    }

    private func processInboundMessage(_ json: [String: Any]) {
        guard let from = json["from_id"] as? String,
              let text = json["text"] as? String else { return }
        
        if blockedUsers.contains(from) { return }
        
        let newMsg = ChatMessage(text: text, isMe: false, partnerId: from, timestamp: Date())
        self.messages.append(newMsg)
        self.updateContactHierarchy(id: from)
        
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    func handleExternalQR(_ code: String) {
        if code.hasPrefix("HQ-") {
            self.updateContactHierarchy(id: code)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    // MARK: - Advanced Safety & Persistence
    func blockEmpireUser(_ id: String) {
        if !blockedUsers.contains(id) {
            blockedUsers.append(id)
            UserDefaults.standard.set(blockedUsers, forKey: "blockedUsers")
            contacts.removeAll { $0.hqId == id }
            messages.removeAll { $0.partnerId == id }
        }
    }

    private func persistAccess() {
        self.hasAccess = true
        UserDefaults.standard.set(true, forKey: "isRegistered")
        UserDefaults.standard.set(myUsername, forKey: "myUsername")
        UserDefaults.standard.set(myNickname, forKey: "myNickname")
    }

    func destructSelfNode() {
        ["isRegistered", "myHQID", "myUsername", "myNickname", "blockedUsers"].forEach { UserDefaults.standard.removeObject(forKey: $0) }
        self.hasAccess = false
        self.authStep = .enterEmail
        self.messages.removeAll()
        self.contacts.removeAll()
        self.loadPersistentStorage()
    }

    // MARK: - Low Level Protocol Management
    private func transmitJSON(_ dict: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: dict),
           let str = String(data: data, encoding: .utf8) {
            webSocket?.send(.string(str)) { _ in }
        }
    }

    private func scheduleReconnect() {
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) { [weak self] in
            if self?.hasAccess == true { self?.establishHQLink() }
        }
    }

    private func incrementMetric(received: Bool, size: Int64) {
        DispatchQueue.main.async {
            if received { self.bytesReceived += size }
            else { self.bytesSent += size }
        }
    }

    private func loadPersistentStorage() {
        self.hasAccess = UserDefaults.standard.bool(forKey: "isRegistered")
        self.myUsername = UserDefaults.standard.string(forKey: "myUsername") ?? ""
        self.myNickname = UserDefaults.standard.string(forKey: "myNickname") ?? ""
        self.blockedUsers = UserDefaults.standard.stringArray(forKey: "blockedUsers") ?? []
        
        if let id = UserDefaults.standard.string(forKey: "myHQID") { self.myHQID = id }
        else {
            let newID = "HQ-\(UUID().uuidString.prefix(6).uppercased())"
            UserDefaults.standard.set(newID, forKey: "myHQID")
            self.myHQID = newID
        }
    }

    private func initializeMeshProtocol() {
        myPeerID = MCPeerID(displayName: myHQID)
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
    }

    private func updateContactHierarchy(id: String) {
        if let index = contacts.firstIndex(where: { $0.hqId == id }) {
            contacts[index].lastMessageDate = Date()
            let moved = contacts.remove(at: index)
            contacts.insert(moved, at: 0)
        } else {
            contacts.insert(Contact(hqId: id, name: "Node " + String(id.suffix(4)), lastMessageDate: Date()), at: 0)
        }
    }

    private func startKeepAliveSignal() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 25.0, repeats: true) { [weak self] _ in
            self?.webSocket?.sendPing { _ in }
        }
    }
}

// MARK: - Multipeer Delegate Implementation
extension MeshNetworkManager: MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) { invitationHandler(true, session) }
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) { browser.invitePeer(peerID, to: session, withContext: nil, timeout: 15) }
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) { 
        DispatchQueue.main.async { 
            self.nearbyNodes = session.connectedPeers.map { $0.displayName } 
            self.activePeerCount = session.connectedPeers.count
        } 
    }
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        DispatchQueue.main.async { self.processInboundMessage(json) }
    }
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {}
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {}
}