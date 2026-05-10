import SwiftUI
import AVKit
import PhotosUI
import MultipeerConnectivity

@main
struct MessengerApp: App { var body: some Scene { WindowGroup { MainCoordinator() } } }

enum MsgType: String, Codable { case text, image, video, voice, call }
struct Message: Identifiable, Codable, Hashable { let id: UUID; let text: String; let senderID: String; let target: String; let isGroup: Bool; let type: MsgType; let url: String?; let isMe: Bool; let timestamp: Date }

// Модель Чата
struct Chat: Identifiable, Hashable {
    let id: String // Имя контакта или название группы
    let isGroup: Bool
    var messages: [Message]
    var lastMessage: String { messages.last?.text ?? (messages.last?.type == .voice ? "Голосовое сообщение" : "Медиа") }
}

class GlobalCore: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    @Published var chats: [String: Chat] = ["ОБЩИЙ ЧАТ": Chat(id: "ОБЩИЙ ЧАТ", isGroup: true, messages: [])]
    @Published var contacts: [String] = []
    @Published var name = UserDefaults.standard.string(forKey: "u_name") ?? ""
    @AppStorage("ngrok_host") var host = "твой-адрес.ngrok-free.dev"
    @Published var peersCount = 0
    @Published var isRecording = false
    
    var ws: URLSessionWebSocketTask?; var session: MCSession?; var adv: MCNearbyServiceAdvertiser?; var bro: MCNearbyServiceBrowser?; var recorder: AVAudioRecorder?

    func setup(n: String) {
        self.name = n.lowercased(); UserDefaults.standard.set(n, forKey: "u_name")
        let pid = MCPeerID(displayName: n)
        session = MCSession(peer: pid, securityIdentity: nil, encryptionPreference: .none); session?.delegate = self
        adv = MCNearbyServiceAdvertiser(peer: pid, discoveryInfo: nil, serviceType: "hq-mesh"); adv?.delegate = self; adv?.startAdvertisingPeer()
        bro = MCNearbyServiceBrowser(peer: pid, serviceType: "hq-mesh"); bro?.delegate = self; bro?.startBrowsingForPeers()
        connect()
    }
    
    func connect() {
        let cleanHost = host.replacingOccurrences(of: "https://", with: "")
        guard let url = URL(string: "wss://\(cleanHost)/ws") else { return }
        ws = URLSession.shared.webSocketTask(with: url); ws?.resume()
        sendPacket(["type": "register", "name": name]); listen()
    }
    
    func listen() {
        ws?.receive { [weak self] res in
            guard let self = self, case .success(let m) = res, case .string(let s) = m, let d = s.data(using: .utf8), let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { self?.listen(); return }
            DispatchQueue.main.async {
                let type = j["type"] as? String
                if type == "contacts", let users = j["users"] as? [String] {
                    self.contacts = users.filter { $0 != self.name }
                    for u in self.contacts where self.chats[u] == nil { self.chats[u] = Chat(id: u, isGroup: false, messages: []) }
                } else if type == "msg", let sID = j["senderID"] as? String, sID != self.name {
                    let target = j["target"] as? String ?? ""
                    let isGroup = j["isGroup"] as? Bool ?? false
                    let msg = Message(id: UUID(), text: j["text"] as? String ?? "", senderID: sID, target: target, isGroup: isGroup, type: MsgType(rawValue: j["msgType"] as? String ?? "text") ?? .text, url: j["url"] as? String, isMe: false, timestamp: Date())
                    
                    let chatKey = isGroup ? target : sID
                    if self.chats[chatKey] == nil { self.chats[chatKey] = Chat(id: chatKey, isGroup: isGroup, messages: []) }
                    self.chats[chatKey]?.messages.append(msg)
                }
            }
            self.listen()
        }
    }
    
    func sendPacket(_ p: [String: Any]) { if let d = try? JSONSerialization.data(withJSONObject: p) { ws?.send(.string(String(data: d, encoding: .utf8)!)) { _ in } } }
    
    func send(txt: String = "", type: MsgType = .text, url: String? = nil, target: String, isGroup: Bool) {
        let p: [String: Any] = ["type": "msg", "senderID": name, "target": target, "isGroup": isGroup, "text": txt, "msgType": type.rawValue, "url": url ?? ""]
        DispatchQueue.main.async {
            let msg = Message(id: UUID(), text: txt, senderID: self.name, target: target, isGroup: isGroup, type: type, url: url, isMe: true, timestamp: Date())
            if self.chats[target] == nil { self.chats[target] = Chat(id: target, isGroup: isGroup, messages: []) }
            self.chats[target]?.messages.append(msg)
            self.sendPacket(p)
            
            // Mesh отправка
            if let sess = self.session, let d = try? JSONSerialization.data(withJSONObject: p) { try? sess.send(d, toPeers: sess.connectedPeers, with: .reliable) }
        }
    }

    func uploadMedia(data: Data, ext: String, type: MsgType, target: String, isGroup: Bool) {
        let url = URL(string: "https://\(host)/upload")!; var req = URLRequest(url: url); req.httpMethod = "POST"
        let b = UUID().uuidString; req.setValue("multipart/form-data; boundary=\(b)", forHTTPHeaderField: "Content-Type")
        var body = Data(); body.append("--\(b)\r\n".data(using: .utf8)!); body.append("Content-Disposition: form-data; name=\"file\"; filename=\"file.\(ext)\"\r\n\r\n".data(using: .utf8)!); body.append(data); body.append("\r\n--\(b)--\r\n".data(using: .utf8)!)
        URLSession.shared.uploadTask(with: req, from: body) { d, _, _ in
            if let d = d, let res = try? JSONDecoder().decode([String: String].self, from: d), let fUrl = res["url"] {
                DispatchQueue.main.async { self.send(type: type, url: fUrl, target: target, isGroup: isGroup) }
            }
        }.resume()
    }

    // Голосовые
    func startVoice() {
        try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default); try? AVAudioSession.sharedInstance().setActive(true)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("rec.m4a")
        recorder = try? AVAudioRecorder(url: url, settings: [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 12000.0, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue]); recorder?.record()
        self.isRecording = true
    }
    func stopVoice(target: String, isGroup: Bool) {
        recorder?.stop(); self.isRecording = false
        if let u = recorder?.url, let d = try? Data(contentsOf: u) { uploadMedia(data: d, ext: "m4a", type: .voice, target: target, isGroup: isGroup) }
    }

    // Заглушки Mesh
    func session(_ s: MCSession, peer id: MCPeerID, didChange st: MCSessionState) { DispatchQueue.main.async { self.peersCount = s.connectedPeers.count } }
    func session(_ s: MCSession, didReceive d: Data, fromPeer id: MCPeerID) {
        if let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any], let sID = j["senderID"] as? String {
            let target = j["target"] as? String ?? ""; let isGroup = j["isGroup"] as? Bool ?? false
            // Если сообщение в группу, или адресовано МНЕ
            if isGroup || target == self.name {
                DispatchQueue.main.async {
                    let chatKey = isGroup ? target : sID
                    let msg = Message(id: UUID(), text: j["text"] as? String ?? "", senderID: sID, target: target, isGroup: isGroup, type: MsgType(rawValue: j["msgType"] as? String ?? "text") ?? .text, url: j["url"] as? String, isMe: false, timestamp: Date())
                    if self.chats[chatKey] == nil { self.chats[chatKey] = Chat(id: chatKey, isGroup: isGroup, messages: []) }
                    self.chats[chatKey]?.messages.append(msg)
                }
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
            TabView {
                ChatListView(core: core).tabItem { Label("Чаты", systemImage: "message.fill") }
                ContactsView(core: core).tabItem { Label("Контакты", systemImage: "person.2.fill") }
                SettingsView(core: core).tabItem { Label("Настройки", systemImage: "gearshape.fill") }
            }
            .onAppear { core.setup(n: core.name) }
        }
    }
}

