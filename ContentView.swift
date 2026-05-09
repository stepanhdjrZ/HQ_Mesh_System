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

// MARK: - ГИБРИДНОЕ ЯДРО
class GlobalCore: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    @Published var messages: [Message] = []
    @Published var name = UserDefaults.standard.string(forKey: "u_name") ?? ""
    @Published var isOnline = false
    @Published var peersCount = 0
    @Published var incomingCall: String? = nil
    
    let host = "elevation-strength-authentic.ngrok-free.dev"
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
                if type == "msg" {
                    if let sID = json["senderID"] as? String, sID != self.name {
                        let m = Message(id: UUID(), text: json["text"] as? String ?? "", senderID: sID, type: MsgType(rawValue: json["msgType"] as? String ?? "text") ?? .text, url: json["url"] as? String, isMe: false)
                        self.messages.append(m)
                    }
                } else if type == "offer" {
                    self.incomingCall = json["from"] as? String
                }
            }
            self.listen()
        }
    }

    func send(txt: String = "", type: MsgType = .text, media: String? = nil) {
        let m = Message(id: UUID(), text: txt, senderID: name, type: type, url: media, isMe: true)
        messages.append(m)
        
        let packet: [String: Any] = ["type": "msg", "senderID": name, "text": txt, "msgType": type.rawValue, "url": media ?? ""]
        if let d = try? JSONSerialization.data(withJSONObject: packet) {
            let str = String(data: d, encoding: .utf8)!
            ws?.send(.string(str)) { _ in }
            try? session.send(d, toPeers: session.connectedPeers, with: .reliable)
        }
    }

    func call(target: String) {
        let p = ["type": "offer", "from": name, "target": target]
        if let d = try? JSONSerialization.data(withJSONObject: p) {
            ws?.send(.string(String(data: d, encoding: .utf8)!)) { _ in }
        }
    }
    
    // MCSessionDelegate
    func session(_ s: MCSession, peer id: MCPeerID, didChange st: MCSessionState) { 
        DispatchQueue.main.async { self.peersCount = s.connectedPeers.count; self.isOnline = (st == .connected) } 
    }
    func session(_ s: MCSession, didReceive d: Data, fromPeer id: MCPeerID) {
        if let json = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
           let sID = json["senderID"] as? String {
            DispatchQueue.main.async {
                let m = Message(id: UUID(), text: json["text"] as? String ?? "", senderID: sID, type: MsgType(rawValue: json["msgType"] as? String ?? "text") ?? .text, url: json["url"] as? String, isMe: false)
                self.messages.append(m)
            }
        }
    }
    func session(_ s: MCSession, didReceive stream: InputStream, withName n: String, fromPeer id: MCPeerID) {}
    func session(_ s: MCSession, didStartReceivingResourceWithName n: String, fromPeer id: MCPeerID, with p: Progress) {}
    func session(_ s: MCSession, didFinishReceivingResourceWithName n: String, fromPeer id: MCPeerID, at l: URL?, withError e: Error?) {}
    func advertiser(_ a: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer id: MCPeerID, withContext c: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) { invitationHandler(true, session) }
    func browser(_ b: MCNearbyServiceBrowser, foundPeer id: MCPeerID, withDiscoveryInfo i: [String : String]?) { b.invitePeer(id, to: session, withContext: nil, timeout: 10) }
    func browser(_ b: MCNearbyServiceBrowser, lostPeer id: MCPeerID) {}
}

// MARK: - ИНТЕРФЕЙС
struct MainCoordinator: View {
    @StateObject var core = GlobalCore()
    var body: some View {
        NavigationView {
            if core.name.isEmpty { RegistrationView(core: core) }
            else { ChatView(core: core) }
        }
        .fullScreenCover(item: Binding(get: { core.incomingCall.map { IdentifiableString(id: $0) } }, set: { _ in core.incomingCall = nil })) { call in
            CallView(name: call.id)
        }
    }
}

struct ChatView: View {
    @ObservedObject var core: GlobalCore
    @State var txt = ""
    var body: some View {
        VStack(spacing: 0) {
            // Status Bar
            HStack {
                Circle().fill(core.isOnline ? Color.blue : Color.red).frame(width: 8, height: 8)
                Text(core.isOnline ? "Cloud Active" : "Mesh Mode").font(.caption)
                Spacer()
                Text("Узлов: \(core.peersCount)").font(.caption)
            }.padding().background(Color(.secondarySystemBackground))
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 15) {
                        ForEach(core.messages) { m in
                            Bubble(m: m).id(m.id)
                        }
                    }.padding()
                }
                .onChange(of: core.messages.count) { _ in withAnimation { proxy.scrollTo(core.messages.last?.id) } }
            }
            
            HStack(spacing: 12) {
                Button(action: { core.call(target: "Papa") }) { Image(systemName: "video.fill").font(.title2) }
                TextField("Сообщение", text: $txt).padding(10).background(Color(.systemGray6)).cornerRadius(20)
                Button(action: { if !txt.isEmpty { core.send(txt: txt); txt = "" } }) { Image(systemName: "arrow.up.circle.fill").font(.system(size: 32)) }
            }.padding()
        }
        .navigationTitle("HQ Global")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { core.setup(n: core.name) }
    }
}

struct Bubble: View {
    let m: Message
    var body: some View {
        HStack {
            if m.isMe { Spacer() }
            VStack(alignment: m.isMe ? .trailing : .leading) {
                if m.type == .circle, let url = m.url {
                    VideoPlayer(player: AVPlayer(url: URL(string: url)!))
                        .frame(width: 200, height: 200).clipShape(Circle())
                } else {
                    Text(m.text).padding(12).background(m.isMe ? Color.blue : Color(.systemGray5))
                        .foregroundColor(m.isMe ? .white : .primary).cornerRadius(18)
                }
            }
            if !m.isMe { Spacer() }
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
                    Button(action: { dismiss() }) { Circle().fill(.red).frame(width: 75).overlay(Image(systemName: "phone.down.fill").foregroundColor(.white).font(.title)) }
                    Button(action: { }) { Circle().fill(.green).frame(width: 75).overlay(Image(systemName: "phone.fill").foregroundColor(.white).font(.title)) }
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
            TextField("Никнейм", text: $n).textFieldStyle(.roundedBorder).padding()
            Button("Войти") { if !n.isEmpty { core.setup(n: n) } }.buttonStyle(.borderedProminent)
        }
    }
}
