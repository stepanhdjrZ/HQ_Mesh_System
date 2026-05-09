import SwiftUI
import PhotosUI
import AVFoundation

@main
struct MessengerApp: App {
    var body: some Scene { WindowGroup { MainCoordinator() } }
}

// MARK: - МОДЕЛИ
struct Message: Identifiable, Codable {
    let id: UUID
    let text: String
    let senderID: String
    let type: MsgType
    let mediaURL: String?
    let isMe: Bool
}

enum MsgType: String, Codable { case text, image, voice }

// MARK: - ЯДРО
class GlobalCore: NSObject, ObservableObject {
    @Published var messages: [Message] = []
    @Published var isOnline = false
    @Published var name = UserDefaults.standard.string(forKey: "u_name") ?? ""
    @Published var showUpdate = false
    
    var ws: URLSessionWebSocketTask?
    let host = "elevation-strength-authentic.ngrok-free.dev" // ТВОЙ АДРЕС
    let currentVersion = "7.0"

    func setup(userName: String) {
        self.name = userName
        UserDefaults.standard.set(userName, forKey: "u_name")
        connect()
    }

    func connect() {
        guard let url = URL(string: "wss://\(host)/ws") else { return }
        ws = URLSession.shared.webSocketTask(with: url)
        ws?.resume()
        listen()
    }

    func listen() {
        ws?.receive { [weak self] res in
            guard let self = self, case .success(let msg) = res, case .string(let str) = msg,
                  let data = str.data(using: .utf8),
                  let m = try? JSONDecoder().decode(Message.self, from: data) else { self?.listen(); return }
            
            DispatchQueue.main.async { if !m.isMe { self.messages.append(m) } }
            self.listen()
        }
    }

    func send(text: String = "", type: MsgType = .text, url: String? = nil) {
        let m = Message(id: UUID(), text: text, senderID: name, type: type, mediaURL: url, isMe: true)
        messages.append(m)
        if let d = try? JSONEncoder().encode(m) { ws?.send(.string(String(data: d, encoding: .utf8)!)) { _ in } }
    }

    func uploadMedia(data: Data, ext: String) {
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
            if let data = data, let res = try? JSONDecoder().decode([String: String].self, from: data) {
                DispatchQueue.main.async { self.send(type: ext == "m4a" ? .voice : .image, url: res["url"]) }
            }
        }.resume()
    }
}

// MARK: - ИНТЕРФЕЙС (TG Style)
struct MainCoordinator: View {
    @StateObject var core = GlobalCore()
    @State var pickerItem: PhotosPickerItem?
    
    var body: some View {
        NavigationView {
            if core.name.isEmpty { RegistrationView(core: core) }
            else {
                VStack(spacing: 0) {
                    // Chat List
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 15) {
                                ForEach(core.messages) { m in
                                    MessageBubble(m: m)
                                }
                            }.padding()
                        }
                        .onChange(of: core.messages.count) { _ in withAnimation { proxy.scrollTo(core.messages.last?.id) } }
                    }
                    
                    // Input Bar
                    HStack(spacing: 15) {
                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            Image(systemName: "paperclip").font(.title2).foregroundColor(.blue)
                        }
                        .onChange(of: pickerItem) { newItem in
                            Task { if let data = try? await newItem?.loadTransferable(type: Data.self) { core.uploadMedia(data: data, ext: "jpg") } }
                        }
                        
                        TextField("Сообщение", text: .constant("")).padding(10).background(Color(.systemGray6)).cornerRadius(20)
                        
                        Image(systemName: "mic.fill").font(.title2).foregroundColor(.blue)
                    }.padding().background(Color(.systemBackground))
                }
                .navigationTitle("HQ Global")
                .navigationBarTitleDisplayMode(.inline)
            }
        }.onAppear { if !core.name.isEmpty { core.setup(userName: core.name) } }
    }
}

struct MessageBubble: View {
    let m: Message
    var body: some View {
        HStack {
            if m.isMe { Spacer() }
            VStack(alignment: m.isMe ? .trailing : .leading, spacing: 4) {
                if !m.isMe { Text(m.senderID).font(.caption2).foregroundColor(.gray).padding(.leading, 5) }
                
                VStack(alignment: .leading, spacing: 0) {
                    if m.type == .image, let url = m.mediaURL {
                        AsyncImage(url: URL(string: url)) { img in
                            img.resizable().scaledToFill()
                        } placeholder: { ProgressView() }
                        .frame(width: 200, height: 200).cornerRadius(12).padding(4)
                    }
                    
                    if m.type == .voice {
                        HStack {
                            Image(systemName: "play.fill")
                            Capsule().fill(Color.gray.opacity(0.3)).frame(width: 100, height: 4)
                            Text("0:05").font(.caption2)
                        }.padding(12)
                    }
                    
                    if !m.text.isEmpty {
                        Text(m.text).padding(12)
                    }
                }
                .background(m.isMe ? Color.blue : Color(.systemGray5))
                .foregroundColor(m.isMe ? .white : .primary)
                .cornerRadius(18)
            }
            if !m.isMe { Spacer() }
        }
    }
}

struct RegistrationView: View {
    @ObservedObject var core: GlobalCore
    @State var n = ""
    var body: some View {
        VStack {
            TextField("Твой ник", text: $n).textFieldStyle(.roundedBorder).padding()
            Button("Войти") { core.setup(userName: n) }.buttonStyle(.borderedProminent)
        }
    }
}
