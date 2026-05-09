import SwiftUI
import AVKit
import PhotosUI
import MultipeerConnectivity

@main
struct MessengerApp: App {
    var body: some Scene { WindowGroup { MainCoordinator() } }
}

enum MsgType: String, Codable { case text, image, video, voice }

struct Message: Identifiable, Codable, Hashable {
    let id: UUID; let text: String; let senderID: String; let type: MsgType; let url: String?; let isMe: Bool
}

class GlobalCore: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    @Published var messages: [Message] = []
    @Published var name = UserDefaults.standard.string(forKey: "u_name") ?? ""
    @Published var isOnline = false
    @Published var peersCount = 0
    @Published var incomingCall: String? = nil
    @Published var showUpdate = false
    @Published var isRecording = false
    
    let host = "elevation-strength-authentic.ngrok-free.dev"
    var ws: URLSessionWebSocketTask?
    var session: MCSession?
    var advertiser: MCNearbyServiceAdvertiser?
    var browser: MCNearbyServiceBrowser?
    var recorder: AVAudioRecorder?

    func setup(n: String) {
        guard !n.isEmpty else { return }
        self.name = n
        UserDefaults.standard.set(n, forKey: "u_name")
        
        let pid = MCPeerID(displayName: n)
        session = MCSession(peer: pid, securityIdentity: nil, encryptionPreference: .none)
        session?.delegate = self
        
        advertiser = MCNearbyServiceAdvertiser(peer: pid, discoveryInfo: nil, serviceType: "hq-mesh")
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        
        browser = MCNearbyServiceBrowser(peer: pid, serviceType: "hq-mesh")
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        
        connect()
    }

    func connect() {
        guard let url = URL(string: "wss://\(host)/ws") else { return }
        ws = URLSession.shared.webSocketTask(with: url)
        ws?.resume()
        sendPacket(["type": "register", "name": name])
        listen()
    }

    func listen() {
        ws?.receive { [weak self] res in
            guard let self = self, case .success(let msg) = res, case .string(let str) = msg,
                  let data = str.data(using: .utf8),
                  let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { self?.listen(); return }
            
            DispatchQueue.main.async {
                let t = j["type"] as? String ?? ""
                if t == "version_check" { self.showUpdate = true }
                else if t == "msg", let sID = j["senderID"] as? String, sID != self.name {
                    let m = Message(id: UUID(), text: j["text"] as? String ?? "", senderID: sID, type: MsgType(rawValue: j["msgType"] as? String ?? "text") ?? .text, url: j["url"] as? String, isMe: false)
                    if !self.messages.contains(where: { $0.id == m.id }) { self.messages.append(m) }
                } else if t == "offer", (j["target"] as? String) == self.name {
                    self.incomingCall = j["from"] as? String
                }
            }
            self.listen()
        }
    }

    func sendPacket(_ p: [String: Any]) {
        if let d = try? JSONSerialization.data(withJSONObject: p) { 
            ws?.send(.string(String(data: d, encoding: .utf8)!)) { _ in } 
        }
    }

    func send(txt: String = "", type: MsgType = .text, url: String? = nil) {
        let mID = UUID()
        let p: [String: Any] = ["type": "msg", "id": mID.uuidString, "senderID": name, "text": txt, "msgType": type.rawValue, "url": url ?? ""]
        
        DispatchQueue.main.async {
            let m = Message(id: mID, text: txt, senderID: self.name, type: type, url: url, isMe: true)
            self.messages.append(m)
            self.sendPacket(p)
            
            if let sess = self.session, !sess.connectedPeers.isEmpty, let d = try? JSONSerialization.data(withJSONObject: p) {
                try? sess.send(d, toPeers: sess.connectedPeers, with: .reliable)
            }
        }
    }

    func upload(data: Data, ext: String, type: MsgType) {
        let url = URL(string: "https://\(host)/upload")!
        var req = URLRequest(url: url); req.httpMethod = "POST"
        let b = UUID().uuidString
        req.setValue("multipart/form-data; boundary=\(b)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        body.append("--\(b)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"file.\(ext)\"\r\n\r\n".data(using: .utf8)!)
        body.append(data); body.append("\r\n--\(b)--\r\n".data(using: .utf8)!)
        
        URLSession.shared.uploadTask(with: req, from: body) { d, _, _ in
            if let d = d, let res = try? JSONDecoder().decode([String: String].self, from: d), let fUrl = res["url"] {
                DispatchQueue.main.async { self.send(type: type, url: fUrl) }
            }
        }.resume()
    }

    func startRecord() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default)
        try? session.setActive(true)
        
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("rec.m4a")
        let settings: [String: Any] = [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 12000.0, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue]
        
        recorder = try? AVAudioRecorder(url: url, settings: settings)
        recorder?.record()
        DispatchQueue.main.async { self.isRecording = true }
    }

    func stopRecord() {
        recorder?.stop()
        DispatchQueue.main.async { self.isRecording = false }
        if let url = recorder?.url, let data = try? Data(contentsOf: url) { upload(data: data, ext: "m4a", type: .voice) }
    }

    // MCSessionDelegate
    func session(_ s: MCSession, peer id: MCPeerID, didChange st: MCSessionState) { DispatchQueue.main.async { self.peersCount = s.connectedPeers.count } }
    func session(_ s: MCSession, didReceive d: Data, fromPeer id: MCPeerID) {
        if let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any], let sID = j["senderID"] as? String {
            DispatchQueue.main.async {
                let m = Message(id: UUID(uuidString: j["id"] as? String ?? "") ?? UUID(), text: j["text"] as? String ?? "", senderID: sID, type: .text, url: j["url"] as? String, isMe: false)
                if !self.messages.contains(where: { $0.id == m.id }) { self.messages.append(m) }
            }
        }
    }
    func advertiser(_ a: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer id: MCPeerID, withContext c: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) { invitationHandler(true, self.session) }
    func browser(_ b: MCNearbyServiceBrowser, foundPeer id: MCPeerID, withDiscoveryInfo i: [String : String]?) { 
        if let sess = self.session { b.invitePeer(id, to: sess, withContext: nil, timeout: 10) }
    }
    func session(_ s: MCSession, didReceive st: InputStream, withName n: String, fromPeer id: MCPeerID) {}
    func session(_ s: MCSession, didStartReceivingResourceWithName n: String, fromPeer id: MCPeerID, with p: Progress) {}
    func session(_ s: MCSession, didFinishReceivingResourceWithName n: String, fromPeer id: MCPeerID, at l: URL?, withError e: Error?) {}
    func browser(_ b: MCNearbyServiceBrowser, lostPeer id: MCPeerID) {}
}

