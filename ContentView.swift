import SwiftUI
import MultipeerConnectivity

@main
struct MessengerApp: App {
    var body: some Scene {
        WindowGroup { MainCoordinator() }
    }
}

// MARK: - МОДЕЛИ
struct Message: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let senderID: String
    let recipientID: String?
    let isMe: Bool
    let viaServer: Bool
}

// Пакеты для сервера
struct ServerPacket: Codable {
    let type: String
    let payload: [Message]?
    let version: String?
}

// MARK: - ГИБРИДНОЕ ЯДРО
class GlobalCore: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    @Published var groupMessages: [Message] = []
    @Published var peers: [MCPeerID] = []
    @Published var myName: String = UserDefaults.standard.string(forKey: "user_name") ?? ""
    @Published var isServerConnected: Bool = false
    @Published var showUpdateAlert = false
    @Published var serverVersion = ""
    
    let currentAppVersion = "6.1"
    var session: MCSession!
    var advertiser: MCNearbyServiceAdvertiser!
    var browser: MCNearbyServiceBrowser!
    var myPeerID: MCPeerID!
    var webSocketTask: URLSessionWebSocketTask?
    
    let historyURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("history.json")

    override init() {
        super.init()
        loadLocalHistory()
    }

    func start(name: String) {
        self.myName = name
        UserDefaults.standard.set(name, forKey: "user_name")
        myPeerID = MCPeerID(displayName: name)
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: "hq-mesh")
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: "hq-mesh")
        browser.delegate = self
        browser.startBrowsingForPeers()
        connectToServer()
    }

    func saveLocally() {
        if let data = try? JSONEncoder().encode(groupMessages) {
            try? data.write(to: historyURL)
        }
    }

    func loadLocalHistory() {
        if let data = try? Data(contentsOf: historyURL),
           let decoded = try? JSONDecoder().decode([Message].self, from: data) {
            self.groupMessages = decoded
        }
    }

    func connectToServer() {
        // ВАЖНО: Замени на свой адрес NGROK (с https://), когда запустишь его!
        guard let url = URL(string: "ws://192.168.0.55:8080") else { return }
        webSocketTask = URLSession.shared.webSocketTask(with: url)
        webSocketTask?.resume()
        receiveFromServer()
    }

    func send(text: String) {
        let msg = Message(id: UUID(), text: text, senderID: myName, recipientID: nil, isMe: true, viaServer: false)
        DispatchQueue.main.async {
            self.groupMessages.append(msg)
            self.saveLocally()
        }
        if let data = try? JSONEncoder().encode(msg) {
            if !session.connectedPeers.isEmpty { try? session.send(data, toPeers: session.connectedPeers, with: .reliable) }
            if isServerConnected { webSocketTask?.send(.string(String(data: data, encoding: .utf8) ?? "")) { _ in } }
        }
    }

    func receiveFromServer() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            if case .success(let message) = result, case .string(let text) = message,
               let data = text.data(using: .utf8) {
                
                if let packet = try? JSONDecoder().decode(ServerPacket.self, from: data) {
                    DispatchQueue.main.async {
                        if packet.type == "version_check", let v = packet.version, v != self.currentAppVersion {
                            self.serverVersion = v
                            self.showUpdateAlert = true
                        } else if packet.type == "history", let payload = packet.payload {
                            let newMsgs = payload.filter { p in !self.groupMessages.contains(where: { $0.id == p.id }) }
                            self.groupMessages.append(contentsOf: newMsgs.map { 
                                Message(id: $0.id, text: $0.text, senderID: $0.senderID, recipientID: $0.recipientID, isMe: $0.senderID == self.myName, viaServer: true)
                            })
                        }
                        self.saveLocally()
                    }
                }
            }
            self.receiveFromServer()
        }
    }
    
    func triggerUpdate() {
        // Ссылка на манифест на твоем сервере (через NGROK)
        let urlStr = "itms-services://?action=download-manifest&url=https://ТВОЙ_АДРЕС_NGROK/manifest.plist"
        if let url = URL(string: urlStr) { UIApplication.shared.open(url) }
    }

    // Mesh Handlers
    func session(_ s: MCSession, didReceive d: Data, fromPeer id: MCPeerID) {
        if let msg = try? JSONDecoder().decode(Message.self, from: d) {
            DispatchQueue.main.async {
                self.groupMessages.append(Message(id: msg.id, text: msg.text, senderID: msg.senderID, recipientID: msg.recipientID, isMe: false, viaServer: false))
                self.saveLocally()
            }
        }
    }
    func session(_ s: MCSession, peer id: MCPeerID, didChange st: MCSessionState) { DispatchQueue.main.async { self.peers = s.connectedPeers; self.isServerConnected = true } }
    func advertiser(_ a: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer id: MCPeerID, withContext c: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) { invitationHandler(true, session) }
    func browser(_ b: MCNearbyServiceBrowser, foundPeer id: MCPeerID, withDiscoveryInfo i: [String : String]?) { b.invitePeer(id, to: session, withContext: nil, timeout: 10) }
    func browser(_ b: MCNearbyServiceBrowser, lostPeer id: MCPeerID) {}
    func session(_ s: MCSession, didReceive stream: InputStream, withName n: String, fromPeer id: MCPeerID) {}
    func session(_ s: MCSession, didStartReceivingResourceWithName n: String, fromPeer id: MCPeerID, with p: Progress) {}
    func session(_ s: MCSession, didFinishReceivingResourceWithName n: String, fromPeer id: MCPeerID, at l: URL?, withError e: Error?) {}
}

