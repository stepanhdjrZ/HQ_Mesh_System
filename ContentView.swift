import SwiftUI
import MultipeerConnectivity

@main
struct MessengerApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let text: String
    let sender: String
}

class MeshManager: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    @Published var messages: [ChatMessage] = []
    var session: MCSession!
    var advertiser: MCNearbyServiceAdvertiser!
    var browser: MCNearbyServiceBrowser!
    let myID = MCPeerID(displayName: "Ghost-\(Int.random(in: 100...999))")
    private var seenIDs = Set<UUID>()

    override init() {
        super.init()
        session = MCSession(peer: myID, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self
        advertiser = MCNearbyServiceAdvertiser(peer: myID, discoveryInfo: nil, serviceType: "hq-mesh")
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        browser = MCNearbyServiceBrowser(peer: myID, serviceType: "hq-mesh")
        browser.delegate = self
        browser.startBrowsingForPeers()
    }

    func send(_ text: String) {
        let msg = ChatMessage(id: UUID(), text: text, sender: myID.displayName)
        self.messages.append(msg)
        seenIDs.insert(msg.id)
        if let data = try? JSONEncoder().encode(msg) {
            try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let msg = try? JSONDecoder().decode(ChatMessage.self, from: data), !seenIDs.contains(msg.id) {
            seenIDs.insert(msg.id)
            DispatchQueue.main.async { self.messages.append(msg) }
            try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
        }
    }

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {}
    func session(_ session: MCSession, didReceive stream: InputStream, withName n: String, fromPeer id: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName n: String, fromPeer id: MCPeerID, with p: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName n: String, fromPeer id: MCPeerID, at l: URL?, withError e: Error?) {}
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer id: MCPeerID, withContext c: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) { invitationHandler(true, session) }
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer id: MCPeerID, withDiscoveryInfo i: [String : String]?) { browser.invitePeer(id, to: session, withContext: nil, timeout: 10) }
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer id: MCPeerID) {}
}

struct ContentView: View {
    @StateObject var mesh = MeshManager()
    @State var text = ""
    var body: some View {
        VStack {
            List(mesh.messages) { m in
                Text("\(m.sender): \(m.text)")
            }
            HStack {
                TextField("...", text: $text).textFieldStyle(.roundedBorder)
                Button("OK") { mesh.send(text); text = "" }
            }.padding()
        }
    }
}
