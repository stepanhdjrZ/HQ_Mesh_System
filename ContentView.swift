import SwiftUI
import MultipeerConnectivity

@main
struct MessengerApp: App {
    var body: some Scene {
        WindowGroup { MainCoordinator() }
    }
}

// MARK: - НАСТРОЙКИ СВЯЗИ
struct AppConfig {
    // ЗАМЕНИ НА СВОЙ ВНЕШНИЙ IP ИЛИ АДРЕС NGROK ДЛЯ СВЯЗИ НА РАССТОЯНИИ
    static let serverURL = "ws://192.168.0.55:8080" 
}

// MARK: - МОДЕЛЬ СООБЩЕНИЯ
struct Message: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let senderID: String
    let recipientID: String?
    let isMe: Bool
    let viaServer: Bool
}

// MARK: - ЯДРО СИСТЕМЫ
class GlobalCore: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    @Published var groupMessages: [Message] = []
    @Published var privateMessages: [String: [Message]] = [:]
    @Published var peers: [MCPeerID] = []
    @Published var myName: String = UserDefaults.standard.string(forKey: "user_name") ?? ""
    @Published var isServerConnected: Bool = false
    
    var session: MCSession!
    var advertiser: MCNearbyServiceAdvertiser!
    var browser: MCNearbyServiceBrowser!
    var myPeerID: MCPeerID!
    var webSocketTask: URLSessionWebSocketTask?

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

    func connectToServer() {
        guard let url = URL(string: AppConfig.serverURL) else { return }
        let request = URLRequest(url: url)
        webSocketTask = URLSession.shared.webSocketTask(with: request)
        webSocketTask?.resume()
        
        webSocketTask?.sendPing { error in
            DispatchQueue.main.async { self.isServerConnected = (error == nil) }
        }
        receiveFromServer()
    }

    func send(text: String, to recipient: MCPeerID? = nil) {
        let msg = Message(id: UUID(), text: text, senderID: myName, recipientID: recipient?.displayName, isMe: true, viaServer: false)
        
        DispatchQueue.main.async {
            withAnimation {
                if let target = recipient?.displayName { self.privateMessages[target, default: []].append(msg) }
                else { self.groupMessages.append(msg) }
            }
        }

        if let data = try? JSONEncoder().encode(msg) {
            // Mesh
            let targets = recipient != nil ? [recipient!] : session.connectedPeers
            if !targets.isEmpty { try? session.send(data, toPeers: targets, with: .reliable) }
            
            // Server (Distanced communication)
            if isServerConnected {
                let stringData = String(data: data, encoding: .utf8) ?? ""
                webSocketTask?.send(.string(stringData)) { _ in }
            }
        }
    }

    func receiveFromServer() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            if case .success(let message) = result, case .string(let text) = message,
               let data = text.data(using: .utf8),
               let msg = try? JSONDecoder().decode(Message.self, from: data),
               msg.senderID != self.myName {
                
                DispatchQueue.main.async {
                    withAnimation {
                        let receivedMsg = Message(id: msg.id, text: msg.text, senderID: msg.senderID, recipientID: msg.recipientID, isMe: false, viaServer: true)
                        if msg.recipientID == nil { self.groupMessages.append(receivedMsg) }
                        else if msg.recipientID == self.myName { self.privateMessages[msg.senderID, default: []].append(receivedMsg) }
                    }
                }
            }
            self.receiveFromServer()
        }
    }

    // Mesh Handlers
    func session(_ session: MCSession, didReceive data: Data, fromPeer id: MCPeerID) {
        if let msg = try? JSONDecoder().decode(Message.self, from: data) {
            DispatchQueue.main.async {
                withAnimation {
                    let receivedMsg = Message(id: msg.id, text: msg.text, senderID: msg.senderID, recipientID: msg.recipientID, isMe: false, viaServer: false)
                    if msg.recipientID == nil { self.groupMessages.append(receivedMsg) }
                    else if msg.recipientID == self.myName { self.privateMessages[msg.senderID, default: []].append(receivedMsg) }
                }
            }
        }
    }

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { self.peers = session.connectedPeers }
    }
    
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
        if core.myName.isEmpty { RegistrationView(core: core) }
        else {
            TabView {
                GroupChatView(core: core).tabItem { Label("Группа", systemImage: "person.3.fill") }
                PeersListView(core: core).tabItem { Label("Личные", systemImage: "person.fill") }
            }.onAppear { core.start(name: core.myName) }
        }
    }
}

