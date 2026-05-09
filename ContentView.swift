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
    let isMe: Bool
}

struct ServerPacket: Codable {
    let type: String
    let version: String?
    let payload: [Message]?
}

// MARK: - ЯДРО С ПОДДЕРЖКОЙ ОБНОВЛЕНИЙ
class GlobalCore: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    @Published var messages: [Message] = []
    @Published var peers: Int = 0
    @Published var isServerConnected = false
    @Published var myName = UserDefaults.standard.string(forKey: "user_name") ?? ""
    
    // OTA Данные
    @Published var showUpdateAlert = false
    @Published var newVersion = ""
    let currentVersion = "6.5"
    
    // Адрес твоего сервера (СЮДА ПИШЕМ АДРЕС ИЗ NGROK)
    let serverHost = "ТВОЙ_АДРЕС_ИЗ_NGROK.ngrok-free.app"
    
    var session: MCSession!
    var webSocketTask: URLSessionWebSocketTask?

    func start(name: String) {
        self.myName = name
        UserDefaults.standard.set(name, forKey: "user_name")
        let peerID = MCPeerID(displayName: name)
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self
        
        let adv = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: "hq-mesh")
        adv.delegate = self
        adv.startAdvertisingPeer()
        
        let browser = MCNearbyServiceBrowser(peer: peerID, serviceType: "hq-mesh")
        browser.delegate = self
        browser.startBrowsingForPeers()
        
        connectToServer()
    }

    func connectToServer() {
        guard let url = URL(string: "wss://\(serverHost)/ws") else { return }
        webSocketTask = URLSession.shared.webSocketTask(with: url)
        webSocketTask?.resume()
        receiveFromServer()
    }

    func receiveFromServer() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self, case .success(let msg) = result, case .string(let text) = msg else { return }
            if let data = text.data(using: .utf8), let packet = try? JSONDecoder().decode(ServerPacket.self, from: data) {
                DispatchQueue.main.async {
                    if packet.type == "version_check", let v = packet.version, v != self.currentVersion {
                        self.newVersion = v
                        self.showUpdateAlert = true
                    }
                }
            }
            self.receiveFromServer()
        }
    }

    func triggerUpdate() {
        let manifestURL = "itms-services://?action=download-manifest&url=https://\(serverHost)/manifest.plist"
        if let url = URL(string: manifestURL) {
            UIApplication.shared.open(url)
        }
    }

    // Остальные методы (Mesh)
    func send(_ text: String) {
        let msg = Message(id: UUID(), text: text, senderID: myName, isMe: true)
        self.messages.append(msg)
        if let data = try? JSONEncoder().encode(msg) {
            try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
            webSocketTask?.send(.string(String(data: data, encoding: .utf8) ?? "")) { _ in }
        }
    }
    
    func session(_ s: MCSession, didReceive d: Data, fromPeer id: MCPeerID) {
        if let msg = try? JSONDecoder().decode(Message.self, from: d) {
            DispatchQueue.main.async { self.messages.append(Message(id: msg.id, text: msg.text, senderID: msg.senderID, isMe: false)) }
        }
    }
    func session(_ s: MCSession, peer id: MCPeerID, didChange st: MCSessionState) { DispatchQueue.main.async { self.peers = s.connectedPeers.count; self.isServerConnected = true } }
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
            if core.myName.isEmpty { RegistrationView(core: core) }
            else {
                ChatView(core: core)
                    .alert("Доступна версия \(core.newVersion)", isPresented: $core.showUpdateAlert) {
                        Button("Обновить по воздуху") { core.triggerUpdate() }
                        Button("Позже", role: .cancel) {}
                    }
            }
        }.navigationViewStyle(.stack)
    }
}

struct ChatView: View {
    @ObservedObject var core: GlobalCore
    @State var text = ""
    var body: some View {
        VStack {
            ScrollView {
                VStack {
                    ForEach(core.messages) { msg in
                        HStack {
                            if msg.isMe { Spacer() }
                            Text(msg.text).padding().background(msg.isMe ? Color.blue : Color.gray.opacity(0.2)).cornerRadius(15).foregroundColor(msg.isMe ? .white : .primary)
                            if !msg.isMe { Spacer() }
                        }
                    }
                }.padding()
            }
            HStack {
                TextField("Текст...", text: $text).padding().background(Color.gray.opacity(0.1)).cornerRadius(10)
                Button("Отправить") { core.send(text); text = "" }
            }.padding()
        }
        .navigationTitle("HQ OTA Test")
        .onAppear { core.start(name: core.myName) }
    }
}

struct RegistrationView: View {
    @ObservedObject var core: GlobalCore
    @State var name = ""
    var body: some View {
        VStack {
            TextField("Твой ник", text: $name).padding().background(Color.gray.opacity(0.1)).cornerRadius(10).padding()
            Button("Войти") { core.start(name: name) }.buttonStyle(.borderedProminent)
        }
    }
}
