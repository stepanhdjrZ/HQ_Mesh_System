import Foundation
import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isMe: Bool
}

class MeshNetworkManager: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var messages: [ChatMessage] = []
    private var webSocket: URLSessionWebSocketTask?
    
    override init() {
        super.init()
        connectToRyzen()
    }
    
    func connectToRyzen() {
        // 🔥 ГЛОБАЛЬНЫЙ СЕРВЕР HQ MESH 🔥
        // wss:// означает защищенный WebSocket (работает через Cloudflare)
        let url = URL(string: "wss://hq-mesh.site/ws")!
        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()
        
        // Автоматически берем имя айфона (например "iPhone 15 Pro Max Степана")
        let deviceName = UIDevice.current.name
        let registerMsg = "{\"type\": \"register\", \"name\": \"\(deviceName)\"}"
        
        webSocket?.send(.string(registerMsg)) { error in
            if error == nil {
                DispatchQueue.main.async { self.isConnected = true }
                self.listen()
            }
        }
    }
    
    func sendMessage(_ text: String) {
        let msgJSON = "{\"type\": \"msg\", \"text\": \"\(text)\"}"
        webSocket?.send(.string(msgJSON)) { _ in 
            DispatchQueue.main.async {
                self.messages.append(ChatMessage(text: text, isMe: true))
            }
        }
    }
    
    private func listen() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let msg):
                if case .string(let text) = msg { self?.parse(text) }
                self?.listen() // Продолжаем слушать после успеха
                
            case .failure: 
                DispatchQueue.main.async { self?.isConnected = false }
                // 🛡 ЗАЩИТА ОТ РАЗРЫВОВ (ПЕРЕПОДКЛЮЧЕНИЕ ЧЕРЕЗ 3 СЕКУНДЫ)
                DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) {
                    self?.connectToRyzen()
                }
                return
            }
        }
    }
    
    private func parse(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String, type == "msg",
              let msgText = json["text"] as? String else { return }
        
        DispatchQueue.main.async {
            // Проверяем, не наше ли это сообщение, чтобы не дублировать
            if self.messages.last?.text != msgText {
                self.messages.append(ChatMessage(text: msgText, isMe: false))
            }
        }
    }
}
