import SwiftUI
import MultipeerConnectivity

@main
struct MessengerApp: App {
    var body: some Scene {
        WindowGroup { MainCoordinator() }
    }
}

// MARK: - МОДЕЛИ (с поддержкой сохранения)
struct Message: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let senderID: String
    let recipientID: String?
    let isMe: Bool
    let viaServer: Bool
}

struct ServerPacket: Codable {
    let type: String
    let payload: [Message]
}

// MARK: - ГИБРИДНОЕ ЯДРО С ПАМЯТЬЮ
class GlobalCore: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    @Published var groupMessages: [Message] = []
    @Published var peers: [MCPeerID] = []
    @Published var myName: String = UserDefaults.standard.string(forKey: "user_name") ?? ""
    @Published var isServerConnected: Bool = false
    
    var session: MCSession!
    var advertiser: MCNearbyServiceAdvertiser!
    var browser: MCNearbyServiceBrowser!
    var myPeerID: MCPeerID!
    var webSocketTask: URLSessionWebSocketTask?
    
    let historyURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("history.json")

    override init() {
        super.init()
        loadLocalHistory() // Загружаем старые чаты при запуске
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

    // ЛОКАЛЬНОЕ ХРАНЕНИЕ
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
        // ЗАМЕНИ НА СВОЙ IP: 192.168.0.55
        guard let url = URL(string: "ws://192.168.0.55:8080") else { return }
        webSocketTask = URLSession.shared.webSocketTask(with: url)
        webSocketTask?.resume()
        
        webSocketTask?.sendPing { error in
            DispatchQueue.main.async { self.isServerConnected = (error == nil) }
        }
        receiveFromServer()
    }

    func send(text: String) {
        let msg = Message(id: UUID(), text: text, senderID: myName, recipientID: nil, isMe: true, viaServer: false)
        
        DispatchQueue.main.async {
            withAnimation {
                self.groupMessages.append(msg)
                self.saveLocally()
            }
        }

        if let data = try? JSONEncoder().encode(msg) {
            if !session.connectedPeers.isEmpty {
                try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
            }
            if isServerConnected {
                webSocketTask?.send(.string(String(data: data, encoding: .utf8) ?? "")) { _ in }
            }
        }
    }

    func receiveFromServer() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            if case .success(let message) = result, case .string(let text) = message,
               let data = text.data(using: .utf8) {
                
                // Обрабатываем либо одно сообщение, либо целую историю
                if let packet = try? JSONDecoder().decode(ServerPacket.self, from: data) {
                    DispatchQueue.main.async {
                        if packet.type == "history" {
                            // Умное слияние истории: добавляем только те, которых у нас нет
                            let newMsgs = packet.payload.filter { p in !self.groupMessages.contains(where: { $0.id == p.id }) }
                            self.groupMessages.append(contentsOf: newMsgs.map { 
                                Message(id: $0.id, text: $0.text, senderID: $0.senderID, recipientID: $0.recipientID, isMe: $0.senderID == self.myName, viaServer: true)
                            })
                        }
                        self.saveLocally()
                    }
                } else if let msg = try? JSONDecoder().decode(Message.self, from: data), msg.senderID != self.myName {
                    DispatchQueue.main.async {
                        withAnimation {
                            self.groupMessages.append(Message(id: msg.id, text: msg.text, senderID: msg.senderID, recipientID: msg.recipientID, isMe: false, viaServer: true))
                            self.saveLocally()
                        }
                    }
                }
            }
            self.receiveFromServer()
        }
    }

    // Mesh (аналогично добавляем saveLocally)
    func session(_ session: MCSession, didReceive data: Data, fromPeer id: MCPeerID) {
        if let msg = try? JSONDecoder().decode(Message.self, from: data) {
            DispatchQueue.main.async {
                withAnimation {
                    self.groupMessages.append(Message(id: msg.id, text: msg.text, senderID: msg.senderID, recipientID: msg.recipientID, isMe: false, viaServer: false))
                    self.saveLocally()
                }
            }
        }
    }
    
    // Стандартные методы Mesh (оставляем без изменений)
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) { DispatchQueue.main.async { self.peers = session.connectedPeers } }
    func advertiser(_ a: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer id: MCPeerID, withContext c: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) { invitationHandler(true, session) }
    func browser(_ b: MCNearbyServiceBrowser, foundPeer id: MCPeerID, withDiscoveryInfo i: [String : String]?) { b.invitePeer(id, to: session, withContext: nil, timeout: 10) }
    func browser(_ b: MCNearbyServiceBrowser, lostPeer id: MCPeerID) {}
    func session(_ s: MCSession, didReceive stream: InputStream, withName n: String, fromPeer id: MCPeerID) {}
    func session(_ s: MCSession, didStartReceivingResourceWithName n: String, fromPeer id: MCPeerID, with p: Progress) {}
    func session(_ s: MCSession, didFinishReceivingResourceWithName n: String, fromPeer id: MCPeerID, at l: URL?, withError e: Error?) {}
}

// MARK: - UI (фикс экрана Pro Max + статус)
struct MainCoordinator: View {
    @StateObject var core = GlobalCore()
    var body: some View {
        NavigationView {
            if core.myName.isEmpty { RegistrationView(core: core) }
            else {
                VStack(spacing: 0) {
                    HStack {
                        Circle().fill(core.isServerConnected ? Color.blue : Color.red).frame(width: 8, height: 8)
                        Text(core.isServerConnected ? "Центр на связи" : "Локальный режим").font(.caption).foregroundColor(.gray)
                        Spacer()
                        Text("Узлов: \(core.peers.count)").font(.caption).foregroundColor(.gray)
                    }.padding(.horizontal).padding(.top, 5)
                    
                    ChatView(core: core)
                }
                .navigationTitle("HQ Global")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear { core.start(name: core.myName) }
            }
        }.navigationViewStyle(.stack)
    }
}

struct ChatView: View {
    @ObservedObject var core: GlobalCore
    @State var text = ""
    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(core.groupMessages) { msg in
                            HStack {
                                if msg.isMe { Spacer() }
                                VStack(alignment: msg.isMe ? .trailing : .leading) {
                                    Text(msg.senderID).font(.caption2).foregroundColor(.gray)
                                    Text(msg.text).padding(12).background(msg.isMe ? Color.blue : Color(.secondarySystemBackground))
                                        .foregroundColor(msg.isMe ? .white : .primary).cornerRadius(16)
                                }
                                if !msg.isMe { Spacer() }
                            }.id(msg.id)
                        }
                    }.padding()
                }
                .onChange(of: core.groupMessages.count) { _ in
                    withAnimation { proxy.scrollTo(core.groupMessages.last?.id) }
                }
            }
            
            HStack {
                TextField("Сообщение...", text: $text).padding(10).background(Color(.systemGray6)).cornerRadius(20)
                Button(action: { core.send(text: text); text = "" }) {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 32))
                }.disabled(text.isEmpty)
            }.padding()
        }
    }
}

struct RegistrationView: View {
    @ObservedObject var core: GlobalCore
    @State var name = ""
    var body: some View {
        VStack(spacing: 20) {
            Text("🛰").font(.system(size: 80))
            Text("Вход в HQ Mesh").font(.title).bold()
            TextField("Никнейм", text: $name).padding().background(Color(.systemGray6)).cornerRadius(12).padding(.horizontal)
            Button("Начать") { if !name.isEmpty { core.start(name: name) } }.buttonStyle(.borderedProminent)
        }
    }
}