// СПИСОК ЧАТОВ
struct ChatListView: View {
    @ObservedObject var core: GlobalCore
    var body: some View {
        NavigationView {
            List(Array(core.chats.values), id: \.id) { chat in
                NavigationLink(destination: ChatRoom(core: core, chatID: chat.id, isGroup: chat.isGroup)) {
                    HStack(spacing: 15) {
                        Circle().fill(chat.isGroup ? Color.blue : Color.green).frame(width: 50, height: 50)
                            .overlay(Text(String(chat.id.prefix(1).uppercased())).foregroundColor(.white).font(.title2).bold())
                        VStack(alignment: .leading, spacing: 5) {
                            Text(chat.id.uppercased()).font(.headline)
                            Text(chat.lastMessage).font(.subheadline).foregroundColor(.gray).lineLimit(1)
                        }
                    }
                }
            }
            .navigationTitle("Чаты")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { HStack { Circle().fill(core.peersCount>0 ? Color.green : Color.red).frame(width:10,height:10); Text(core.peersCount>0 ? "Mesh" : "Server").font(.caption).foregroundColor(.gray) } } }
        }
    }
}

// КОНТАКТЫ
struct ContactsView: View {
    @ObservedObject var core: GlobalCore
    var body: some View {
        NavigationView {
            List(core.contacts, id: \.self) { contact in
                NavigationLink(destination: ChatRoom(core: core, chatID: contact, isGroup: false)) {
                    HStack {
                        Circle().fill(Color.orange).frame(width: 40, height: 40)
                            .overlay(Text(String(contact.prefix(1).uppercased())).foregroundColor(.white).bold())
                        Text(contact.uppercased()).font(.headline)
                        Spacer()
                        Text("в сети").font(.caption).foregroundColor(.green)
                    }
                }
            }.navigationTitle("Контакты онлайн")
        }
    }
}

