import SwiftUI
import MultipeerConnectivity

@MainActor
class MeshManager: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    @Published var messages: [String] = ["Штаб на связи..."]
    
    let peerID = MCPeerID(displayName: UIDevice.current.name)
    var session: MCSession?
    var advertiser: MCNearbyServiceAdvertiser?
    var browser: MCNearbyServiceBrowser?
    
    override init() {
        super.init()
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .none)
        session?.delegate = self
        
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: "hq-mesh")
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: "hq-mesh")
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }
    
    func send(_ message: String) {
        let data = Data("СООБЩЕНИЕ: \(message)".utf8)
        try? session?.send(data, toPeers: session?.connectedPeers ?? [], with: .reliable)
        messages.append("Вы: \(message)")
    }
    
    // MARK: - Delegates
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {}
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let msg = String(data: data, encoding: .utf8) {
            DispatchQueue.main.async { self.messages.append(msg) }
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: (any Error)?) {}

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        browser.invitePeer(peerID, to: session!, withContext: nil, timeout: 10)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}

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
