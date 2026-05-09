import SwiftUI
import AVKit
import PhotosUI
import MultipeerConnectivity

@main
struct MessengerApp: App {
    var body: some Scene { WindowGroup { MainCoordinator() } }
}

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

class GlobalCore: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    @Published var groupMessages: [Message] = []
    @Published var contacts: [String] = []
    @Published var name = UserDefaults.standard.string(forKey: "u_name") ?? ""
    @Published var isOnline = false
    @Published var incomingCall: String? = nil
    
    // OTA Переменные
    @Published var showUpdate = false
    @Published var newVersion = ""
    let currentAppVersion = "9.0"
    
    let host = "elevation-strength-authentic.ngrok-free.dev"
    var ws: URLSessionWebSocketTask?
    var session: MCSession!

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
                
                if type == "version_check", let v = json["version"] as? String, v != self.currentAppVersion {
                    self.newVersion = v
                    self.showUpdate = true
                }
                
                if from == self.name { self.listen(); return }

                if type == "msg" {
                    let m = Message(id: UUID(uuidString: json["id"] as? String ?? "") ?? UUID(), text: json["text"] as? String ?? "", senderID: from, type: MsgType(rawValue: json["msgType"] as? String ?? "text") ?? .text, url: json["url"] as? String, isMe: false)
                    if !self.groupMessages.contains(where: { $0.id == m.id }) { self.groupMessages.append(m) }
                } else if type == "offer" { self.incomingCall = from }
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
            try? session.send(d, toPeers: session.connectedPeers, with: .reliable) // ВОЗВРАЩАЕМ MESH
        }
    }

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

    // ВОССТАНОВЛЕННЫЙ ПРИЕМ MESH
    func session(_ s: MCSession, didReceive d: Data, fromPeer id: MCPeerID) {
        if let json = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
            DispatchQueue.main.async {
                let m = Message(id: UUID(uuidString: json["id"] as? String ?? "") ?? UUID(), text: json["text"] as? String ?? "", senderID: json["senderID"] as? String ?? id.displayName, type: MsgType(rawValue: json["msgType"] as? String ?? "text") ?? .text, url: json["url"] as? String, isMe: false)
                if !self.groupMessages.contains(where: { $0.id == m.id }) { self.groupMessages.append(m) }
            }
        }
    }
    
    func session(_ s: MCSession, peer id: MCPeerID, didChange st: MCSessionState) { DispatchQueue.main.async { if st == .connected && !self.contacts.contains(id.displayName) { self.contacts.append(id.displayName) } } }
    func advertiser(_ a: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer id: MCPeerID, withContext c: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) { invitationHandler(true, session) }
    func browser(_ b: MCNearbyServiceBrowser, foundPeer id: MCPeerID, withDiscoveryInfo i: [String : String]?) { b.invitePeer(id, to: session, withContext: nil, timeout: 10) }
    func session(_ s: MCSession, didReceive stream: InputStream, withName n: String, fromPeer id: MCPeerID) {}
    func session(_ s: MCSession, didStartReceivingResourceWithName n: String, fromPeer id: MCPeerID, with p: Progress) {}
    func session(_ s: MCSession, didFinishReceivingResourceWithName n: String, fromPeer id: MCPeerID, at l: URL?, withError e: Error?) {}
    func browser(_ b: MCNearbyServiceBrowser, lostPeer id: MCPeerID) {}
}

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
                Button("Установить по воздуху") {
                    if let u = URL(string: "itms-services://?action=download-manifest&url=https://\(core.host)/manifest.plist") { UIApplication.shared.open(u) }
                }
                Button("Отмена", role: .cancel) {}
            } message: { Text("Твой сервер раздает новое обновление.") }
            .fullScreenCover(item: Binding(get: { core.incomingCall.map { IdentifiableString(id: $0) } }, set: { _ in core.incomingCall = nil })) { call in
                CallView(name: call.id)
            }
        }
    }
}

// ... (Остальные Views: GlobalChatView, Bubble, ContactsView, CallView, RegistrationView остаются точно такими же, как в прошлом коде) ...
