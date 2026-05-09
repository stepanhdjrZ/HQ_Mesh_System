import SwiftUI
import AVKit
import PhotosUI
import MultipeerConnectivity

@main
struct MessengerApp: App {
    var body: some Scene { WindowGroup { MainCoordinator() } }
}

// MARK: - МОДЕЛИ
enum MsgType: String, Codable { case text, image, video, circle, voice }

struct Message: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let senderID: String
    let type: MsgType
    let url: String?
    let isMe: Bool
}

struct IdentifiableString: Identifiable { let id: String }

// MARK: - ГЛОБАЛЬНОЕ ЯДРО
class GlobalCore: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    @Published var groupMessages: [Message] = []
    @Published var contacts: [String] = []
    @Published var name = UserDefaults.standard.string(forKey: "u_name") ?? ""
    @Published var isOnline = false
    @Published var peersCount = 0
    @Published var incomingCall: String? = nil
    @Published var showUpdate = false
    @Published var newVersion = ""
    
    let currentAppVersion = "9.0"
    let host = "elevation-strength-authentic.ngrok-free.dev" // ТВОЙ АДРЕС NGROK
    
    var ws: URLSessionWebSocketTask?
    var session: MCSession!
    var advertiser: MCNearbyServiceAdvertiser!
    var browser: MCNearbyServiceBrowser!

    func setup(n: String) {
        self.name = n
        UserDefaults.standard.set(n, forKey: "u_name")
        let pid = MCPeerID(displayName: n)
        session = MCSession(peer: pid, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self
        
        advertiser = MCNearbyServiceAdvertiser(peer: pid, discoveryInfo: nil, serviceType: "hq-mesh")
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        
        browser = MCNearbyServiceBrowser(peer: pid, serviceType: "hq-mesh")
        browser.delegate = self
        browser.startBrowsingForPeers()
        
        connect()
    }

    func connect() {
        guard let url = URL(string: "wss://\(host)/ws") else { return }
        ws = URLSession.shared.webSocketTask(with: url)
        ws?.resume()
        
        let reg = ["type": "register", "name": name]
        if let d = try? JSONSerialization.data(withJSONObject: reg) {
            ws?.send(.string(String(data: d, encoding: .utf8)!)) { _ in }
        }
        listen()
    }

    func listen() {
        ws?.receive { [weak self] res in
            guard let self = self, case .success(let msg) = res, case .string(let str) = msg,
                  let data = str.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { self?.listen(); return }
            
            DispatchQueue.main.async {
                let type = json["type"] as? String ?? ""
                if type == "version_check", let v = json["version"] as? String, v != self.currentAppVersion {
                    self.newVersion = v
                    self.showUpdate = true
                }
                
                let from = json["senderID"] as? String ?? ""
                if from == self.name { self.listen(); return }

                if type == "msg" {
                    let m = Message(id: UUID(uuidString: json["id"] as? String ?? "") ?? UUID(),
                                    text: json["text"] as? String ?? "",
                                    senderID: from,
                                    type: MsgType(rawValue: json["msgType"] as? String ?? "text") ?? .text,
                                    url: json["url"] as? String,
                                    isMe: false)
                    if !self.groupMessages.contains(where: { $0.id == m.id }) { self.groupMessages.append(m) }
                } else if type == "offer" {
                    self.incomingCall = from
                }
            }
            self.listen()
        }
    }

    func send(txt: String = "", type: MsgType = .text, media: String? = nil) {
        let mID = UUID()
        let m = Message(id: mID, text: txt, senderID: name, type: type, url: media, isMe: true)
        groupMessages.append(m)
        
        let packet: [String: Any] = ["type": "msg", "id": mID.uuidString, "senderID": name, "text": txt, "msgType": type.rawValue, "url": media ?? ""]
        if let d = try? JSONSerialization.data(withJSONObject: packet) {
            ws?.send(.string(String(data: d, encoding: .utf8)!)) { _ in }
            try? session.send(d, toPeers: session.connectedPeers, with: .reliable)
        }
    }

    func upload(data: Data, ext: String, type: MsgType) {
        let url = URL(string: "https://\(host)/upload")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        let b = UUID().uuidString
        req.setValue("multipart/form-data; boundary=\(b)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        body.append("--\(b)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(UUID().uuidString).\(ext)\"\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(b)--\r\n".data(using: .utf8)!)
        URLSession.shared.uploadTask(with: req, from: body) { data, _, _ in
            if let data = data, let res = try? JSONDecoder().decode([String: String].self, from: data), let fileUrl = res["url"] {
                DispatchQueue.main.async { self.send(type: type, media: fileUrl) }
            }
        }.resume()
    }

    // MESH LOGIC
    func session(_ s: MCSession, peer id: MCPeerID, didChange st: MCSessionState) { 
        DispatchQueue.main.async { 
            self.peersCount = s.connectedPeers.count
            self.isOnline = (st == .connected)
            if st == .connected && !self.contacts.contains(id.displayName) { self.contacts.append(id.displayName) }
        } 
    }
    func session(_ s: MCSession, didReceive d: Data, fromPeer id: MCPeerID) {
        if let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
            DispatchQueue.main.async {
                let m = Message(id: UUID(uuidString: j["id"] as? String ?? "") ?? UUID(), text: j["text"] as? String ?? "", senderID: j["senderID"] as? String ?? id.displayName, type: MsgType(rawValue: j["msgType"] as? String ?? "text") ?? .text, url: j["url"] as? String, isMe: false)
                if !self.groupMessages.contains(where: { $0.id == m.id }) { self.groupMessages.append(m) }
            }
        }
    }
    func advertiser(_ a: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer id: MCPeerID, withContext c: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) { invitationHandler(true, session) }
    func browser(_ b: MCNearbyServiceBrowser, foundPeer id: MCPeerID, withDiscoveryInfo i: [String : String]?) { b.invitePeer(id, to: session, withContext: nil, timeout: 10) }
    func session(_ s: MCSession, didReceive st: InputStream, withName n: String, fromPeer id: MCPeerID) {}
    func session(_ s: MCSession, didStartReceivingResourceWithName n: String, fromPeer id: MCPeerID, with p: Progress) {}
    func session(_ s: MCSession, didFinishReceivingResourceWithName n: String, fromPeer id: MCPeerID, at l: URL?, withError e: Error?) {}
    func browser(_ b: MCNearbyServiceBrowser, lostPeer id: MCPeerID) {}
}