struct GroupChatView: View {
    @ObservedObject var core: GlobalCore
    @State var text = ""
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                StatusBar(core: core)
                ChatBubbleList(messages: core.groupMessages)
                MessageInput(text: $text) { core.send(text: text) }
            }.navigationTitle("HQ Global").navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct PeersListView: View {
    @ObservedObject var core: GlobalCore
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                StatusBar(core: core)
                List(core.peers, id: \.self) { peer in
                    NavigationLink(destination: PrivateChatView(core: core, peer: peer)) {
                        HStack {
                            Circle().fill(Color.blue.gradient).frame(width: 40, height: 40)
                                .overlay(Text(String(peer.displayName.prefix(1)).uppercased()).foregroundColor(.white).bold())
                            Text(peer.displayName).font(.headline)
                        }
                    }
                }.overlay(Group { if core.peers.isEmpty { Text("Рядом никого нет...").foregroundColor(.gray) } })
            }.navigationTitle("Контакты").navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct PrivateChatView: View {
    @ObservedObject var core: GlobalCore
    let peer: MCPeerID
    @State var text = ""
    var body: some View {
        VStack {
            ChatBubbleList(messages: core.privateMessages[peer.displayName] ?? [])
            MessageInput(text: $text) { core.send(text: text, to: peer) }
        }.navigationTitle(peer.displayName).navigationBarTitleDisplayMode(.inline)
    }
}

struct StatusBar: View {
    @ObservedObject var core: GlobalCore
    var body: some View {
        HStack {
            HStack {
                Circle().fill(core.peers.count > 0 ? Color.green : Color.red).frame(width: 10, height: 10)
                Text("Mesh: \(core.peers.count)")
            }.padding(.horizontal)
            Spacer()
            HStack {
                Text("Cloud").foregroundColor(core.isServerConnected ? .blue : .gray)
                Image(systemName: core.isServerConnected ? "network" : "network.slash").foregroundColor(core.isServerConnected ? .blue : .red)
            }.padding(.horizontal)
        }.font(.caption).padding(.vertical, 5).background(Color(UIColor.secondarySystemBackground))
    }
}

struct ChatBubbleList: View {
    let messages: [Message]
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(messages) { msg in
                    HStack(alignment: .bottom) {
                        if msg.isMe { Spacer() }
                        VStack(alignment: msg.isMe ? .trailing : .leading) {
                            if !msg.isMe {
                                HStack {
                                    Text(msg.senderID).font(.caption2).foregroundColor(.gray)
                                    Image(systemName: msg.viaServer ? "cloud.fill" : "wave.3.left").font(.system(size: 8)).foregroundColor(.gray)
                                }
                            }
                            Text(msg.text).padding(12).background(msg.isMe ? Color.blue : Color(UIColor.secondarySystemBackground))
                                .foregroundColor(msg.isMe ? .white : .primary).cornerRadius(18)
                        }
                        if !msg.isMe { Spacer() }
                    }
                }
            }.padding()
        }
    }
}

struct MessageInput: View {
    @Binding var text: String
    var onSend: () -> Void
    var body: some View {
        HStack {
            TextField("Сообщение...", text: $text).padding(10).background(Color.gray.opacity(0.1)).cornerRadius(20)
            Button(action: { onSend(); text = "" }) { Image(systemName: "arrow.up.circle.fill").font(.title).foregroundColor(.blue) }.disabled(text.isEmpty)
        }.padding()
    }
}

struct RegistrationView: View {
    @ObservedObject var core: GlobalCore
    @State var name = ""
    var body: some View {
        VStack(spacing: 30) {
            Text("🛰").font(.system(size: 80))
            Text("HQ Global").font(.largeTitle).bold()
            TextField("Твой ник", text: $name).padding().background(Color.gray.opacity(0.1)).cornerRadius(12).padding(.horizontal)
            Button("Войти") { if !name.isEmpty { core.start(name: name) } }.buttonStyle(.borderedProminent)
        }.edgesIgnoringSafeArea(.all)
    }
}
