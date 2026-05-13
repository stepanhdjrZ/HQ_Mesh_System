import Foundation
import MultipeerConnectivity
import SwiftUI
import UIKit
import CryptoKit

struct ChatMessage: Identifiable, Codable, Hashable {
    var id = UUID()
    let text: String
    let isMe: Bool
    let partnerId: String
    let timestamp: Date
    var timeString: String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return f.string(from: timestamp)
    }
}

struct Contact: Identifiable, Codable, Hashable {
    var id = UUID()
    let hqId: String
    let name: String
    var lastMessageDate: Date
}

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
    @Published var isWaiting = false
    @Published var authError = ""
    
    @Published var bytesSent: Int64 = 0
    @Published var bytesReceived: Int64 = 0

    enum ConnectionState { case disconnected, connecting, connected, meshOnly }
    enum AuthStep { case enterEmail, enterCode, setupProfile }
    
    private var webSocket: URLSessionWebSocketTask?
    private let serviceType = "hq-mesh-v4"
    private var myPeerID: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!
    private var heartbeatTimer: Timer?
    private let serverURL = "wss://elevation-strength-authentic.ngrok-free.dev/ws"

    override init() {
        super.init()
        loadData()
        setupMesh()
        if hasAccess { connectToHQ() }
    }

    func requestEmailCode(email: String) {
        isWaiting = true
        sendJSON(["type": "request_code", "email": email])
    }
    
    func registerUser(email: String, code: String, username: String, nickname: String) {
        isWaiting = true
        sendJSON(["type": "verify_and_register", "email": email, "code": code, "username": username, "nickname": nickname, "hq_id": myHQID])
    }

    func connectToHQ() {
        DispatchQueue.main.async { self.connectionState = .connecting }
        guard let url = URL(string: serverURL) else { return }
        webSocket = URLSession.shared.webSocketTask(with: url)
        webSocket?.resume()
        if hasAccess { sendJSON(["type": "register", "my_id": myHQID]) }
        listenWS()
    }

    private func listenWS() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let msg):
                if case .string(let text) = msg { self.handleServerMsg(text) }
                self.listenWS()
                DispatchQueue.main.async { self.connectionState = .connected }
            case .failure:
                DispatchQueue.main.async { self.connectionState = .meshOnly }
                DispatchQueue.global().asyncAfter(deadline: .now() + 5) { self.connectToHQ() }
            }
        }
    }

    private func handleServerMsg(_ text: String) {
        guard let data = text.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        DispatchQueue.main.async {
            self.isWaiting = false
            let type = json["type"] as? String
            if type == "code_response" { self.authStep = .enterCode }
            else if type == "auth_success" { self.finalizeAuth() }
            else if type == "msg" { self.receiveMsg(json) }
        }
    }

    func sendMessage(to id: String, text: String) {
        let payload: [String: Any] = ["type": "private_msg", "to_id": id, "text": text]
        sendJSON(payload)
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
        }
        DispatchQueue.main.async {
            self.messages.append(ChatMessage(text: text, isMe: true, partnerId: id, timestamp: Date()))
            self.updateContacts(id: id)
        }
    }

    private func receiveMsg(_ json: [String: Any]) {
        guard let from = json["from_id"] as? String, let txt = json["text"] as? String else { return }
        if blockedUsers.contains(from) { return }
        messages.append(ChatMessage(text: txt, isMe: false, partnerId: from, timestamp: Date()))
        updateContacts(id: from)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    func handleQR(_ code: String) {
        if code.hasPrefix("HQ-") {
            updateContacts(id: code)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    private func updateContacts(id: String) {
        if !contacts.contains(where: { $0.hqId == id }) {
            contacts.insert(Contact(hqId: id, name: "Узел " + id.prefix(6), lastMessageDate: Date()), at: 0)
        }
    }

    func block(_ id: String) {
        blockedUsers.append(id)
        UserDefaults.standard.set(blockedUsers, forKey: "blockedUsers")
        contacts.removeAll { $0.hqId == id }
    }

    private func sendJSON(_ dict: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: dict), let str = String(data: data, encoding: .utf8) {
            webSocket?.send(.string(str)) { _ in }
        }
    }

    private func finalizeAuth() {
        hasAccess = true
        UserDefaults.standard.set(true, forKey: "isRegistered")
        UserDefaults.standard.set(myUsername, forKey: "myUsername")
        UserDefaults.standard.set(myNickname, forKey: "myNickname")
    }

    func logout() {
        ["isRegistered", "myHQID", "myUsername", "myNickname"].forEach { UserDefaults.standard.removeObject(forKey: $0) }
        hasAccess = false
        loadData()
    }

    private func loadData() {
        hasAccess = UserDefaults.standard.bool(forKey: "isRegistered")
        myUsername = UserDefaults.standard.string(forKey: "myUsername") ?? ""
        myNickname = UserDefaults.standard.string(forKey: "myNickname") ?? ""
        blockedUsers = UserDefaults.standard.stringArray(forKey: "blockedUsers") ?? []
        if let id = UserDefaults.standard.string(forKey: "myHQID") { myHQID = id }
        else {
            let newID = "HQ-" + UUID().uuidString.prefix(6).uppercased()
            UserDefaults.standard.set(newID, forKey: "myHQID")
            myHQID = newID
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

    private func startHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { _ in
            self.webSocket?.sendPing { _ in }
        }
    }
}

extension MeshNetworkManager: MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) { invitationHandler(true, session) }
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) { browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10) }
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) { DispatchQueue.main.async { self.nearbyNodes = session.connectedPeers.map { $0.displayName } } }
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        DispatchQueue.main.async { self.receiveMsg(json) }
    }
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {}
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {}
}
