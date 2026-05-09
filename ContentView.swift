import SwiftUI
import MultipeerConnectivity

@main
struct MessengerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ChatMessage: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let senderID: String
    let isMe: Bool
}

class MeshManager: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    @Published var messages: [ChatMessage] = []
    @Published var nodeCount: Int = 0
    
    var session: MCSession!
    var advertiser: MCNearbyServiceAdvertiser!
    var browser: MCNearbyServiceBrowser!
    
    let myGhostID = "Ghost-\(Int.random(in: 100...999))"
    private var processedIDs = Set<UUID>()

    override init() {
        super.init()
        let peerID = MCPeerID(displayName: myGhostID)
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self
        
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: "hq-mesh")
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: "hq-mesh")
        browser.delegate = self
        browser.startBrowsingForPeers()
    }

    func send(_ text: String) {
        let msg = ChatMessage(id: UUID(), text: text, senderID: myGhostID, isMe: true)
        DispatchQueue.main.async { withAnimation { self.messages.append(msg) } }
        processedIDs.insert(msg.id)
        if let data = try? JSONEncoder().encode(msg) {
            try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let msg = try? JSONDecoder().decode(ChatMessage.self, from: data) {
            if !processedIDs.contains(msg.id) {
                processedIDs.insert(msg.id)
                DispatchQueue.main.async {
                    withAnimation { self.messages.append(ChatMessage(id: msg.id, text: msg.text, senderID: msg.senderID, isMe: false)) }
                }
                try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
            }
        }
    }

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { self.nodeCount = session.connectedPeers.count }
    }
    func session(_ session: MCSession, didReceive stream: InputStream, withName name: String, fromPeer id: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName name: String, fromPeer id: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName name: String, fromPeer id: MCPeerID, at url: URL?, withError err: Error?) {}
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer id: MCPeerID, withContext ctx: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) { invitationHandler(true, session) }
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer id: MCPeerID, withDiscoveryInfo info: [String : String]?) { browser.invitePeer(id, to: session, withContext: nil, timeout: 10) }
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer id: MCPeerID) {}
}

struct ContentView: View {
    @StateObject var mesh = MeshManager()
    @State var text = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 15) {
                        ForEach(mesh.messages) { msg in
                            HStack(alignment: .bottom) {
                                if !msg.isMe {
                                    Circle().fill(Color.orange).frame(width: 30, height: 30)
20:05
.overlay(Text(String(msg.senderID.suffix(2))).font(.system(size: 10)).foregroundColor(.white))
                                } else { Spacer() }
                                
                                Text(msg.text)
                                    .padding(10)
                                    .background(msg.isMe ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(msg.isMe ? .white : .primary)
                                    .cornerRadius(15)
                                
                                if !msg.isMe { Spacer() }
                            }
                        }
                    }.padding()
                }.background(Color(UIColor.systemGroupedBackground))
                
                HStack {
                    TextField("Сообщение...", text: $text)
                        .textFieldStyle(.roundedBorder)
                    Button("ОК") {
                        if !text.isEmpty { mesh.send(text); text = "" }
                    }
                }.padding()
            }
            .navigationBarTitle("HQ Mesh", displayMode: .inline)
            .navigationBarItems(trailing: Text("Узлов: \(mesh.nodeCount)").font(.caption))
        }
    }
}
