import SwiftUI
import AVKit
import PhotosUI
import MultipeerConnectivity

@main
struct MessengerApp: App { var body: some Scene { WindowGroup { MainCoordinator() } } }

enum MsgType: String, Codable { case text, image, video, voice }
struct Message: Identifiable, Codable, Hashable { let id: UUID; let text: String; let senderID: String; let type: MsgType; let url: String?; let isMe: Bool }

class GlobalCore: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    @Published var messages: [Message] = []
    @Published var name = UserDefaults.standard.string(forKey: "u_name") ?? ""
    @AppStorage("ngrok_host") var host = "твой-адрес.ngrok-free.dev" // <--- МЕНЯЕТСЯ ИЗ ПРИЛОЖЕНИЯ
    @Published var peersCount = 0
    @Published var showUpdate = false
    @Published var showSettings = false
    var ws: URLSessionWebSocketTask?; var session: MCSession?; var adv: MCNearbyServiceAdvertiser?; var bro: MCNearbyServiceBrowser?

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
                if j["type"] as? String == "version_check" { self.showUpdate = true }
                else if j["type"] as? String == "msg", let sID = j["senderID"] as? String, sID != self.name {
                    let msg = Message(id: UUID(), text: j["text"] as? String ?? "", senderID: sID, type: MsgType(rawValue: j["msgType"] as? String ?? "text") ?? .text, url: j["url"] as? String, isMe: false)
                    if !self.messages.contains(where: { $0.id == msg.id }) { self.messages.append(msg) }
                }
            }
            self.listen()
        }
    }
    func sendPacket(_ p: [String: Any]) { if let d = try? JSONSerialization.data(withJSONObject: p) { ws?.send(.string(String(data: d, encoding: .utf8)!)) { _ in } } }
    func send(txt: String = "", type: MsgType = .text, url: String? = nil) {
        let p: [String: Any] = ["type": "msg", "senderID": name, "text": txt, "msgType": type.rawValue, "url": url ?? ""]
        DispatchQueue.main.async {
            self.messages.append(Message(id: UUID(), text: txt, senderID: self.name, type: type, url: url, isMe: true))
            self.sendPacket(p)
            if let sess = self.session, let d = try? JSONSerialization.data(withJSONObject: p) { try? sess.send(d, toPeers: sess.connectedPeers, with: .reliable) }
        }
    }
    // Функции Mesh (обязательные заглушки протокола)
    func session(_ s: MCSession, peer id: MCPeerID, didChange st: MCSessionState) { DispatchQueue.main.async { self.peersCount = s.connectedPeers.count } }
    func session(_ s: MCSession, didReceive d: Data, fromPeer id: MCPeerID) {
        if let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any], let sID = j["senderID"] as? String {
            DispatchQueue.main.async { self.messages.append(Message(id: UUID(), text: j["text"] as? String ?? "", senderID: sID, type: .text, url: nil, isMe: false)) }
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
            NavigationView {
                VStack(spacing: 0) {
                    HStack {
                        Circle().fill(core.peersCount > 0 ? Color.green : Color.gray).frame(width: 10, height: 10)
                        Text(core.peersCount > 0 ? "Mesh Активен (\(core.peersCount))" : "Только Сервер").font(.caption).foregroundColor(.gray)
                        Spacer()
                    }.padding(.horizontal).padding(.vertical, 5).background(Color(UIColor.systemGray6))
                    
                    ScrollView { VStack(spacing: 8) { ForEach(core.messages) { m in Bubble(m: m) } }.padding() }
                    InputBar(core: core)
                }
                .navigationTitle("TG Global").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button(action: { core.showSettings = true }) { Image(systemName: "gear") } }
                .sheet(isPresented: $core.showSettings) { SettingsView(core: core) }
            }
            .alert("Доступно обновление сервера!", isPresented: $core.showUpdate) {
                Button("Обновить") {
                    let cleanHost = core.host.replacingOccurrences(of: "https://", with: "")
                    if let u = URL(string: "itms-services://?action=download-manifest&url=https://\(cleanHost)/manifest.plist?user=\(core.name)") { UIApplication.shared.open(u) }
                }; Button("Отмена", role: .cancel) {}
            }
            .onAppear { core.setup(n: core.name) }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var core: GlobalCore
    @Environment(\.presentationMode) var pm
    @State var tempHost = ""
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Подключение к серверу (Ngrok)")) {
                    TextField("elevation-...ngrok-free.dev", text: $tempHost)
                    Button("Сохранить и перезайти") { core.host = tempHost; core.connect(); pm.wrappedValue.dismiss() }
                }
                Section(header: Text("Твой профиль")) { Text("Никнейм: \(core.name)") }
            }
            .navigationTitle("Настройки").onAppear { tempHost = core.host }
        }
    }
}

struct InputBar: View {
    @ObservedObject var core: GlobalCore; @State var txt = ""
    var body: some View {
        HStack {
            TextField("Сообщение...", text: $txt).padding(12).background(Color(UIColor.systemGray5)).cornerRadius(20)
            Button(action: { if !txt.isEmpty { core.send(txt: txt); txt = "" } }) { Image(systemName: "paperplane.circle.fill").font(.system(size: 32)).foregroundColor(.blue) }
        }.padding()
    }
}

struct Bubble: View {
    let m: Message
    var body: some View {
        HStack {
            if m.isMe { Spacer() }
            VStack(alignment: m.isMe ? .trailing : .leading, spacing: 2) {
                if !m.isMe { Text(m.senderID).font(.caption).foregroundColor(.blue).bold() }
                Text(m.text).padding(12).background(m.isMe ? Color.blue : Color(UIColor.systemGray5)).foregroundColor(m.isMe ? .white : .primary).cornerRadius(16)
            }
            if !m.isMe { Spacer() }
        }
    }
}

struct LoginView: View {
    @ObservedObject var core: GlobalCore; @State var n = ""
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "paperplane.fill").font(.system(size: 80)).foregroundColor(.blue)
            Text("TG Global").font(.title).bold()
            TextField("Твой ник (stepan, sergey, lena)", text: $n).textFieldStyle(.roundedBorder).padding(.horizontal, 40)
            Button("Войти") { if !n.isEmpty { core.setup(n: n) } }.buttonStyle(.borderedProminent)
        }
    }
}
