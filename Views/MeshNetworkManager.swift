import Foundation
import MultipeerConnectivity
import SwiftUI
import UIKit

// MARK: - Модели данных
struct ChatMessage: Identifiable, Codable, Hashable {
    var id = UUID()
    let text: String
    let isMe: Bool
    let partnerId: String
    let timestamp: Date
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: timestamp)
    }
}

struct Contact: Identifiable, Codable, Hashable {
    var id = UUID()
    let hqId: String
    let name: String
    var lastMessageDate: Date
}

// MARK: - Менеджер Сети
class MeshNetworkManager: NSObject, ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var messages: [ChatMessage] = []
    @Published var contacts: [Contact] = []
    @Published var nearbyNodes: [String] = []
    @Published var blockedUsers: [String] = []
    
    @Published var myHQID: String = ""
    @Published var myUsername: String = ""
    @Published var myNickname: String = ""
    @Published var hasAccess = false
    
    @Published var authStep: AuthStep = .enterEmail
    @Published var isWaitingForServer = false
    @Published var authError = ""
    
    @Published var bytesSent: Int64 = 0
    @Published var bytesReceived: Int64 = 0

    enum ConnectionState { case disconnected, connecting, connected, meshOnly }
    enum AuthStep { case enterEmail, enterCode, setupProfile }
    
    private var webSocket: URLSessionWebSocketTask?
    private let serviceType = "hq-mesh-v2"
    private var myPeerID: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!
    private var heartbeatTimer: Timer?
    private let serverURL = "wss://elevation-strength-authentic.ngrok-free.dev/ws"

    override init() {
        super.init()
        loadPersistentData()
        setupMeshProtocol()
        if hasAccess { connectToCentralHQ() }
    }

    func requestEmailCode(email: String) {
        if email.contains("@") && email.contains(".") {
            isWaitingForServer = true
            sendWSMessage(["type": "request_code", "email": email])
        } else {
            self.authError = "Неверный формат почты"
        }
    }
    
    func registerUser(email: String, code: String, username: String, nickname: String) {
        isWaitingForServer = true
        sendWSMessage(["type": "verify_and_register", "email": email, "code": code, "username": username, "nickname": nickname, "hq_id": myHQID])
    }

    func connectToCentralHQ() {
        DispatchQueue.main.async { self.connectionState = .connecting }
        guard let url = URL(string: serverURL) else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        webSocket = URLSession.shared.webSocketTask(with: request)
        webSocket?.resume()
        
        if hasAccess { sendWSMessage(["type": "register", "my_id": myHQID]) }
        startHeartbeat()
        listenToWebSocket()
    }

    private func listenToWebSocket() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let msg):
                DispatchQueue.main.async { self.bytesReceived += 256 }
                if case .string(let text) = msg { self.processIncomingData(text) }
                self.listenToWebSocket()
                DispatchQueue.main.async { self.connectionState = .connected }
            case .failure(_):
                DispatchQueue.main.async { self.connectionState = .meshOnly }
                self.scheduleSecureReconnect()
            }
        }
    }

    private func processIncomingData(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }
        
        DispatchQueue.main.async {
            self.isWaitingForServer = false
            switch type {
            case "code_response":
                if json["success"] as? Bool == true { self.authStep = .enterCode } else { self.authError = "Ошибка сервера." }
            case "auth_success":
                self.finalizeRegistration()
            case "auth_error":
                self.authError = json["text"] as? String ?? "Ошибка верификации"
            case "msg":
                self.handleIncomingMessage(json)
            default: break
            }
        }
    }

    func sendMessage(to targetID: String, text: String) {
        let payload: [String: Any] = ["type": "private_msg", "to_id": targetID, "text": text]
        let packetSize = text.count * 2 + 128
        
        if connectionState == .connected {
            sendWSMessage(payload)
            DispatchQueue.main.async { self.bytesSent += Int64(packetSize) }
        }
        
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
            DispatchQueue.main.async { self.bytesSent += Int64(packetSize) }
        }
        
        DispatchQueue.main.async {
            self.messages.append(ChatMessage(text: text, isMe: true, partnerId: targetID, timestamp: Date()))
            self.updateContactTop(id: targetID, name: targetID)
        }
    }

    private func handleIncomingMessage(_ json: [String: Any]) {
        guard let senderId = json["from_id"] as? String, let msgText = json["text"] as? String else { return }
        if blockedUsers.contains(senderId) { return }
        
        let newMsg = ChatMessage(text: msgText, isMe: false, partnerId: senderId, timestamp: Date())
        self.messages.append(newMsg)
        self.updateContactTop(id: senderId, name: "Node \(senderId.prefix(4))")
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func updateContactTop(id: String, name: String) {
        if let index = contacts.firstIndex(where: { $0.hqId == id }) {
            contacts[index].lastMessageDate = Date()
            let moved = contacts.remove(at: index)
            contacts.insert(moved, at: 0)
        } else {
            contacts.insert(Contact(hqId: id, name: name, lastMessageDate: Date()), at: 0)
        }
    }

    func blockNode(_ id: String) {
        DispatchQueue.main.async {
            if !self.blockedUsers.contains(id) {
                self.blockedUsers.append(id)
                UserDefaults.standard.set(self.blockedUsers, forKey: "blockedUsers")
                self.contacts.removeAll { $0.hqId == id }
                self.messages.removeAll { $0.partnerId == id }
            }
        }
    }

    private func sendWSMessage(_ dict: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: dict), let string = String(data: data, encoding: .utf8) {
            webSocket?.send(.string(string)) { _ in }
        }
    }

    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: true) { [weak self] _ in
            self?.webSocket?.sendPing { error in if error != nil { self?.scheduleSecureReconnect() } }
        }
    }

    private func scheduleSecureReconnect() {
        heartbeatTimer?.invalidate()
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) { [weak self] in
            if self?.hasAccess == true { self?.connectToCentralHQ() }
        }
    }

    private func finalizeRegistration() {
        self.hasAccess = true
        UserDefaults.standard.set(true, forKey: "isRegistered")
        UserDefaults.standard.set(self.myUsername, forKey: "myUsername")
        UserDefaults.standard.set(self.myNickname, forKey: "myNickname")
    }

    func destructEmpireNode() {
        ["isRegistered", "myHQID", "myUsername", "myNickname", "blockedUsers"].forEach { UserDefaults.standard.removeObject(forKey: $0) }
        self.hasAccess = false
        self.authStep = .enterEmail
        self.messages.removeAll()
        self.contacts.removeAll()
        self.blockedUsers.removeAll()
        self.bytesSent = 0
        self.bytesReceived = 0
        webSocket?.cancel(with: .goingAway, reason: nil)
        heartbeatTimer?.invalidate()
        loadPersistentData()
    }

    private func loadPersistentData() {
        self.hasAccess = UserDefaults.standard.bool(forKey: "isRegistered")
        self.myUsername = UserDefaults.standard.string(forKey: "myUsername") ?? ""
        self.myNickname = UserDefaults.standard.string(forKey: "myNickname") ?? ""
        self.blockedUsers = UserDefaults.standard.stringArray(forKey: "blockedUsers") ?? []
        if let savedID = UserDefaults.standard.string(forKey: "myHQID") {
            self.myHQID = savedID
        } else {
            let newID = "HQ-\(UUID().uuidString.prefix(6))"
            UserDefaults.standard.set(newID, forKey: "myHQID")
            self.myHQID = newID
        }
    }

    private func setupMeshProtocol() {
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
}

extension MeshNetworkManager: MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) { invitationHandler(true, session) }
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) { browser.invitePeer(peerID, to: session, withContext: nil, timeout: 15) }
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) { DispatchQueue.main.async { self.nearbyNodes = session.connectedPeers.map { $0.displayName } } }
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        DispatchQueue.main.async { self.bytesReceived += Int64(data.count) }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let text = json["text"] as? String else { return }
        DispatchQueue.main.async {
            if self.blockedUsers.contains(peerID.displayName) { return }
            self.messages.append(ChatMessage(text: text, isMe: false, partnerId: peerID.displayName, timestamp: Date()))
            self.updateContactTop(id: peerID.displayName, name: "Node \(peerID.displayName.prefix(4))")
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
        }
    }
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {}
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {}
}