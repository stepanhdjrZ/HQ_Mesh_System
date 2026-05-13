import Foundation
import MultipeerConnectivity
import SwiftUI
import Combine

final class MeshNetworkManager: NSObject, ObservableObject {
    private let persistence = PersistenceManager()
    @ObservedObject var queue = QueueManager() // Привязываем очередь
    
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
    
    enum ConnectionState { case disconnected, connecting, connected, meshOnly }
    enum MeshAuthStep { case enterEmail, enterCode, setupProfile }
    
    private var webSocket: URLSessionWebSocketTask?
    private var session: MCSession!
    private var myPeerID: MCPeerID!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!
    
    override init() {
        super.init()
        self.setupIdentity()
        self.initMesh()
        if hasAccess { self.connectToHQ() }
    }
    
    private func setupIdentity() {
        self.hasAccess = persistence.fetchBool(forKey: .accessGranted)
        self.myHQID = persistence.fetchString(forKey: .nodeID) ?? ("HQ-" + UUID().uuidString.prefix(8).uppercased())
        persistence.save(self.myHQID, forKey: .nodeID)
        self.myNickname = persistence.fetchString(forKey: .nickname) ?? "Node"
    }

    func connectToHQ() {
        guard let url = URL(string: AppConstants.serverURL) else { return }
        DispatchQueue.main.async { self.connectionState = .connecting }
        
        let request = URLRequest(url: url)
        webSocket = URLSession.shared.webSocketTask(with: request)
        webSocket?.resume()
        
        self.listen()
        
        // Пытаемся протолкнуть очередь, если есть интернет
        self.queue.processQueue { payload in
            self.transmit(payload)
            return true
        }
    }

    func broadcastData(to target: String, content: String) {
        let packet: [String: Any] = [
            "type": "secure_msg",
            "from": myHQID,
            "to": target,
            "body": SecurityEngine.encrypt(content),
            "ts": Date().timeIntervalSince1970
        ]
        
        // 1. Пробуем Mesh (P2P)
        let meshSuccess = sendToMesh(packet)
        
        // 2. Если Mesh не сработал и есть интернет — шлем в Штаб
        if connectionState == .connected {
            transmit(packet)
        } else if !meshSuccess {
            // 3. Если связи нет совсем — в очередь!
            queue.addToQueue(target: target, data: packet)
        }
        
        // UI Update
        let msg = ChatMessage(text: content, isMe: true, partnerId: target, timestamp: Date())
        DispatchQueue.main.async { self.messages.append(msg) }
    }

    private func transmit(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else { return }
        webSocket?.send(.string(str)) { _ in 
            DispatchQueue.main.async { self.statsSent += Int64(str.count) }
        }
    }

    private func listen() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let msg):
                if case .string(let text) = msg { self.handleJSON(text) }
                self.listen()
                DispatchQueue.main.async { self.connectionState = .connected }
            case .failure:
                DispatchQueue.main.async { self.connectionState = .meshOnly }
                DispatchQueue.global().asyncAfter(deadline: .now() + 5) { self.connectToHQ() }
            }
        }
    }

    private func handleJSON(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }
        
        DispatchQueue.main.async {
            if type == "secure_msg" { self.processInbound(json) }
        }
    }

    private func processInbound(_ json: [String: Any]) {
        guard let from = json["from"] as? String, let body = json["body"] as? String else { return }
        let msg = ChatMessage(text: SecurityEngine.decrypt(body), isMe: false, partnerId: from, timestamp: Date())
        self.messages.append(msg)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
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
        do { try session.send(data, toPeers: session.connectedPeers, with: .reliable); return true }
        catch { return false }
    }
}

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
