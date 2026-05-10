import SwiftUI
import AVKit
import PhotosUI
import MultipeerConnectivity

@main
struct MessengerApp: App { var body: some Scene { WindowGroup { MainCoordinator() } } }

enum MsgType: String, Codable { case text, image, voice, circle, call }
struct Message: Identifiable, Codable, Hashable { let id: UUID; let text: String; let senderID: String; let target: String; let isGroup: Bool; let type: MsgType; let url: String?; let isMe: Bool }

struct Chat: Identifiable, Hashable {
    let id: String; let isGroup: Bool; var messages: [Message]
    var lastMsg: String { messages.last?.text ?? (messages.last?.type == .circle ? "Кружочек" : "Медиа") }
}

class GlobalCore: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    @Published var chats: [String: Chat] = ["ОБЩИЙ ЧАТ": Chat(id: "ОБЩИЙ ЧАТ", isGroup: true, messages: [])]
    @Published var contacts: [String] = []
    @Published var name = UserDefaults.standard.string(forKey: "u_name") ?? ""
    @AppStorage("ngrok_host") var host = "твой.ngrok-free.dev"
    @Published var peersCount = 0
    @Published var activeCall: String? = nil
    
    var ws: URLSessionWebSocketTask?; var session: MCSession?; var adv: MCNearbyServiceAdvertiser?; var bro: MCNearbyServiceBrowser?
    var recorder: AVAudioRecorder?

    func setup(n: String) {
        self.name = n.lowercased(); UserDefaults.standard.set(n, forKey: "u_name")
        let pid = MCPeerID(displayName: n)
        session = MCSession(peer: pid, securityIdentity: nil, encryptionPreference: .none); session?.delegate = self
        adv = MCNearbyServiceAdvertiser(peer: pid, discoveryInfo: nil, serviceType: "hq-mesh"); adv?.delegate = self; adv?.startAdvertisingPeer()
        bro = MCNearbyServiceBrowser(peer: pid, serviceType: "hq-mesh"); bro?.delegate = self; bro?.startBrowsingForPeers()
        connect()
    }

    func connect() {
        let h = host.replacingOccurrences(of: "https://", with: "")
        guard let url = URL(string: "wss://\(h)/ws") else { return }
        ws = URLSession.shared.webSocketTask(with: url); ws?.resume()
        sendPacket(["type": "register", "name": name]); listen()
    }

    func listen() {
        ws?.receive { [weak self] res in
            guard let self = self, case .success(let m) = res, case .string(let s) = m, let d = s.data(using: .utf8), let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { self?.listen(); return }
            DispatchQueue.main.async {
                let t = j["type"] as? String
                if t == "contacts", let users = j["users"] as? [String] {
                    self.contacts = users.filter { $0 != self.name }
                    for u in self.contacts where self.chats[u] == nil { self.chats[u] = Chat(id: u, isGroup: false, messages: []) }
                } else if t == "msg", let sID = j["senderID"] as? String, sID != self.name {
                    let target = j["target"] as? String ?? ""; let isG = j["isGroup"] as? Bool ?? false
                    let msg = Message(id: UUID(), text: j["text"] as? String ?? "", senderID: sID, target: target, isGroup: isG, type: MsgType(rawValue: j["msgType"] as? String ?? "text") ?? .text, url: j["url"] as? String, isMe: false)
                    let key = isG ? target : sID
                    if self.chats[key] == nil { self.chats[key] = Chat(id: key, isGroup: isG, messages: []) }
                    self.chats[key]?.messages.append(msg)
                }
            }
            self.listen()
        }
    }

    func sendPacket(_ p: [String: Any]) { if let d = try? JSONSerialization.data(withJSONObject: p) { ws?.send(.string(String(data: d, encoding: .utf8)!)) { _ in } } }

    func send(txt: String = "", type: MsgType = .text, url: String? = nil, target: String, isGroup: Bool) {
        let p: [String: Any] = ["type": "msg", "senderID": name, "target": target, "isGroup": isGroup, "text": txt, "msgType": type.rawValue, "url": url ?? ""]
        DispatchQueue.main.async {
            self.chats[target]?.messages.append(Message(id: UUID(), text: txt, senderID: self.name, target: target, isGroup: isGroup, type: type, url: url, isMe: true))
            self.sendPacket(p)
            if let s = self.session, let d = try? JSONSerialization.data(withJSONObject: p) { try? s.send(d, toPeers: s.connectedPeers, with: .reliable) }
        }
    }

    func upload(data: Data, ext: String, type: MsgType, target: String, isGroup: Bool) {
        let url = URL(string: "https://\(host)/upload")!; var req = URLRequest(url: url); req.httpMethod = "POST"
        let b = UUID().uuidString; req.setValue("multipart/form-data; boundary=\(b)", forHTTPHeaderField: "Content-Type")
        var body = Data(); body.append("--\(b)\r\n".data(using: .utf8)!); body.append("Content-Disposition: form-data; name=\"file\"; filename=\"file.\(ext)\"\r\n\r\n".data(using: .utf8)!); body.append(data); body.append("\r\n--\(b)--\r\n".data(using: .utf8)!)
        URLSession.shared.uploadTask(with: req, from: body) { d, _, _ in
            if let d = d, let res = try? JSONDecoder().decode([String: String].self, from: d), let fUrl = res["url"] {
                DispatchQueue.main.async { self.send(type: type, url: fUrl, target: target, isGroup: isGroup) }
            }
        }.resume()
    }

    // Mesh
    func session(_ s: MCSession, peer id: MCPeerID, didChange st: MCSessionState) { DispatchQueue.main.async { self.peersCount = s.connectedPeers.count } }
    func session(_ s: MCSession, didReceive d: Data, fromPeer id: MCPeerID) {
        if let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any], let sID = j["senderID"] as? String {
            DispatchQueue.main.async {
                let target = j["target"] as? String ?? ""; let isG = j["isGroup"] as? Bool ?? false
                let key = isG ? target : sID
                let msg = Message(id: UUID(), text: j["text"] as? String ?? "", senderID: sID, target: target, isGroup: isG, type: .text, url: j["url"] as? String, isMe: false)
                if self.chats[key] == nil { self.chats[key] = Chat(id: key, isGroup: isG, messages: []) }
                self.chats[key]?.messages.append(msg)
            }
        }
    }
    func advertiser(_ a: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer i: MCPeerID, withContext c: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) { invitationHandler(true, self.session) }
    func browser(_ b: MCNearbyServiceBrowser, foundPeer i: MCPeerID, withDiscoveryInfo d: [String : String]?) { if let s = session { b.invitePeer(i, to: s, withContext: nil, timeout: 10) } }
    func session(_ s: MCSession, didReceive st: InputStream, withName n: String, fromPeer i: MCPeerID) {}
    func session(_ s: MCSession, didStartReceivingResourceWithName n: String, fromPeer i: MCPeerID, with p: Progress) {}
    func session(_ s: MCSession, didFinishReceivingResourceWithName n: String, fromPeer i: MCPeerID, at l: URL?, withError e: Error?) {}
    func browser(_ b: MCNearbyServiceBrowser, lostPeer i: MCPeerID) {}
}

