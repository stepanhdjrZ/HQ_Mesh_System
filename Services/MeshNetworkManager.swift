import Foundation
import MultipeerConnectivity
import SwiftUI
import UIKit
import Combine
import CryptoKit

// MARK: - Core Data Models
struct ChatMessage: Identifiable, Codable, Hashable {
    var id = UUID()
    let text: String
    let isMe: Bool
    let partnerId: String
    let timestamp: Date
    
    var timeString: String {
        let formatter = DateFormatter(); formatter.dateFormat = "HH:mm"
        return formatter.string(from: timestamp)
    }
}

struct Contact: Identifiable, Codable, Hashable {
    var id = UUID()
    let hqId: String
    let name: String
    var lastMessageDate: Date
    var unreadCount: Int = 0
}

// MARK: - Global Network Manager
class MeshNetworkManager: NSObject, ObservableObject {
    // MARK: Published UI States
    @Published var connectionState: ConnectionState = .disconnected
    @Published var messages: [ChatMessage] = []
    @Published var contacts: [Contact] = []
    @Published var nearbyNodes: [String] = []
    @Published var blockedUsers: [String] = []
    
    // MARK: User Identity
    @Published var myHQID: String = ""
    @Published var myUsername: String = ""
    @Published var myNickname: String = ""
    @Published var hasAccess = false
    
    // MARK: Auth State Machine
    @Published var authStep: AuthStep = .enterEmail
    @Published var isWaitingForServer = false
    @Published var authError = ""
    
    // MARK: Advanced Telemetry
    @Published var bytesSent: Int64 = 0
    @Published var bytesReceived: Int64 = 0
    @Published var sessionUptime: TimeInterval = 0

    enum ConnectionState { case disconnected, connecting, connected, meshOnly }
    enum AuthStep { case enterEmail, enterCode, setupProfile }
    
    // MARK: Private Engine Core
    private var webSocket: URLSessionWebSocketTask?
    private let serviceType = "hq-mesh-v1"
    private var myPeerID: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!
    
    private var heartbeatTimer: Timer?
    private var uptimeTimer: Timer?
    private let serverURL = "wss://elevation-strength-authentic.ngrok-free.dev/ws"

    override init() {
        super.init()
        bootstrapSystem()
    }
    
    // MARK: - System Initialization
    private func bootstrapSystem() {
        print("[HQ CORE] Инициализация систем Империи...")
        loadPersistentData()
        setupMeshProtocol()
        if hasAccess {
            connectToCentralHQ()
            startTelemetry()
        }
    }

    // MARK: - Auth Flow (Server Communication)
    func requestEmailCode(email: String) {
        guard isValidEmail(email) else {
            self.authError = "Некорректный формат почты"; return
        }
        isWaitingForServer = true
        sendWSMessage(["type": "request_code", "email": email])
    }
    
    func registerUser(email: String, code: String, username: String, nickname: String) {
        isWaitingForServer = true
        sendWSMessage([
            "type": "verify_and_register",
            "email": email, "code": code,
            "username": username, "nickname": nickname,
            "hq_id": myHQID
        ])
    }