struct MainCoordinator: View {
    @StateObject var core = GlobalCore()
    var body: some View {
        if core.name.isEmpty { RegistrationView(core: core) }
        else {
            NavigationView {
                VStack(spacing: 0) {
                    HStack {
                        Circle().fill(core.peersCount > 0 ? Color.blue : Color.gray).frame(width: 8, height: 8)
                        Text("Узлов в сети: \(core.peersCount)").font(.caption)
                        Spacer()
                        if core.isRecording { Text("ЗАПИСЬ...").foregroundColor(.red).font(.caption).bold() }
                    }.padding(8).background(Color(.secondarySystemBackground))
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 12) { ForEach(core.messages) { m in Bubble(m: m).id(m.id) } }.padding()
                        }.onChange(of: core.messages.count) { _ in proxy.scrollTo(core.messages.last?.id) }
                    }
                    InputBar(core: core)
                }
                .navigationTitle("HQ Global").navigationBarTitleDisplayMode(.inline)
            }
            .alert("Обновление!", isPresented: $core.showUpdate) {
                Button("Поставить v10.2") { if let u = URL(string: "itms-services://?action=download-manifest&url=https://\(core.host)/manifest.plist") { UIApplication.shared.open(u) } }
                Button("Позже", role: .cancel) {}
            }
            .onAppear { if !core.name.isEmpty { core.setup(n: core.name) } }
        }
    }
}

struct InputBar: View {
    @ObservedObject var core: GlobalCore; @State var txt = ""; @State var pick: PhotosPickerItem?
    var body: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $pick, matching: .images) { Image(systemName: "plus.circle.fill").font(.title) }
            .onChange(of: pick) { n in Task { if let d = try? await n?.loadTransferable(type: Data.self) { core.upload(data: d, ext: "jpg", type: .image) } } }
            
            TextField("Сообщение", text: $txt).padding(10).background(Color(.systemGray6)).cornerRadius(20)
            
            if txt.isEmpty {
                Image(systemName: "mic.fill")
                    .font(.title2).foregroundColor(core.isRecording ? .red : .blue)
                    .scaleEffect(core.isRecording ? 1.5 : 1.0)
                    .gesture(DragGesture(minimumDistance: 0).onChanged { _ in if !core.isRecording { core.startRecord() } }.onEnded { _ in core.stopRecord() })
            } else {
                Button(action: { core.send(txt: txt); txt = "" }) { Image(systemName: "arrow.up.circle.fill").font(.system(size: 32)) }
            }
        }.padding()
    }
}

struct Bubble: View {
    let m: Message
    var body: some View {
        HStack {
            if m.isMe { Spacer() }
            VStack(alignment: m.isMe ? .trailing : .leading) {
                Text(m.senderID).font(.caption2).foregroundColor(.gray)
                if let u = m.url {
                    if m.type == .image { AsyncImage(url: URL(string: u)) { i in i.resizable().scaledToFit() } placeholder: { ProgressView() }.frame(width: 200).cornerRadius(12) }
                    else if m.type == .voice { HStack { Image(systemName: "play.circle.fill"); Text("Голосовое") }.padding(12).background(Color.blue.opacity(0.2)).cornerRadius(18) }
                } else { Text(m.text).padding(12).background(m.isMe ? Color.blue : Color(.systemGray5)).foregroundColor(m.isMe ? .white : .primary).cornerRadius(18) }
            }
            if !m.isMe { Spacer() }
        }
    }
}

struct RegistrationView: View {
    @ObservedObject var core: GlobalCore; @State var n = ""
    var body: some View {
        VStack(spacing: 20) {
            Text("🛰").font(.system(size: 80))
            TextField("Твой ник", text: $n).textFieldStyle(.roundedBorder).padding()
            Button("Войти") { if !n.isEmpty { core.setup(n: n) } }.buttonStyle(.borderedProminent)
        }
    }
}
struct IdentifiableString: Identifiable { let id: String }