struct MainCoordinator: View {
    @StateObject var core = GlobalCore()
    var body: some View {
        if core.name.isEmpty { LoginView(core: core) }
        else {
            ZStack {
                TabView {
                    ChatListView(core: core).tabItem { Label("Чаты", systemImage: "message.fill") }
                    ContactsView(core: core).tabItem { Label("Контакты", systemImage: "person.2.fill") }
                    SettingsView(core: core).tabItem { Label("Настройки", systemImage: "gear") }
                }
                if let callUser = core.activeCall { CallView(user: callUser, core: core) }
            }
            .onAppear { core.setup(n: core.name) }
        }
    }
}

// ЭКРАН ЗВОНКА
struct CallView: View {
    let user: String; @ObservedObject var core: GlobalCore
    var body: some View {
        VStack {
            Spacer()
            Circle().fill(Color.gray).frame(width: 120, height: 120).overlay(Text(user.prefix(1).uppercased()).font(.largeTitle).foregroundColor(.white))
            Text(user.uppercased()).font(.title).bold().padding()
            Text("ЗВОНОК...").foregroundColor(.green).font(.headline)
            Spacer()
            HStack(spacing: 50) {
                Button(action: { core.activeCall = nil }) { Image(systemName: "phone.down.fill").font(.system(size: 40)).foregroundColor(.red).padding(30).background(Color.white).clipShape(Circle()) }
                Button(action: {}) { Image(systemName: "mic.fill").font(.system(size: 30)).foregroundColor(.gray).padding(20).background(Color.white).clipShape(Circle()) }
            }
            Spacer()
        }.background(Color.black.opacity(0.9).ignoresSafeArea())
    }
}

