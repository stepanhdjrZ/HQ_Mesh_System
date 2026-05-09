import SwiftUI
@preconcurrency import MultipeerConnectivity

class MeshManager: NSObject, ObservableObject {
    @Published var messages: [String] = ["Штаб на связи..."]
    
    var peerID: MCPeerID
    var session: MCSession?
    var advertiser: MCNearbyServiceAdvertiser?
    var browser: MCNearbyServiceBrowser?
    
    override init() {
        // Жестко задаем имя, чтобы Xcode не ругался на доступ к настройкам телефона
        self.peerID = MCPeerID(displayName: "iPhone_User")
        super.init()
        
        self.session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .none)
        self.session?.delegate = self
        
        self.advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: "hq-mesh")
        self.advertiser?.delegate = self
        self.advertiser?.startAdvertisingPeer()
        
        self.browser = MCNearbyServiceBrowser(peer: peerID, serviceType: "hq-mesh")
        self.browser?.delegate = self
        self.browser?.startBrowsingForPeers()
    }
    
    func send(_ message: String) {
        let data = Data("СООБЩЕНИЕ: \(message)".utf8)
        if let session = session, !session.connectedPeers.isEmpty {
            try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
        }
        DispatchQueue.main.async {
            self.messages.append("Вы: \(message)")
        }
    }
}

// Отдельный блок для приема связи
extension MeshManager: @preconcurrency MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {}
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let msg = String(data: data, encoding: .utf8) {
            DispatchQueue.main.async {
                self.messages.append(msg)
            }
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// Отдельный блок для рекламы устройства в сети
extension MeshManager: @preconcurrency MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, self.session)
    }
}

// Отдельный блок для поиска ПК
extension MeshManager: @preconcurrency MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        if let session = self.session {
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
        }
    }
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}

// Визуальная часть (Интерфейс)
struct ContentView: View {
    @StateObject var mesh = MeshManager()
    @State var text = ""
    
    var body: some View {
        VStack {
            List(mesh.messages, id: \.self) { Text($0) }
            HStack {
                TextField("Сообщение", text: $text)
                    .textFieldStyle(.roundedBorder)
                Button("Отправить") {
                    mesh.send(text)
                    text = ""
                }
            }
            .padding()
        }
    }
}
