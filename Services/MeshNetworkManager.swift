import Foundation
import MultipeerConnectivity
import SwiftUI

class MeshNetworkManager: NSObject, ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var messages: [ChatMessage] = []
    @Published var myHQID: String = ""
    @Published var nearbyNodes: Int = 0 // Сколько людей рядом по Bluetooth
    
    enum ConnectionState { case disconnected, connecting, connected, meshOnly }
    
    private var webSocket: URLSessionWebSocketTask?
    
    // MESH CORE (Apple Multipeer Connectivity)
    private let serviceType = "hq-mesh"
    private var myPeerID: MCPeerID!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!
    private var session: MCSession!

    override init() {
        super.init()
        loadData()
        setupMesh() // Запускаем Bluetooth-поиск
        connectToHQ() // Запускаем связь с Ryzen
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
        let url = URL(string: "wss://hq-mesh.site/ws")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
        webSocket = URLSession.shared.webSocketTask(with: request)
        webSocket?.resume()
        
        // Отправляем пакет регистрации
        sendJSON(["type": "register", "my_id": myHQID])
        listenWS()
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

    func sendMessage(to targetID: String, text: String) {
        let payload: [String: Any] = ["type": "private_msg", "to_id": targetID, "text": text]
        
        // 1. Пытаемся через Ryzen (Интернет)
        sendJSON(payload)
        
        // 2. Дублируем через Mesh (Bluetooth) для всех вокруг
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
        }
        
        DispatchQueue.main.async {
            self.messages.append(ChatMessage(text: text, isMe: true, partnerId: targetID, timestamp: Date()))
        }
    }
    
    private func sendJSON(_ dict: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: dict),
           let string = String(data: data, encoding: .utf8) {
            webSocket?.send(.string(string)) { _ in }
        }
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

// Код для работы Bluetooth Mesh
extension MeshNetworkManager: MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { self.nearbyNodes = session.connectedPeers.count }
    }
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Логика получения сообщения через Mesh...
    }
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {}
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {}
}
