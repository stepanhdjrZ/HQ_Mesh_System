import SwiftUI
import AVKit
import PhotosUI

// MARK: - ТИПЫ ДАННЫХ
enum MsgType: String, Codable { case text, image, video, voice, circle }

struct Message: Identifiable, Codable {
    let id: UUID
    let text: String
    let senderID: String
    let type: MsgType
    let mediaURL: String?
    let isMe: Bool
}

// MARK: - ЯДРО С ПОДДЕРЖКОЙ ЗВОНКОВ
class GlobalCore: NSObject, ObservableObject {
    @Published var messages: [Message] = []
    @Published var incomingCallFrom: String? = nil
    @Published var isCalling = false
    
    let host = "elevation-strength-authentic.ngrok-free.dev"
    var ws: URLSessionWebSocketTask?

    func sendSignaling(_ type: String, target: String, data: String) {
        let packet: [String: String] = ["type": type, "target": target, "data": data, "from": UserDefaults.standard.string(forKey: "u_name") ?? ""]
        if let d = try? JSONEncoder().encode(packet) { ws?.send(.string(String(data: d, encoding: .utf8)!)) { _ in } }
    }

    // ЛОГИКА ВИДЕО И КРУЖОЧКОВ
    func sendMedia(data: Data, type: MsgType) {
        let ext = (type == .video || type == .circle) ? "mp4" : "jpg"
        // Тут вызываем наш метод upload из v7.0 и шлем сообщение с типом type
    }
    
    func startVideoCall(to: String) {
        isCalling = true
        sendSignaling("offer", target: to, data: "init_video_call")
    }
}

// MARK: - ИНТЕРФЕЙС
struct ChatView: View {
    @ObservedObject var core: GlobalCore
    @State var showMediaPicker = false
    
    var body: some View {
        VStack {
            // Список сообщений
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(core.messages) { m in
                        MessageBubble(m: m)
                    }
                }.padding()
            }
            
            // ПАНЕЛЬ ВВОДА (Кружочки + Видео + Звонки)
            HStack(spacing: 15) {
                Button(action: { /* звонок */ }) {
                    Image(systemName: "phone.fill").font(.title3)
                }
                
                Button(action: { showMediaPicker = true }) {
                    Image(systemName: "plus.circle.fill").font(.title2)
                }
                
                TextField("Сообщение", text: .constant("")).padding(10).background(Color(.systemGray6)).cornerRadius(20)
                
                // КНОПКА ДЛЯ КРУЖОЧКОВ (при долгом нажатии)
                Button(action: {}) {
                    Image(systemName: "camera.fill").font(.title3)
                }
            }.padding()
        }
        .navigationTitle("HQ Global")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Видеозвонок") { core.startVideoCall(to: "Papa") }
            }
        }
        .sheet(isPresented: Binding(get: { core.incomingCallFrom != nil }, set: { _ in core.incomingCallFrom = nil })) {
            IncomingCallView(core: core)
        }
    }
}

struct MessageBubble: View {
    let m: Message
    var body: some View {
        HStack {
            if m.isMe { Spacer() }
            
            VStack(alignment: m.isMe ? .trailing : .leading) {
                if m.type == .circle, let url = m.mediaURL {
                    // КРУЖОЧЕК
                    VideoPlayer(player: AVPlayer(url: URL(string: url)!))
                        .frame(width: 200, height: 200)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.blue, lineWidth: 2))
                } else if m.type == .video, let url = m.mediaURL {
                    // ВИДЕО
                    VideoPlayer(player: AVPlayer(url: URL(string: url)!))
                        .frame(width: 250, height: 150)
                        .cornerRadius(12)
                } else {
                    // ТЕКСТ / ФОТО
                    Text(m.text).padding(12).background(m.isMe ? Color.blue : Color.gray.opacity(0.2)).cornerRadius(15)
                }
            }
            
            if !m.isMe { Spacer() }
        }
    }
}

struct IncomingCallView: View {
    @ObservedObject var core: GlobalCore
    var body: some View {
        VStack(spacing: 50) {
            Text("Входящий звонок от").font(.headline)
            Text(core.incomingCallFrom ?? "Неизвестно").font(.largeTitle).bold()
            
            HStack(spacing: 100) {
                Button("Сбросить") { core.incomingCallFrom = nil }.foregroundColor(.red)
                Button("Принять") { /* Запуск WebRTC */ }.foregroundColor(.green)
            }.font(.title2)
        }
    }
}