// MARK: - UI
struct MainCoordinator: View {
    @StateObject var core = GlobalCore()
    var body: some View {
        NavigationView {
            if core.myName.isEmpty { RegistrationView(core: core) }
            else {
                ChatView(core: core)
                    .alert("Доступно обновление v\(core.serverVersion)", isPresented: $core.showUpdateAlert) {
                        Button("Обновить") { core.triggerUpdate() }
                        Button("Позже", role: .cancel) {}
                    } message: { Text("Новая версия уже на твоем Ryzen. Ставим?") }
            }
        }.navigationViewStyle(.stack)
    }
}

struct ChatView: View {
    @ObservedObject var core: GlobalCore
    @State var text = ""
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Circle().fill(core.isServerConnected ? Color.blue : Color.red).frame(width: 8, height: 8)
                Text(core.isServerConnected ? "HQ Ryzen Online" : "Mesh Mode").font(.caption)
                Spacer()
                Text("Узлов: \(core.peers.count)").font(.caption)
            }.padding().background(Color(.secondarySystemBackground))

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(core.groupMessages) { msg in
                            HStack {
                                if msg.isMe { Spacer() }
                                VStack(alignment: msg.isMe ? .trailing : .leading) {
                                    Text(msg.senderID).font(.caption2).foregroundColor(.gray)
                                    Text(msg.text).padding(12).background(msg.isMe ? Color.blue : Color(.systemGray5))
                                        .foregroundColor(msg.isMe ? .white : .primary).cornerRadius(16)
                                }
                                if !msg.isMe { Spacer() }
                            }.id(msg.id)
                        }
                    }.padding()
                }
                .onChange(of: core.groupMessages.count) { _ in proxy.scrollTo(core.groupMessages.last?.id) }
            }
            
            HStack {
                TextField("Сообщение...", text: $text).padding(10).background(Color(.systemGray6)).cornerRadius(20)
                Button(action: { core.send(text: text); text = "" }) {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 32))
                }.disabled(text.isEmpty)
            }.padding()
        }
        .navigationTitle("HQ Global")
        .onAppear { core.start(name: core.myName) }
    }
}

struct RegistrationView: View {
    @ObservedObject var core: GlobalCore
    @State var name = ""
    var body: some View {
        VStack(spacing: 20) {
            Text("🛰").font(.system(size: 80))
            TextField("Никнейм", text: $name).padding().background(Color(.systemGray6)).cornerRadius(12).padding()
            Button("Начать") { core.start(name: name) }.buttonStyle(.borderedProminent)
        }
    }
}