// КОМНАТА ЧАТА (ЛС ИЛИ ГРУППА)
struct ChatRoom: View {
    @ObservedObject var core: GlobalCore
    let chatID: String; let isGroup: Bool
    @State var txt = ""; @State var pick: PhotosPickerItem?
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        if let msgs = core.chats[chatID]?.messages { ForEach(msgs) { m in Bubble(m: m, isGroup: isGroup).id(m.id) } }
                    }.padding()
                }.onChange(of: core.chats[chatID]?.messages.count) { _ in proxy.scrollTo(core.chats[chatID]?.messages.last?.id) }
            }
            
            // Input Bar
            HStack(spacing: 12) {
                PhotosPicker(selection: $pick, matching: .images) { Image(systemName: "paperclip").font(.title2).foregroundColor(.gray) }
                .onChange(of: pick) { n in Task { if let d = try? await n?.loadTransferable(type: Data.self) { core.uploadMedia(data: d, ext: "jpg", type: .image, target: chatID, isGroup: isGroup) } } }
                
                TextField("Сообщение...", text: $txt).padding(10).background(Color(UIColor.systemGray6)).cornerRadius(20)
                
                if txt.isEmpty {
                    Image(systemName: "mic.fill").font(.title2).foregroundColor(core.isRecording ? .red : .blue)
                        .scaleEffect(core.isRecording ? 1.5 : 1.0).animation(.spring(), value: core.isRecording)
                        .gesture(DragGesture(minimumDistance: 0).onChanged { _ in if !core.isRecording { core.startVoice() } }.onEnded { _ in core.stopVoice(target: chatID, isGroup: isGroup) })
                } else {
                    Button(action: { core.send(txt: txt, target: chatID, isGroup: isGroup); txt = "" }) { Image(systemName: "arrow.up.circle.fill").font(.system(size: 32)).foregroundColor(.blue) }
                }
            }.padding()
        }
        .navigationTitle(chatID.uppercased())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            HStack {
                Button(action: { core.send(txt: "☎️ Входящий видеозвонок (В разработке)", type: .call, target: chatID, isGroup: isGroup) }) { Image(systemName: "video.fill") }
                Button(action: { core.send(txt: "📞 Входящий аудиозвонок (В разработке)", type: .call, target: chatID, isGroup: isGroup) }) { Image(systemName: "phone.fill") }
            }
        }
    }
}

// ПУЗЫРЬ СООБЩЕНИЯ
struct Bubble: View {
    let m: Message; let isGroup: Bool
    var body: some View {
        HStack {
            if m.isMe { Spacer() }
            VStack(alignment: m.isMe ? .trailing : .leading, spacing: 4) {
                if isGroup && !m.isMe { Text(m.senderID.uppercased()).font(.caption2).foregroundColor(.blue).bold() }
                
                if m.type == .call {
                    HStack { Image(systemName: "phone.arrow.down.left"); Text(m.text) }.padding(12).background(Color.green.opacity(0.2)).cornerRadius(12)
                } else if let u = m.url {
                    if m.type == .image { AsyncImage(url: URL(string: u)) { i in i.resizable().scaledToFit().cornerRadius(12) } placeholder: { ProgressView() }.frame(width: 220) }
                    else if m.type == .voice { HStack { Image(systemName: "play.circle.fill"); Text("Голосовое сообщение") }.padding(12).background(m.isMe ? Color.blue.opacity(0.8) : Color.gray.opacity(0.2)).foregroundColor(m.isMe ? .white : .primary).cornerRadius(16) }
                } else {
                    Text(m.text).padding(12).background(m.isMe ? Color.blue : Color(UIColor.systemGray5)).foregroundColor(m.isMe ? .white : .primary).cornerRadius(18)
                }
            }
            if !m.isMe { Spacer() }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var core: GlobalCore; @State var tempHost = ""
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Подключение к серверу (Ngrok)")) { TextField("elevation-...ngrok-free.dev", text: $tempHost); Button("Сохранить и перезайти") { core.host = tempHost; core.connect() } }
                Section(header: Text("Твой профиль")) { Text("Никнейм: \(core.name.uppercased())") }
                Section(header: Text("Сеть")) { Text("Узлов Mesh рядом: \(core.peersCount)").foregroundColor(core.peersCount > 0 ? .green : .gray) }
            }.navigationTitle("Настройки").onAppear { tempHost = core.host }
        }
    }
}

struct LoginView: View {
    @ObservedObject var core: GlobalCore; @State var n = ""
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "paperplane.fill").font(.system(size: 80)).foregroundColor(.blue)
            Text("TG Global").font(.largeTitle).bold()
            TextField("Твой ник (stepan, sergey, lena)", text: $n).textFieldStyle(.roundedBorder).padding(.horizontal, 40)
            Button("Войти") { if !n.isEmpty { core.setup(n: n) } }.buttonStyle(.borderedProminent).controlSize(.large)
        }
    }
}