struct ChatRoom: View {
    @ObservedObject var core: GlobalCore; let chatID: String; let isGroup: Bool
    @State var txt = ""; @State var showCircles = false
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        if let msgs = core.chats[chatID]?.messages { ForEach(msgs) { m in Bubble(m: m, isGroup: isGroup).id(m.id) } }
                    }.padding()
                }.onChange(of: core.chats[chatID]?.messages.count) { _ in withAnimation { proxy.scrollTo(core.chats[chatID]?.messages.last?.id) } }
            }
            
            HStack(spacing: 12) {
                Button(action: { showCircles.toggle() }) { Image(systemName: "play.circle.fill").font(.title).foregroundColor(.blue) }
                TextField("Сообщение...", text: $txt).padding(10).background(Color(UIColor.systemGray6)).cornerRadius(20)
                Button(action: { if !txt.isEmpty { core.send(txt: txt, target: chatID, isGroup: isGroup); txt = "" } }) { Image(systemName: "paperplane.fill").font(.title2) }
            }.padding()
        }
        .navigationTitle(chatID.uppercased())
        .toolbar {
            Button(action: { core.activeCall = chatID }) { Image(systemName: "video.fill") }
        }
        .sheet(isPresented: $showCircles) { CircleRecorder(core: core, target: chatID, isGroup: isGroup) }
    }
}

// КРУЖОЧКИ (ВИДЕО)
struct CircleRecorder: View {
    @ObservedObject var core: GlobalCore; let target: String; let isGroup: Bool
    @Environment(\.presentationMode) var pm
    var body: some View {
        VStack {
            Text("Запись кружочка").font(.headline).padding()
            Circle().fill(Color.black).frame(width: 250, height: 250).overlay(Text("КАМЕРА").foregroundColor(.white))
            Text("Удерживай кнопку для записи").font(.caption).padding()
            Button(action: {
                // Имитация записи кружочка
                core.send(txt: "🎥 Видео-кружочек", type: .circle, url: "https://www.w3schools.com/html/mov_bbb.mp4", target: target, isGroup: isGroup)
                pm.wrappedValue.dismiss()
            }) {
                Circle().fill(Color.red).frame(width: 80, height: 80).shadow(radius: 5)
            }.padding(40)
        }
    }
}

struct Bubble: View {
    let m: Message; let isGroup: Bool
    var body: some View {
        HStack {
            if m.isMe { Spacer() }
            VStack(alignment: m.isMe ? .trailing : .leading) {
                if isGroup && !m.isMe { Text(m.senderID).font(.caption2).bold().foregroundColor(.blue) }
                
                if m.type == .circle {
                    VideoPlayer(player: AVPlayer(url: URL(string: m.url ?? "")!))
                        .frame(width: 200, height: 200).clipShape(Circle()).overlay(Circle().stroke(Color.blue, lineWidth: 2))
                } else {
                    Text(m.text).padding(12).background(m.isMe ? Color.blue : Color(UIColor.systemGray5)).foregroundColor(m.isMe ? .white : .primary).cornerRadius(18)
                }
            }
            if !m.isMe { Spacer() }
        }
    }
}

// Остальные вспомогательные вью (ChatListView, ContactsView и т.д. остаются как в v12.0)
struct ChatListView: View {
    @ObservedObject var core: GlobalCore
    var body: some View {
        NavigationView {
            List(Array(core.chats.values), id: \.id) { chat in
                NavigationLink(destination: ChatRoom(core: core, chatID: chat.id, isGroup: chat.isGroup)) {
                    HStack {
                        Circle().fill(chat.isGroup ? Color.blue : Color.green).frame(width: 45, height: 45).overlay(Text(chat.id.prefix(1).uppercased()).foregroundColor(.white))
                        VStack(alignment: .leading) { Text(chat.id.uppercased()).bold(); Text(chat.lastMsg).font(.caption).foregroundColor(.gray).lineLimit(1) }
                    }
                }
            }.navigationTitle("TG Global")
        }
    }
}
struct ContactsView: View {
    @ObservedObject var core: GlobalCore
    var body: some View {
        NavigationView {
            List(core.contacts, id: \.self) { c in
                NavigationLink(destination: ChatRoom(core: core, chatID: c, isGroup: false)) { Text(c.uppercased()) }
            }.navigationTitle("Контакты")
        }
    }
}
struct SettingsView: View {
    @ObservedObject var core: GlobalCore; @State var h = ""
    var body: some View {
        NavigationView {
            Form {
                Section("Сервер") { TextField("Ngrok", text: $h); Button("Сохранить") { core.host = h; core.connect() } }
                Section("Инфо") { Text("Имя: \(core.name)"); Text("Mesh узлов: \(core.peersCount)") }
            }.navigationTitle("Настройки").onAppear { h = core.host }
        }
    }
}
struct LoginView: View {
    @ObservedObject var core: GlobalCore; @State var n = ""
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "paperplane.fill").font(.system(size: 80)).foregroundColor(.blue)
            TextField("Никнейм", text: $n).textFieldStyle(.roundedBorder).padding(.horizontal, 50)
            Button("Войти") { core.setup(n: n) }.buttonStyle(.borderedProminent)
        }
    }
}
