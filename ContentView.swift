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

// MARK: - ЯДРО СИСТЕМЫ
class GlobalCore: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    @Published var groupMessages: [Message] = []
    @Published var privateMessages: [String: [Message]] = [:] // Ник : Сообщения
    @Published var contacts: [String] = []
    @Published var name = UserDefaults.standard.string(forKey: "u_name") ?? ""
    @Published var isOnline = false
    @Published var incomingCall: String? = nil
    @Published var isRecordingVoice = false
    
    let host = "elevation-strength-authentic.ngrok-free.dev"
    var ws: URLSessionWebSocketTask?
    var session: MCSession!
    var audioRecorder: AVAudioRecorder?

    func setup(n: String) {
        self.name = n
        UserDefaults.standard.set(n, forKey: "u_name")
        let pid = MCPeerID(displayName: n)
        session = MCSession(peer: pid, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self
        MCNearbyServiceAdvertiser(peer: pid, discoveryInfo: nil, serviceType: "hq-mesh").startAdvertisingPeer()
        MCNearbyServiceBrowser(peer: pid, serviceType: "hq-mesh").startBrowsingForPeers()
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
                let from = json["senderID"] as? String ?? ""
                
                // Проверка на эхо (чтобы не звонить самому себе и не дублировать сообщения)
                if from == self.name { self.listen(); return }

                if type == "msg" {
                    let m = Message(id: UUID(uuidString: json["id"] as? String ?? "") ?? UUID(),
                                    text: json["text"] as? String ?? "",
                                    senderID: from,
                                    type: MsgType(rawValue: json["msgType"] as? String ?? "text") ?? .text,
                                    url: json["url"] as? String,
                                    isMe: false)
                    
                    // Убираем дубли по ID
                    if !self.groupMessages.contains(where: { $0.id == m.id }) {
                        self.groupMessages.append(m)
                    }
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
        }
    }

    // Загрузка медиа на Ryzen
    func upload(data: Data, ext: String, type: MsgType) {
        let url = URL(string: "https://\(host)/upload")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        let boundary = UUID().uuidString
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(UUID().uuidString).\(ext)\"\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        URLSession.shared.uploadTask(with: req, from: body) { data, _, _ in
            if let data = data, let res = try? JSONDecoder().decode([String: String].self, from: data), let fileUrl = res["url"] {
                DispatchQueue.main.async { self.send(type: type, media: fileUrl) }
            }
        }.resume()
    }

    // Mesh
    func session(_ s: MCSession, peer id: MCPeerID, didChange st: MCSessionState) { 
        DispatchQueue.main.async { if st == .connected && !self.contacts.contains(id.displayName) { self.contacts.append(id.displayName) } } 
    }
    func session(_ s: MCSession, didReceive d: Data, fromPeer id: MCPeerID) {}
    func advertiser(_ a: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer id: MCPeerID, withContext c: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) { invitationHandler(true, session) }
    func browser(_ b: MCNearbyServiceBrowser, foundPeer id: MCPeerID, withDiscoveryInfo i: [String : String]?) { b.invitePeer(id, to: session, withContext: nil, timeout: 10) }
    // Заглушки для протоколов
    func session(_ s: MCSession, didReceive stream: InputStream, withName n: String, fromPeer id: MCPeerID) {}
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
                ContactsView(core: core).tabItem { Label("Контакты", systemImage: "person.2.fill") }
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
    @State var pickerItem: PhotosPickerItem?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(core.groupMessages) { m in
                                Bubble(m: m).id(m.id)
                            }
                        }.padding()
                    }
                    .onChange(of: core.groupMessages.count) { _ in proxy.scrollTo(core.groupMessages.last?.id) }
                }
                
                HStack(spacing: 12) {
                    PhotosPicker(selection: $pickerItem, matching: .any(of: [.images, .videos])) {
                        Image(systemName: "paperclip").font(.title2)
                    }
                    .onChange(of: pickerItem) { newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                core.upload(data: data, ext: "dat", type: .image)
                            }
                        }
                    }
                    
                    TextField("Сообщение", text: $txt).padding(10).background(Color(.systemGray6)).cornerRadius(20)
                    
                    if txt.isEmpty {
                        Button(action: { /* Голосовой */ }) { Image(systemName: "mic.fill").font(.title2) }
                    } else {
                        Button(action: { core.send(txt: txt); txt = "" }) { Image(systemName: "arrow.up.circle.fill").font(.system(size: 32)) }
                    }
                }.padding()
            }
            .navigationTitle("HQ Global")
            .navigationBarTitleDisplayMode(.inline)
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
                
                if let url = m.url, m.type == .image {
                    AsyncImage(url: URL(string: url)) { img in img.resizable().scaledToFit() }
                    placeholder: { ProgressView() }.frame(width: 200).cornerRadius(12)
                } else if let url = m.url, m.type == .video {
                    VideoPlayer(player: AVPlayer(url: URL(string: url)!)).frame(width: 200, height: 200).cornerRadius(12)
                } else {
                    Text(m.text).padding(12).background(m.isMe ? Color.blue : Color(.systemGray5))
                        .foregroundColor(m.isMe ? .white : .primary).cornerRadius(18)
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
            List(core.contacts, id: \.self) { contact in
                HStack {
                    Image(systemName: "person.crop.circle.fill").font(.title)
                    Text(contact)
                    Spacer()
                    Button(action: { core.incomingCall = contact }) { Image(systemName: "video.fill") }
                }
            }.navigationTitle("Контакты")
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
