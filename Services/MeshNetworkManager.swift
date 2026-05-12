import Foundation
import MultipeerConnectivity
import SwiftUI

class MeshNetworkManager: NSObject, ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var messages: [ChatMessage] = []
    @Published var myHQID: String = ""
    @Published var nearbyNodes: Int = 0
    @Published var contacts: [Contact] = []
    
    enum ConnectionState { case disconnected, connecting, connected, meshOnly }
    
    private var webSocket: URLSessionWebSocketTask?
    private let serviceType = "hq-mesh-p2p"
    private var myPeerID: MCPeerID!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!
    private var session: MCSession!

    override init() {
        super.init()
        loadData()
        setupMesh()
        connectToHQ()
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

    func connectToHQ() {
        DispatchQueue.main.async { self.connectionState = .connecting }
        
        // ТВОЯ ССЫЛКА ИЗ NGROK
        let url = URL(string: "wss://elevation-strength-authentic.ngrok-free.dev/ws")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        
        webSocket = URLSession.shared.webSocketTask(with: request)
        webSocket?.resume()
        
        sendJSON(["type": "register", "my_id": myHQID])
        listenWS()
    }

    func sendMessage(to targetID: String, text: String) {
        let payload: [String: Any] = ["type": "private_msg", "to_id": targetID, "text": text]
        sendJSON(payload)
        
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
        }
        
        DispatchQueue.main.async {
            let newMsg = ChatMessage(text: text, isMe: true, partnerId: targetID, timestamp: Date())
            self.messages.append(newMsg)
        }
    }
    
    private func sendJSON(_ dict: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: dict),
           let string = String(data: data, encoding: .utf8) {
            webSocket?.send(.string(string)) { _ in }
        }
    }

    private func listenWS() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let msg):
                if case .string(let text) = msg { self?.parse(text) }
                self?.listenWS()
                DispatchQueue.main.async { self?.connectionState = .connected }
            case .failure:
                DispatchQueue.main.async { self?.connectionState = .meshOnly }
                self?.reconnect()
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
            if !self.contacts.contains(where: { $0.hqId == senderId }) {
                self.contacts.append(Contact(hqId: senderId, name: "Node \(senderId.prefix(4))", lastMessageDate: Date()))
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    func deleteAccountRequest() {
        UserDefaults.standard.removeObject(forKey: "myHQID")
        self.loadData()
    }

    private func reconnect() {
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) { self.connectToHQ() }
    }
    
    private func loadData() {
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
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) { DispatchQueue.main.async { self.nearbyNodes = session.connectedPeers.count } }
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let text = json["text"] as? String {
            DispatchQueue.main.async {
                let newMsg = ChatMessage(text: text, isMe: false, partnerId: peerID.displayName, timestamp: Date())
                self.messages.append(newMsg)
            }
        }
    }
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {}
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {}
}