// MARK: - ИНТЕРФЕЙС
struct MainCoordinator: View {
    @StateObject var core = GlobalCore()
    var body: some View {
        if core.name.isEmpty { RegistrationView(core: core) }
        else {
            TabView {
                GlobalChatView(core: core).tabItem { Label("Чат", systemImage: "bubble.left.and.bubble.right.fill") }
                ContactsView(core: core).tabItem { Label("Mesh-Узлы", systemImage: "network") }
            }
            .alert("Доступна v\(core.newVersion)!", isPresented: $core.showUpdate) {
                Button("Обновить по воздуху") {
                    if let u = URL(string: "itms-services://?action=download-manifest&url=https://\(core.host)/manifest.plist") { UIApplication.shared.open(u) }
                }
                Button("Позже", role: .cancel) {}
            }
            .fullScreenCover(item: Binding(get: { core.incomingCall.map { IdentifiableString(id: $0) } }, set: { _ in core.incomingCall = nil })) { call in
                CallView(name: call.id)
            }
        }
    }
}

struct GlobalChatView: View {
    @ObservedObject var core: GlobalCore
    @State var txt = ""
    @State var picker: PhotosPickerItem?
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack {
                    Circle().fill(core.isOnline ? Color.blue : Color.red).frame(width: 8, height: 8)
                    Text(core.isOnline ? "Cloud" : "Mesh Only").font(.caption)
                    Spacer()
                    Text("Узлов: \(core.peersCount)").font(.caption)
                }.padding().background(Color(.secondarySystemBackground))
                
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(core.groupMessages) { m in Bubble(m: m).id(m.id) }
                        }.padding()
                    }.onChange(of: core.groupMessages.count) { _ in proxy.scrollTo(core.groupMessages.last?.id) }
                }
                HStack(spacing: 12) {
                    PhotosPicker(selection: $picker, matching: .any(of: [.images, .videos])) { Image(systemName: "paperclip").font(.title2) }
                    .onChange(of: picker) { n in Task { if let d = try? await n?.loadTransferable(type: Data.self) { core.upload(data: d, ext: "dat", type: .image) } } }
                    TextField("Сообщение", text: $txt).padding(10).background(Color(.systemGray6)).cornerRadius(20)
                    Button(action: { core.send(txt: txt); txt = "" }) { Image(systemName: "arrow.up.circle.fill").font(.system(size: 32)) }.disabled(txt.isEmpty)
                }.padding()
            }.navigationTitle("HQ Global").navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct Bubble: View {
    let m: Message
    var body: some View {
        HStack {
            if m.isMe { Spacer() }
            VStack(alignment: m.isMe ? .trailing : .leading) {
                Text(m.senderID).font(.caption2).foregroundColor(.gray)
                if let u = m.url, m.type == .image {
                    AsyncImage(url: URL(string: u)) { i in i.resizable().scaledToFit() } placeholder: { ProgressView() }.frame(width: 200).cornerRadius(12)
                } else if let u = m.url, m.type == .video {
                    VideoPlayer(player: AVPlayer(url: URL(string: u)!)).frame(width: 200, height: 200).cornerRadius(12)
                } else {
                    Text(m.text).padding(12).background(m.isMe ? Color.blue : Color(.systemGray5)).foregroundColor(m.isMe ? .white : .primary).cornerRadius(18)
                }
            }
            if !m.isMe { Spacer() }
        }
    }
}

struct ContactsView: View {
    @ObservedObject var core: GlobalCore
    var body: some View {
        NavigationView {
            List(core.contacts, id: \.self) { c in
                HStack {
                    Text(c); Spacer()
                    Button(action: { core.incomingCall = c }) { Image(systemName: "video.fill") }
                }
            }.navigationTitle("Mesh-Узлы")
        }
    }
}

struct CallView: View {
    let name: String
    @Environment(\.dismiss) var dismiss
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            VStack {
                Text("ВИДЕОЗВОНОК").foregroundColor(.gray)
                Text(name).font(.largeTitle).bold().foregroundColor(.white)
                Spacer()
                HStack(spacing: 60) {
                    Button(action: { dismiss() }) { Circle().fill(.red).frame(width: 75).overlay(Image(systemName: "phone.down.fill").foregroundColor(.white)) }
                    Button(action: { dismiss() }) { Circle().fill(.green).frame(width: 75).overlay(Image(systemName: "phone.fill").foregroundColor(.white)) }
                }
            }.padding(.vertical, 100)
        }
    }
}

struct RegistrationView: View {
    @ObservedObject var core: GlobalCore
    @State var n = ""
    var body: some View {
        VStack(spacing: 20) {
            Text("🛰").font(.system(size: 80))
            TextField("Твой ник", text: $n).textFieldStyle(.roundedBorder).padding()
            Button("Войти") { if !n.isEmpty { core.setup(n: n) } }.buttonStyle(.borderedProminent)
        }
    }
}
