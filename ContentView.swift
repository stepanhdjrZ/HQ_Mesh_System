import SwiftUI
import MultipeerConnectivity

@main
struct MessengerApp: App {
    var body: some Scene {
        WindowGroup { MainCoordinator() }
    }
}

struct AppConfig {
    static let host = "elevation-strength-authentic.ngrok-free.dev"
    static let version = "6.6"
}

struct Message: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let senderID: String
    let isMe: Bool
}

struct ServerPacket: Codable {
    let type: String
    let version: String?
    let payload: [Message]?
}

class GlobalCore: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    @Published var messages: [Message] = []
    @Published var peers = 0
    @Published var isOnline = false
    @Published var showUpdate = false
    @Published var serverV = ""
    @Published var name = UserDefaults.standard.string(forKey: "u_name") ?? ""
    
    var session: MCSession!
    var ws: URLSessionWebSocketTask?

    func setup(userName: String) {
        self.name = userName
        UserDefaults.standard.set(userName, forKey: "u_name")
        let pid = MCPeerID(displayName: userName)
        session = MCSession(peer: pid, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self
        
        let adv = MCNearbyServiceAdvertiser(peer: pid, discoveryInfo: nil, serviceType: "hq-mesh")
        adv.delegate = self
        adv.startAdvertisingPeer()
        
        let browser = MCNearbyServiceBrowser(peer: pid, serviceType: "hq-mesh")
        browser.delegate = self
        browser.startBrowsingForPeers()
        
        connect()
    }

    func connect() {
        guard let url = URL(string: "wss://\(AppConfig.host)/ws") else { return }
        ws = URLSession.shared.webSocketTask(with: url)
        ws?.resume()
        listen()
    }

    func listen() {
        ws?.receive { [weak self] res in
            guard let self = self, case .success(let msg) = res, case .string(let str) = msg,
                  let data = str.data(using: .utf8),
                  let packet = try? JSONDecoder().decode(ServerPacket.self, from: data) else {
                self?.listen()
                return
            }
            
            DispatchQueue.main.async {
                if packet.type == "version_check", let v = packet.version, v != AppConfig.version {
                    self.serverV = v
                    self.showUpdate = true
                } else if packet.type == "msg", let p = packet.payload {
                    self.messages.append(contentsOf: p.filter { m in !self.messages.contains(where: { $0.id == m.id }) })
                }
            }
            self.listen()
        }
    }

    func update() {
        let url = "itms-services://?action=download-manifest&url=https://\(AppConfig.host)/manifest.plist"
        if let u = URL(string: url) { UIApplication.shared.open(u) }
    }

    func send(_ txt: String) {
        let m = Message(id: UUID(), text: txt, senderID: name, isMe: true)
        messages.append(m)
        if let d = try? JSONEncoder().encode(m) {
            try? session.send(d, toPeers: session.connectedPeers, with: .reliable)
            ws?.send(.string(String(data: d, encoding: .utf8) ?? "")) { _ in }
        }
    }

    // Mesh
    func session(_ s: MCSession, didReceive d: Data, fromPeer id: MCPeerID) {
        if let m = try? JSONDecoder().decode(Message.self, from: d) {
            DispatchQueue.main.async { self.messages.append(Message(id: m.id, text: m.text, senderID: m.senderID, isMe: false)) }
        }
    }
    func session(_ s: MCSession, peer id: MCPeerID, didChange st: MCSessionState) { DispatchQueue.main.async { self.peers = s.connectedPeers.count; self.isOnline = (st == .connected) } }
    func advertiser(_ a: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer id: MCPeerID, withContext c: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) { invitationHandler(true, session) }
    func browser(_ b: MCNearbyServiceBrowser, foundPeer id: MCPeerID, withDiscoveryInfo i: [String : String]?) { b.invitePeer(id, to: session, withContext: nil, timeout: 10) }
    func browser(_ b: MCNearbyServiceBrowser, lostPeer id: MCPeerID) {}
    func session(_ s: MCSession, didReceive stream: InputStream, withName n: String, fromPeer id: MCPeerID) {}
    func session(_ s: MCSession, didStartReceivingResourceWithName n: String, fromPeer id: MCPeerID, with p: Progress) {}
    func session(_ s: MCSession, didFinishReceivingResourceWithName n: String, fromPeer id: MCPeerID, at l: URL?, withError e: Error?) {}
}

struct MainCoordinator: View {
    @StateObject var core = GlobalCore()
    var body: some View {
        NavigationView {
            if core.name.isEmpty {
                VStack {
                    TextField("Ник", text: $core.name).textFieldStyle(.roundedBorder).padding()
                    Button("Войти") { core.setup(userName: core.name) }.buttonStyle(.borderedProminent)
                }
            } else {
                VStack {
                    HStack {
                        Circle().fill(core.isOnline ? Color.blue : Color.red).frame(width: 10, height: 10)
                        Text(core.isOnline ? "Cloud" : "Mesh").font(.caption)
                        Spacer()
                        Text("Узлов: \(core.peers)").font(.caption)
                    }.padding()
                    
                    ScrollView {
                        VStack {
                            ForEach(core.messages) { m in
                                HStack {
                                    if m.isMe { Spacer() }
                                    Text(m.text).padding(10).background(m.isMe ? Color.blue : Color.gray.opacity(0.2)).cornerRadius(12).foregroundColor(m.isMe ? .white : .primary)
                                    if !m.isMe { Spacer() }
                                }
                            }
                        }.padding()
                    }
                    
                    HStack {
                        TextField("Сообщение...", text: $core.serverV).padding() // Используем поле для текста
                        Button("🚀") { core.send(core.serverV); core.serverV = "" }
                    }.padding()
                }
                .navigationTitle("HQ Mesh")
                .alert("Обнова v\(core.serverV)", isPresented: $core.showUpdate) {
                    Button("Ставим!") { core.update() }
                    Button("Отмена", role: .cancel) {}
                }
            }
        }.onAppear { if !core.name.isEmpty { core.setup(userName: core.name) } }
    }
}
