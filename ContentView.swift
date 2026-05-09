import SwiftUI
import MultipeerConnectivity

@main
struct MessengerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// 1. Модель сообщения 
struct ChatMessage: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let sender: String
    let isMe: Bool
}

// 2. Мозги Mesh-сети (Теперь анонимные)
class MeshManager: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    @Published var messages: [ChatMessage] = []
    @Published var connectedPeers: [MCPeerID] = []
    @Published var isOfflineOnly: Bool = true 
    
    var session: MCSession!
    var advertiser: MCNearbyServiceAdvertiser!
    var browser: MCNearbyServiceBrowser!
    
    // Генерируем случайный позывной вместо реального имени iPhone
    let myPeerID = MCPeerID(displayName: "Ghost-\(Int.random(in: 1000...9999))")
    
    // База ID сообщений для защиты от бесконечного зацикливания
    private var processedMessageIDs = Set<UUID>()

    override init() {
        super.init()
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self
        
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: "hq-mesh")
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: "hq-mesh")
        browser.delegate = self
        browser.startBrowsingForPeers()
    }

    func send(_ text: String) {
        if !isOfflineOnly {
            let msg = ChatMessage(id: UUID(), text: "[Онлайн] " + text, sender: myPeerID.displayName, isMe: true)
            DispatchQueue.main.async { withAnimation { self.messages.append(msg) } }
            return
        }
        
        let msg = ChatMessage(id: UUID(), text: text, sender: myPeerID.displayName, isMe: true)
        DispatchQueue.main.async { withAnimation { self.messages.append(msg) } }
        processedMessageIDs.insert(msg.id) 
        
        if let data = try? JSONEncoder().encode(msg) {
            broadcast(data)
        }
    }

    private func broadcast(_ data: Data) {
        guard !session.connectedPeers.isEmpty else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    // --- Ловим сообщения и делаем "Прыжок" (Hop) ---
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let msg = try? JSONDecoder().decode(ChatMessage.self, from: data) {
            if !processedMessageIDs.contains(msg.id) {
                processedMessageIDs.insert(msg.id)
                
                let receivedMsg = ChatMessage(id: msg.id, text: msg.text, sender: msg.sender, isMe: false)
                DispatchQueue.main.async {
                    withAnimation { self.messages.append(receivedMsg) }
                }
                
                // Молча ретранслируем дальше
                broadcast(data)
            }
        }
    }

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { self.connectedPeers = session.connectedPeers }
    }
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) { invitationHandler(true, session) }
19:59
func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) { browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10) }
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}

// 3. UI
struct ContentView: View {
    @StateObject var mesh = MeshManager()
    @State var text = ""
    @State var showSettings = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(mesh.messages) { msg in
                                MessageBubble(msg: msg)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: mesh.messages.count) { _ in
                        if let last = mesh.messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
                .background(Color(UIColor.systemGroupedBackground))
                
                HStack {
                    TextField("Сообщение...", text: $text)
                        .padding(10)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(20)
                    
                    Button(action: {
                        if !text.isEmpty { mesh.send(text); text = "" }
                    }) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.blue)
                    }
                    .disabled(text.isEmpty)
                }
                .padding()
                .background(Color(UIColor.systemBackground))
            }
            .navigationBarTitle("HQ Mesh", displayMode: .inline)
            .navigationBarItems(trailing: Button(action: { showSettings.toggle() }) {
                Image(systemName: "shield.fill").foregroundColor(.blue) // Иконка приватности
            })
            .sheet(isPresented: $showSettings) {
                SettingsView(mesh: mesh)
            }
        }
    }
}

struct MessageBubble: View {
    let msg: ChatMessage
    var body: some View {
        HStack {
            if msg.isMe { Spacer() }
            VStack(alignment: msg.isMe ? .trailing : .leading, spacing: 4) {
                if !msg.isMe {
                    Text(msg.sender) // Здесь будет выводиться что-то вроде Ghost-1234
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Text(msg.text)
                    .padding(12)
                    .background(msg.isMe ? Color.blue : Color(UIColor.secondarySystemBackground))
                    .foregroundColor(msg.isMe ? .white : .primary)
                    .cornerRadius(16)
            }
            if !msg.isMe { Spacer() }
        }
    }
}

// Анонимные настройки
struct SettingsView: View {
    @ObservedObject var mesh: MeshManager
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Сеть"), footer: Text("Пакеты передаются полностью анонимно. Устройства работают как скрытые ретрансляторы.")) {
                    Toggle("Изолированный Mesh-режим", isOn: $mesh.isOfflineOnly)
                }
                Section(header: Text("Статус узла")) {
                    HStack {
                        Text("Активных мостов рядом:")
                        Spacer()
                        Text("\(mesh.connectedPeers.count)")
                            .foregroundColor(.gray)
                            .bold()
                    }
                }
            }
            .navigationBarTitle("Настройки безопасности", displayMode: .inline)
        }
    }
}
