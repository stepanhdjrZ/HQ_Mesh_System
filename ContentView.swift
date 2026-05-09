import SwiftUI
import MultipeerConnectivity

@main
struct MessengerApp: App {
    var body: some Scene {
        WindowGroup { MainCoordinator() }
    }
}

// MARK: - МОДЕЛЬ СООБЩЕНИЯ
struct Message: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let senderID: String
    let recipientID: String? // nil для групп
    let isMe: Bool
}

// MARK: - ЯДРО СЕТИ
class MeshCore: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    @Published var groupMessages: [Message] = []
    @Published var privateMessages: [String: [Message]] = [:] // Ник : [Сообщения]
    @Published var peers: [MCPeerID] = []
    @Published var myName: String = UserDefaults.standard.string(forKey: "user_name") ?? ""
    
    var session: MCSession!
    var advertiser: MCNearbyServiceAdvertiser!
    var browser: MCNearbyServiceBrowser!
    var myPeerID: MCPeerID!

    func setup(name: String) {
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
    }

    func send(text: String, to recipient: MCPeerID? = nil) {
        let msg = Message(id: UUID(), text: text, senderID: myName, recipientID: recipient?.displayName, isMe: true)
        
        DispatchQueue.main.async {
            if let target = recipient?.displayName {
                self.privateMessages[target, default: []].append(msg)
            } else {
                self.groupMessages.append(msg)
            }
        }

        if let data = try? JSONEncoder().encode(msg) {
            let targets = recipient != nil ? [recipient!] : session.connectedPeers
            try? session.send(data, toPeers: targets, with: .reliable)
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let msg = try? JSONDecoder().decode(Message.self, from: data) {
            DispatchQueue.main.async {
                let receivedMsg = Message(id: msg.id, text: msg.text, senderID: msg.senderID, recipientID: msg.recipientID, isMe: false)
                
                if msg.recipientID == nil {
                    self.groupMessages.append(receivedMsg)
                } else if msg.recipientID == self.myName {
                    self.privateMessages[msg.senderID, default: []].append(receivedMsg)
                }
            }
        }
    }

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { self.peers = session.connectedPeers }
    }
    
    // Заглушки
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer id: MCPeerID, withContext c: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) { invitationHandler(true, session) }
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer id: MCPeerID, withDiscoveryInfo info: [String : String]?) { browser.invitePeer(id, to: session, withContext: nil, timeout: 10) }
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer id: MCPeerID) {}
    func session(_ session: MCSession, didReceive stream: InputStream, withName n: String, fromPeer id: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName n: String, fromPeer id: MCPeerID, with p: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName n: String, fromPeer id: MCPeerID, at l: URL?, withError e: Error?) {}
}

// MARK: - ИНТЕРФЕЙС
struct MainCoordinator: View {
    @StateObject var core = MeshCore()
    var body: some View {
        if core.myName.isEmpty { RegistrationView(core: core) }
        else {
            TabView {
                GroupChatView(core: core)
                    .tabItem { Label("Группа", systemImage: "person.3.fill") }
                
                PeersListView(core: core)
                    .tabItem { Label("Личные", systemImage: "person.fill") }
            }
            .onAppear { core.setup(name: core.myName) }
        }
    }
}

struct GroupChatView: View {
    @ObservedObject var core: MeshCore
    @State var text = ""
    var body: some View {
        NavigationView {
            VStack {
                ChatBubbleList(messages: core.groupMessages)
                MessageInput(text: $text) { core.send(text: text) }
            }
            .navigationTitle("Общий канал")
        }
    }
}

struct PeersListView: View {
    @ObservedObject var core: MeshCore
    var body: some View {
        NavigationView {
            List(core.peers, id: \.self) { peer in
                NavigationLink(destination: PrivateChatView(core: core, peer: peer)) {
                    HStack {
                        Avatar(name: peer.displayName)
                        Text(peer.displayName).font(.headline)
                    }
                }
            }
            .navigationTitle("Контакты")
            .overlay(Group { if core.peers.isEmpty { Text("Никого нет рядом...").foregroundColor(.gray) } })
        }
    }
}

struct PrivateChatView: View {
    @ObservedObject var core: MeshCore
    let peer: MCPeerID
    @State var text = ""
    var body: some View {
        VStack {
            ChatBubbleList(messages: core.privateMessages[peer.displayName] ?? [])
            MessageInput(text: $text) { core.send(text: text, to: peer) }
        }
        .navigationTitle(peer.displayName)
    }
}

// MARK: - UI КОМПОНЕНТЫ
struct ChatBubbleList: View {
    let messages: [Message]
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(messages) { msg in
                    HStack {
                        if msg.isMe { Spacer() }
                        VStack(alignment: msg.isMe ? .trailing : .leading) {
                            if !msg.isMe { Text(msg.senderID).font(.caption2).foregroundColor(.gray) }
                            Text(msg.text)
                                .padding(10).background(msg.isMe ? Color.blue : Color.gray.opacity(0.15))
                                .foregroundColor(msg.isMe ? .white : .primary).cornerRadius(15)
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
            Button(action: { onSend(); text = "" }) {
                Image(systemName: "paperplane.fill").font(.title2)
            }.disabled(text.isEmpty)
        }.padding()
    }
}

struct Avatar: View {
    let name: String
    var body: some View {
        Circle().fill(Color.blue.gradient).frame(width: 40, height: 40)
            .overlay(Text(String(name.prefix(1)).uppercased()).foregroundColor(.white).bold())
    }
}

struct RegistrationView: View {
    @ObservedObject var core: MeshCore
    @State var name = ""
    var body: some View {
        VStack(spacing: 20) {
            Text("🛰").font(.system(size: 80))
            Text("Вход в HQ Mesh").font(.title).bold()
            TextField("Твой ник", text: $name).padding().background(Color.gray.opacity(0.1)).cornerRadius(12).padding(.horizontal)
            Button("Создать аккаунт") { if !name.isEmpty { core.setup(name: name) } }.buttonStyle(.borderedProminent)
        }
    }
}
