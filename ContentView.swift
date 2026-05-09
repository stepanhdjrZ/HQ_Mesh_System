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
    let viaServer: Bool // Флаг: пришло по Mesh или через Сервер
}

// MARK: - ГИБРИДНОЕ ЯДРО (Mesh + Server)
class HybridCore: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    @Published var messages: [Message] = []
    @Published var myName: String = UserDefaults.standard.string(forKey: "user_name") ?? ""
    @Published var meshPeers: Int = 0
    @Published var isServerConnected: Bool = false
    
    // Mesh
    var session: MCSession!
    var advertiser: MCNearbyServiceAdvertiser!
    var browser: MCNearbyServiceBrowser!
    var myPeerID: MCPeerID!
    
    // Server
    var webSocketTask: URLSessionWebSocketTask?

    func startSystem(name: String) {
        self.myName = name
        UserDefaults.standard.set(name, forKey: "user_name")
        
        // 1. Старт Mesh
        myPeerID = MCPeerID(displayName: name)
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: "hq-mesh")
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: "hq-mesh")
        browser.delegate = self
        browser.startBrowsingForPeers()
        
        // 2. Старт Сервера (WebSocket)
        connectToServer()
    }

    // Подключение к серверу
    func connectToServer() {
        // Публичный тестовый сервер. Позже заменим на IP твоего компа!
        guard let url = URL(string: "wss://echo.websocket.events") else { return }
        let request = URLRequest(url: url)
        webSocketTask = URLSession.shared.webSocketTask(with: request)
        webSocketTask?.resume()
        
        // Пинг, чтобы проверить статус
        webSocketTask?.sendPing { error in
            DispatchQueue.main.async { self.isServerConnected = (error == nil) }
        }
        receiveFromServer()
    }

    // Отправка (Умная маршрутизация)
    func send(_ text: String) {
        let msg = Message(id: UUID(), text: text, senderID: myName, isMe: true, viaServer: false)
        DispatchQueue.main.async { withAnimation { self.messages.append(msg) } }
        
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(msg) else { return }
        
        // Отправляем по Mesh
        if !session.connectedPeers.isEmpty {
            try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
        }
        
        // Отправляем на Сервер (если есть)
        if isServerConnected {
            let stringData = String(data: data, encoding: .utf8) ?? ""
            webSocketTask?.send(.string(stringData)) { _ in }
        }
    }

    // Прием с сервера
    func receiveFromServer() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8),
                       let msg = try? JSONDecoder().decode(Message.self, from: data), msg.senderID != self?.myName {
                        DispatchQueue.main.async {
                            withAnimation {
                                self?.messages.append(Message(id: msg.id, text: msg.text, senderID: msg.senderID, isMe: false, viaServer: true))
                            }
                        }
                    }
                default: break
                }
            case .failure(_):
                DispatchQueue.main.async { self?.isServerConnected = false }
            }
            self?.receiveFromServer() // Ждем следующее
        }
    }

    // Прием по Mesh
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let msg = try? JSONDecoder().decode(Message.self, from: data) {
            DispatchQueue.main.async {
                withAnimation {
                    self.messages.append(Message(id: msg.id, text: msg.text, senderID: msg.senderID, isMe: false, viaServer: false))
                }
            }
        }
    }

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { self.meshPeers = session.connectedPeers.count }
    }
    
    // Заглушки
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer id: MCPeerID, withContext c: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) { invitationHandler(true, session) }
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer id: MCPeerID, withDiscoveryInfo i: [String : String]?) { browser.invitePeer(id, to: session, withContext: nil, timeout: 10) }
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer id: MCPeerID) {}
    func session(_ session: MCSession, didReceive stream: InputStream, withName n: String, fromPeer id: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName n: String, fromPeer id: MCPeerID, with p: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName n: String, fromPeer id: MCPeerID, at l: URL?, withError e: Error?) {}
}

// MARK: - ИНТЕРФЕЙС
struct MainCoordinator: View {
    @StateObject var core = HybridCore()
    var body: some View {
        if core.myName.isEmpty { RegistrationView(core: core) }
        else { ChatView(core: core).onAppear { core.startSystem(name: core.myName) } }
    }
}

struct RegistrationView: View {
    @ObservedObject var core: HybridCore
    @State var name = ""
    var body: some View {
        VStack(spacing: 30) {
            Text("🛰").font(.system(size: 80))
            Text("HQ Network").font(.largeTitle).bold()
            TextField("Твой ник", text: $name).padding().background(Color.gray.opacity(0.1)).cornerRadius(12).padding(.horizontal)
            Button("Войти") { if !name.isEmpty { core.startSystem(name: name) } }.buttonStyle(.borderedProminent)
        }.edgesIgnoringSafeArea(.all) // ФИКС МЕЛКОГО ЭКРАНА ДЛЯ UI
    }
}

struct ChatView: View {
    @ObservedObject var core: HybridCore
    @State var text = ""
    var body: some View {
        NavigationView {
            VStack {
                // Статус Бар
                HStack {
                    HStack {
                        Circle().fill(core.meshPeers > 0 ? Color.green : Color.red).frame(width: 10, height: 10)
                        Text("Mesh: \(core.meshPeers)")
                    }.padding(.horizontal)
                    Spacer()
                    HStack {
                        Text("Cloud").foregroundColor(core.isServerConnected ? .blue : .gray)
                        Image(systemName: core.isServerConnected ? "network" : "network.slash").foregroundColor(core.isServerConnected ? .blue : .red)
                    }.padding(.horizontal)
                }.font(.caption).padding(.vertical, 5).background(Color(UIColor.secondarySystemBackground))
                
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(core.messages) { msg in
                            HStack(alignment: .bottom) {
                                if msg.isMe { Spacer() }
                                VStack(alignment: msg.isMe ? .trailing : .leading) {
                                    if !msg.isMe {
                                        HStack {
                                            Text(msg.senderID).font(.caption2).foregroundColor(.gray)
                                            Image(systemName: msg.viaServer ? "cloud.fill" : "wave.3.left").font(.system(size: 8)).foregroundColor(.gray)
                                        }
                                    }
                                    Text(msg.text)
                                        .padding(12).background(msg.isMe ? Color.blue : Color(UIColor.secondarySystemBackground))
                                        .foregroundColor(msg.isMe ? .white : .primary).cornerRadius(18)
                                }
                                if !msg.isMe { Spacer() }
                            }
                        }
                    }.padding()
                }
                
                HStack {
                    TextField("Сообщение...", text: $text).padding(10).background(Color.gray.opacity(0.1)).cornerRadius(20)
                    Button(action: { core.send(text); text = "" }) {
                        Image(systemName: "arrow.up.circle.fill").font(.title).foregroundColor(.blue)
                    }.disabled(text.isEmpty)
                }.padding()
            }
            .navigationTitle("HQ Global")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
