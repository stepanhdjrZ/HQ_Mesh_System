import Foundation
import MultipeerConnectivity
import SwiftUI

class MeshNetworkManager: NSObject, ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var messages: [ChatMessage] = []
    @Published var contacts: [Contact] = []
    @Published var nearbyNodes: [String] = []
    @Published var myHQID: String = ""
    @Published var myUsername: String = ""
    @Published var myNickname: String = ""
    @Published var hasAccess = false
    
    // Состояния для процесса регистрации
    @Published var authStep: AuthStep = .enterEmail
    @Published var isWaitingForServer = false
    @Published var authError = ""

    enum ConnectionState { case disconnected, connecting, connected, meshOnly }
    enum AuthStep { case enterEmail, enterCode, setupProfile }
    
    private var webSocket: URLSessionWebSocketTask?
    private let serviceType = "hq-global-mesh"
    private var myPeerID: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!

    override init() {
        super.init()
        loadData()
        setupMesh()
        connectToHQ()
    }

    // --- АВТОРИЗАЦИЯ ЧЕРЕЗ РЕАЛЬНЫЙ СЕРВЕР ---
    
    func requestEmailCode(email: String) {
        isWaitingForServer = true
        sendJSON(["type": "request_code", "email": email])
    }
    
    func registerUser(email: String, code: String, username: String, nickname: String) {
        isWaitingForServer = true
        sendJSON([
            "type": "verify_and_register",
            "email": email,
            "code": code,
            "username": username,
            "nickname": nickname,
            "hq_id": myHQID
        ])
    }

    // --- СЕТЕВАЯ ЛОГИКА ---

    func connectToHQ() {
        let url = URL(string: "wss://elevation-strength-authentic.ngrok-free.dev/ws")!
        webSocket = URLSession.shared.webSocketTask(with: url)
        webSocket?.resume()
        listenWS()
        
        if hasAccess {
            sendJSON(["type": "register", "my_id": myHQID])
        }
    }

    private func listenWS() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let msg):
                if case .string(let text) = msg { self?.handleServerResponse(text) }
                self?.listenWS()
                DispatchQueue.main.async { self?.connectionState = .connected }
            case .failure:
                DispatchQueue.main.async { self?.connectionState = .meshOnly }
                self.reconnect()
            }
        }
    }

    private func handleServerResponse(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        
        DispatchQueue.main.async {
            self.isWaitingForServer = false
            let type = json["type"] as? String
            
            if type == "code_response" {
                if json["success"] as? Bool == true { self.authStep = .enterCode }
                else { self.authError = "Ошибка отправки письма." }
            } 
            else if type == "auth_success" {
                self.hasAccess = true
                UserDefaults.standard.set(true, forKey: "isRegistered")
                // Сохраняем профиль локально
                UserDefaults.standard.set(self.myUsername, forKey: "myUsername")
                UserDefaults.standard.set(self.myNickname, forKey: "myNickname")
            }
            else if type == "auth_error" {
                self.authError = json["text"] as? String ?? "Ошибка"
            }
            else if type == "msg" {
                self.parseMessage(json)
            }
        }
    }

    // --- MESH & MESSAGING ---

    func sendMessage(to targetID: String, text: String) {
        let payload: [String: Any] = ["type": "private_msg", "to_id": targetID, "text": text]
        sendJSON(payload)
        
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
        }
        
        messages.append(ChatMessage(text: text, isMe: true, partnerId: targetID, timestamp: Date()))
    }

    private func sendJSON(_ dict: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: dict),
           let string = String(data: data, encoding: .utf8) {
            webSocket?.send(.string(string)) { _ in }
        }
    }

    private func setupMesh() {
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

    private func parseMessage(_ json: [String: Any]) {
        if let senderId = json["from_id"] as? String, let msgText = json["text"] as? String {
            self.messages.append(ChatMessage(text: msgText, isMe: false, partnerId: senderId, timestamp: Date()))
            if !contacts.contains(where: { $0.hqId == senderId }) {
                contacts.append(Contact(hqId: senderId, name: "Node \(senderId.prefix(4))", lastMessageDate: Date()))
            }
        }
    }

    private func reconnect() {
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) { self.connectToHQ() }
    }
    
    private func loadData() {
        self.hasAccess = UserDefaults.standard.bool(forKey: "isRegistered")
        self.myUsername = UserDefaults.standard.string(forKey: "myUsername") ?? ""
        self.myNickname = UserDefaults.standard.string(forKey: "myNickname") ?? ""
        
        if let savedID = UserDefaults.standard.string(forKey: "myHQID") { self.myHQID = savedID }
        else {
            let newID = "HQ-\(UUID().uuidString.prefix(5))"
            UserDefaults.standard.set(newID, forKey: "myHQID")
            self.myHQID = newID
        }
    }
}

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
