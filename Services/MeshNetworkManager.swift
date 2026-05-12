import Foundation
import MultipeerConnectivity
import SwiftUI

class MeshNetworkManager: NSObject, ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var messages: [ChatMessage] = []
    @Published var myHQID: String = ""
    @Published var nearbyDevices: [String] = [] // Реальные люди рядом
    
    enum ConnectionState { case disconnected, connecting, connected, meshOnly }
    
    // WebSocket
    private var webSocket: URLSessionWebSocketTask?
    
    // Multipeer (Реальный MESH)
    private let serviceType = "hq-mesh"
    private var myPeerID: MCPeerID!
    private var serviceAdvertiser: MCNearbyServiceAdvertiser!
    private var serviceBrowser: MCNearbyServiceBrowser!
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
        
        serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        serviceAdvertiser.delegate = self
        serviceAdvertiser.startAdvertisingPeer()
        
        serviceBrowser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        serviceBrowser.delegate = self
        serviceBrowser.startBrowsingForPeers()
    }

    func connectToHQ() {
        DispatchQueue.main.async { self.connectionState = .connecting }
        let url = URL(string: "wss://hq-mesh.site/ws")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
        webSocket = URLSession.shared.webSocketTask(with: request)
        webSocket?.resume()
        
        sendWSMessage(["type": "register", "my_id": myHQID])
        listenWS()
    }

    private func listenWS() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let msg):
                if case .string(let text) = msg { self?.parseWS(text) }
                self?.listenWS()
                DispatchQueue.main.async { self?.connectionState = .connected }
            case .failure:
                DispatchQueue.main.async { self?.connectionState = .meshOnly }
                self?.reconnectWS()
            }
        }
    }

    func sendMessage(to targetID: String, text: String) {
        let payload: [String: Any] = ["type": "private_msg", "to_id": targetID, "text": text]
        
        // 1. Пробуем через сервер
        if connectionState == .connected {
            sendWSMessage(payload)
        } 
        
        // 2. Дублируем в MESH (Bluetooth) для надежности
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
        }
        
        DispatchQueue.main.async {
            self.messages.append(ChatMessage(text: text, isMe: true, partnerId: targetID, timestamp: Date()))
        }
    }
    
    private func sendWSMessage(_ dict: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: dict),
           let string = String(data: data, encoding: .utf8) {
            webSocket?.send(.string(string)) { _ in }
        }
    }
    
    private func reconnectWS() {
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) { self.connectToHQ() }
    }
    
    private func loadData() {
        if let savedID = UserDefaults.standard.string(forKey: "myHQID") {
            self.myHQID = savedID
        } else {
            let newID = "HQ-\(UUID().uuidString.prefix(5))"
            UserDefaults.standard.set(newID, forKey: "myHQID")
            self.myHQID = newID
        }
    }
}

// Делегаты для MESH (Bluetooth/Wi-Fi)
extension MeshNetworkManager: MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.nearbyDevices = session.connectedPeers.map { $0.displayName }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = json["text"] as? String {
            DispatchQueue.main.async {
                self.messages.append(ChatMessage(text: text, isMe: false, partnerId: peerID.displayName, timestamp: Date()))
            }
        }
    }
    
    // Пустые обязательные методы
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {}
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {}
}