    // MARK: - Central Server Logic (WebSockets)
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
                self.recordTelemetry(received: true, bytes: 256) // Примерный вес пакета
                if case .string(let text) = msg { self.processIncomingData(text) }
                self.listenToWebSocket()
                DispatchQueue.main.async { self.connectionState = .connected }
            case .failure(let error):
                print("[HQ CORE] Разрыв соединения: \(error.localizedDescription)")
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
                if json["success"] as? Bool == true { self.authStep = .enterCode }
                else { self.authError = "Сбой сервера. Письмо не отправлено." }
            case "auth_success":
                self.finalizeRegistration()
            case "auth_error":
                self.authError = json["text"] as? String ?? "Критическая ошибка верификации"
            case "msg":
                self.handleIncomingMessage(json)
            default: break
            }
        }
    }

    // MARK: - P2P & Global Messaging Engine
    func sendMessage(to targetID: String, text: String) {
        let payload: [String: Any] = ["type": "private_msg", "to_id": targetID, "text": text]
        let packetSize = text.count * 2 + 128
        
        // 1. Попытка отправки через глобальный сервер
        if connectionState == .connected {
            sendWSMessage(payload)
            recordTelemetry(received: false, bytes: packetSize)
        }
        
        // 2. Параллельная маршрутизация через локальный Mesh (Bluetooth/Wi-Fi)
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            do {
                try session.send(data, toPeers: session.connectedPeers, with: .reliable)
                recordTelemetry(received: false, bytes: packetSize)
            } catch {
                print("[HQ MESH] Ошибка доставки локального пакета: \(error)")
            }
        }
        
        // 3. Сохранение в UI
        DispatchQueue.main.async {
            let newMsg = ChatMessage(text: text, isMe: true, partnerId: targetID, timestamp: Date())
            self.messages.append(newMsg)
            self.updateContactTop(id: targetID, name: targetID)
        }
    }

    private func handleIncomingMessage(_ json: [String: Any]) {
        guard let senderId = json["from_id"] as? String, let msgText = json["text"] as? String else { return }
        
        // [APPLE STORE RULE]: Жесткая фильтрация черного списка
        if blockedUsers.contains(senderId) {
            print("[HQ MODERATION] Пакет от заблокированного узла \(senderId) уничтожен.")
            return 
        }
        
        let newMsg = ChatMessage(text: msgText, isMe: false, partnerId: senderId, timestamp: Date())
        self.messages.append(newMsg)
        self.updateContactTop(id: senderId, name: "Node \(senderId.prefix(4))")
        
        // Тактильный и звуковой отклик
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    private func updateContactTop(id: String, name: String) {
        if let index = contacts.firstIndex(where: { $0.hqId == id }) {
            contacts[index].lastMessageDate = Date()
            // Поднимаем контакт наверх
            let moved = contacts.remove(at: index)
            contacts.insert(moved, at: 0)
        } else {
            contacts.insert(Contact(hqId: id, name: name, lastMessageDate: Date()), at: 0)
        }
    }

    // MARK: - Moderation & Safety (App Store Must-Haves)
    func blockNode(_ id: String) {
        DispatchQueue.main.async {
            if !self.blockedUsers.contains(id) {
                self.blockedUsers.append(id)
                UserDefaults.standard.set(self.blockedUsers, forKey: "blockedUsers")
                // Зачистка следов заблокированного узла
                self.contacts.removeAll { $0.hqId == id }
                self.messages.removeAll { $0.partnerId == id }
                print("[HQ MODERATION] Узел \(id) заблокирован. Данные стерты.")
            }
        }
    }

    // MARK: - Low-Level Network Helpers
    private func sendWSMessage(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let string = String(data: data, encoding: .utf8) else { return }
        webSocket?.send(.string(string)) { error in
            if let e = error { print("[HQ CORE] Ошибка WebSocket: \(e)") }
        }
    }

    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: true) { [weak self] _ in
            self?.webSocket?.sendPing { error in
                if error != nil { self?.scheduleSecureReconnect() }
            }
        }
    }

    private func scheduleSecureReconnect() {
        heartbeatTimer?.invalidate()
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) { [weak self] in
            if self?.hasAccess == true { self?.connectToCentralHQ() }
        }
    }

    // MARK: - Telemetry & Analytics
    private func startTelemetry() {
        uptimeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.sessionUptime += 1
        }
    }
    
    private func recordTelemetry(received: Bool, bytes: Int) {
        DispatchQueue.main.async {
            if received { self.bytesReceived += Int64(bytes) }
            else { self.bytesSent += Int64(bytes) }
        }
    }

    // MARK: - Data Persistence Engine
    private func finalizeRegistration() {
        self.hasAccess = true
        UserDefaults.standard.set(true, forKey: "isRegistered")
        UserDefaults.standard.set(self.myUsername, forKey: "myUsername")
        UserDefaults.standard.set(self.myNickname, forKey: "myNickname")
        startTelemetry()
    }

    func destructEmpireNode() {
        let keys = ["isRegistered", "myHQID", "myUsername", "myNickname", "blockedUsers"]
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        
        self.hasAccess = false
        self.authStep = .enterEmail
        self.messages.removeAll()
        self.contacts.removeAll()
        self.blockedUsers.removeAll()
        self.bytesSent = 0
        self.bytesReceived = 0
        
        webSocket?.cancel(with: .goingAway, reason: nil)
        heartbeatTimer?.invalidate()
        uptimeTimer?.invalidate()
        
        loadPersistentData() // Генерация нового чистого ID
    }

    private func loadPersistentData() {
        self.hasAccess = UserDefaults.standard.bool(forKey: "isRegistered")
        self.myUsername = UserDefaults.standard.string(forKey: "myUsername") ?? ""
        self.myNickname = UserDefaults.standard.string(forKey: "myNickname") ?? ""
        self.blockedUsers = UserDefaults.standard.stringArray(forKey: "blockedUsers") ?? []
        
        if let savedID = UserDefaults.standard.string(forKey: "myHQID") {
            self.myHQID = savedID
        } else {
            let newID = generateCryptographicNodeID()
            UserDefaults.standard.set(newID, forKey: "myHQID")
            self.myHQID = newID
        }
    }
    
    private func generateCryptographicNodeID() -> String {
        let uuid = UUID().uuidString
        let hash = SHA256.hash(data: Data(uuid.utf8))
        let compactHash = hash.compactMap { String(format: "%02x", $0) }.joined().prefix(6).uppercased()
        return "HQ-\(compactHash)"
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let req = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return NSPredicate(format:"SELF MATCHES %@", req).evaluate(with: email)
    }

    // MARK: - Mesh P2P Engine (Apple MultipeerConnectivity)
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
        
        print("[HQ MESH] Радиомолчание нарушено. Узел \(myHQID) начал вещание.")
    }
}

// MARK: - Mesh Protocol Delegates
extension MeshNetworkManager: MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        print("[HQ MESH] Входящий P2P запрос от \(peerID.displayName)")
        invitationHandler(true, session)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        print("[HQ MESH] Обнаружен узел \(peerID.displayName). Инициирую рукопожатие.")
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 15)
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.nearbyNodes = session.connectedPeers.map { $0.displayName }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        self.recordTelemetry(received: true, bytes: data.count)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["text"] as? String else { return }
        
        DispatchQueue.main.async {
            if self.blockedUsers.contains(peerID.displayName) { return }
            let newMsg = ChatMessage(text: text, isMe: false, partnerId: peerID.displayName, timestamp: Date())
            self.messages.append(newMsg)
            self.updateContactTop(id: peerID.displayName, name: "Node \(peerID.displayName.prefix(4))")
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {}
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {}
}
