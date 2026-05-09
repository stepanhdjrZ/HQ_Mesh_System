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

// MARK: - Модели
struct Message: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let senderID: String
    let isMe: Bool
}

// MARK: - Ядро Сети
class MeshCore: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    @Published var messages: [Message] = []
    @Published var myName: String = UserDefaults.standard.string(forKey: "user_name") ?? ""
    @Published var peersCount: Int = 0
    
    var session: MCSession!
    var advertiser: MCNearbyServiceAdvertiser!
    var browser: MCNearbyServiceBrowser!
    var myPeerID: MCPeerID!
    private var seenIDs = Set<UUID>()

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
    }

    func send(_ text: String) {
        let msg = Message(id: UUID(), text: text, senderID: myName, isMe: true)
        DispatchQueue.main.async { withAnimation { self.messages.append(msg) } }
        seenIDs.insert(msg.id)
        broadcast(msg)
    }

    private func broadcast(_ msg: Message) {
        if let data = try? JSONEncoder().encode(msg) {
            try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let msg = try? JSONDecoder().decode(Message.self, from: data), !seenIDs.contains(msg.id) {
            seenIDs.insert(msg.id)
            DispatchQueue.main.async {
                withAnimation(.spring()) {
                    self.messages.append(Message(id: msg.id, text: msg.text, senderID: msg.senderID, isMe: false))
                }
            }
            broadcast(msg) // Тот самый Прыжок (Hop)
        }
    }

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { self.peersCount = session.connectedPeers.count }
    }
    func session(_ session: MCSession, didReceive stream: InputStream, withName n: String, fromPeer id: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName n: String, fromPeer id: MCPeerID, with p: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName n: String, fromPeer id: MCPeerID, at l: URL?, withError e: Error?) {}
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer id: MCPeerID, withContext c: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) { invitationHandler(true, session) }
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer id: MCPeerID, withDiscoveryInfo i: [String : String]?) { browser.invitePeer(id, to: session, withContext: nil, timeout: 10) }
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer id: MCPeerID) {}
}

// MARK: - Интерфейс
struct MainCoordinator: View {
    @StateObject var core = MeshCore()
    var body: some View {
        if core.myName.isEmpty { RegistrationView(core: core) }
        else { ChatUI(core: core).onAppear { core.start(name: core.myName) } }
    }
}

struct RegistrationView: View {
    @ObservedObject var core: MeshCore
    @State var name = ""
    var body: some View {
        VStack(spacing: 30) {
            ZStack {
                Circle().fill(Color.blue).frame(width: 100, height: 100)
                Image(systemName: "paperplane.fill").font(.system(size: 50)).foregroundColor(.white)
            }
            Text("HQ Mesh").font(.system(size: 32, weight: .bold))
            TextField("Твой ник", text: $name)
                .padding().background(Color.gray.opacity(0.1)).cornerRadius(15).padding(.horizontal)
            Button("Начать общение") { if !name.isEmpty { core.start(name: name) } }
                .buttonStyle(.borderedProminent).controlSize(.large)
        }
    }
}

struct ChatUI: View {
    @ObservedObject var core: MeshCore
    @State var text = ""
    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    VStack(spacing: 15) {
                        ForEach(core.messages) { msg in
                            HStack(alignment: .bottom, spacing: 10) {
                                if !msg.isMe { Avatar(name: msg.senderID) }
                                else { Spacer() }
                                
                                Text(msg.text)
                                    .padding(12).background(msg.isMe ? Color.blue : Color(UIColor.secondarySystemBackground))
                                    .foregroundColor(msg.isMe ? .white : .primary)
                                    .cornerRadius(18)
                                
                                if !msg.isMe { Spacer() }
                            }
                        }
                    }.padding()
                }
                HStack {
                    TextField("Сообщение", text: $text).padding(10).background(Color.gray.opacity(0.1)).cornerRadius(20)
                    Button(action: { core.send(text); text = "" }) {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 30)).foregroundColor(.blue)
                    }.disabled(text.isEmpty)
                }.padding()
            }
            .navigationTitle("Чаты")
            .navigationBarItems(trailing: Text("В сети: \(core.peersCount)").font(.caption).foregroundColor(.green))
        }
    }
}

struct Avatar: View {
    let name: String
    var body: some View {
        let colors: [Color] = [.blue, .purple, .orange, .pink, .green, .cyan]
        let color = colors[abs(name.hashValue) % colors.count]
        Circle().fill(color).frame(width: 35, height: 35)
            .overlay(Text(String(name.prefix(1)).uppercased()).foregroundColor(.white).bold())
    }
}
