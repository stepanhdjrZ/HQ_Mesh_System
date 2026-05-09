import SwiftUI
import MultipeerConnectivity

@main
struct MessengerApp: App {
    var body: some Scene {
        WindowGroup {
            MainCoordinator()
        }
    }
}

// MARK: - МОДЕЛИ ДАННЫХ
struct Chat: Identifiable, Hashable {
    let id: String // Обычно это Ghost-ID
    var lastMessage: String
    var time: String
}

struct Message: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let senderID: String
    let isMe: Bool
}

// MARK: - ЛОГИКА СЕТИ
class MeshCore: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    @Published var messages: [Message] = []
    @Published var activeChats: [Chat] = []
    @Published var myName: String = UserDefaults.standard.string(forKey: "user_name") ?? ""
    
    var session: MCSession!
    var advertiser: MCNearbyServiceAdvertiser!
    var browser: MCNearbyServiceBrowser!
    var myPeerID: MCPeerID!

    func setupMesh(name: String) {
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

    func send(_ text: String) {
        let msg = Message(id: UUID(), text: text, senderID: myName, isMe: true)
        DispatchQueue.main.async { self.messages.append(msg) }
        if let data = try? JSONEncoder().encode(msg) {
            try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let msg = try? JSONDecoder().decode(Message.self, from: data) {
            DispatchQueue.main.async {
                self.messages.append(Message(id: msg.id, text: msg.text, senderID: msg.senderID, isMe: false))
                // Обновляем список чатов
                if let index = self.activeChats.firstIndex(where: { $0.id == msg.senderID }) {
                    self.activeChats[index].lastMessage = msg.text
                } else {
                    self.activeChats.append(Chat(id: msg.senderID, lastMessage: msg.text, time: "сейчас"))
                }
            }
            // Ретрансляция (Mesh Hop)
            try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
        }
    }

    // Заглушки протокола
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {}
    func session(_ session: MCSession, didReceive stream: InputStream, withName n: String, fromPeer id: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName n: String, fromPeer id: MCPeerID, with p: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName n: String, fromPeer id: MCPeerID, at l: URL?, withError e: Error?) {}
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer id: MCPeerID, withContext c: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) { invitationHandler(true, session) }
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer id: MCPeerID, withDiscoveryInfo i: [String : String]?) { browser.invitePeer(id, to: session, withContext: nil, timeout: 10) }
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer id: MCPeerID) {}
}

// MARK: - ИНТЕРФЕЙС (UI)
struct MainCoordinator: View {
    @StateObject var core = MeshCore()
    
    var body: some View {
        if core.myName.isEmpty {
            RegistrationView(core: core)
        } else {
            ChatListView(core: core)
                .onAppear { core.setupMesh(name: core.myName) }
        }
    }
}

struct RegistrationView: View {
    @ObservedObject var core: MeshCore
    @State var tempName = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "paperplane.circle.fill").font(.system(size: 80)).foregroundColor(.blue)
            Text("HQ Messenger").font(.largeTitle).bold()
            Text("Придумай анонимный ник для Mesh-сети").foregroundColor(.gray)
            
            TextField("Твой ник (напр. Ghost-77)", text: $tempName)
                .padding().background(Color.gray.opacity(0.1)).cornerRadius(12).padding(.horizontal)
            
            Button("Войти в сеть") {
                if !tempName.isEmpty { core.setupMesh(name: tempName) }
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
        }
    }
}

struct ChatListView: View {
    @ObservedObject var core: MeshCore
    
    var body: some View {
        NavigationView {
            List(core.activeChats) { chat in
                NavigationLink(destination: ChatDetailView(core: core, chat: chat)) {
                    HStack {
                        Circle().fill(Color.blue.opacity(0.8)).frame(width: 50, height: 50)
                            .overlay(Text(String(chat.id.prefix(1))).foregroundColor(.white).bold())
                        VStack(alignment: .leading) {
                            Text(chat.id).bold()
                            Text(chat.lastMessage).font(.subheadline).foregroundColor(.gray).lineLimit(1)
                        }
                        Spacer()
                        Text(chat.time).font(.caption2).foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Чаты")
        }
    }
}

struct ChatDetailView: View {
    @ObservedObject var core: MeshCore
    let chat: Chat
    @State var text = ""
    
    var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(core.messages.filter { $0.senderID == chat.id || ($0.isMe && core.activeChats.contains(where: { $0.id == chat.id })) }) { msg in
                        HStack {
                            if msg.isMe { Spacer() }
                            Text(msg.text)
                                .padding(12).background(msg.isMe ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(msg.isMe ? .white : .primary)
                                .cornerRadius(18)
                            if !msg.isMe { Spacer() }
                        }
                    }
                }.padding()
            }
            
            HStack {
                TextField("Сообщение", text: $text)
                    .padding(10).background(Color.gray.opacity(0.1)).cornerRadius(20)
                Button(action: {
                    core.send(text)
                    text = ""
                }) {
                    Image(systemName: "arrow.up.circle.fill").font(.title).foregroundColor(.blue)
                }
            }.padding()
        }
        .navigationTitle(chat.id)
    }
}
