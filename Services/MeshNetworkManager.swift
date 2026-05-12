import Foundation
import SwiftUI

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isMe: Bool
    let partnerId: String // С кем переписываемся
}

class MeshNetworkManager: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var messages: [ChatMessage] = []
    
    // Твой уникальный ID (генерируется один раз и сохраняется)
    @Published var myHQID: String = ""
    
    private var webSocket: URLSessionWebSocketTask?
    
    override init() {
        super.init()
        // Достаем ID из памяти телефона или создаем новый (например, HQ-8493)
        if let savedID = UserDefaults.standard.string(forKey: "myHQID") {
            self.myHQID = savedID
        } else {
            let newID = "HQ-\(Int.random(in: 1000...9999))"
            UserDefaults.standard.set(newID, forKey: "myHQID")
            self.myHQID = newID
        }
        connectToHQ()
    }
    
    func connectToHQ() {
        let url = URL(string: "wss://hq-mesh.site/ws")!
        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()
        
        let registerMsg = "{\"type\": \"register\", \"my_id\": \"\(myHQID)\"}"
        webSocket?.send(.string(registerMsg)) { error in
            if error == nil {
                DispatchQueue.main.async { self.isConnected = true }
                self.listen()
            }
        }
    }
    
    // Отправка конкретному контакту (по его ID)
    func sendMessage(to targetID: String, text: String) {
        let msgJSON = "{\"type\": \"private_msg\", \"to_id\": \"\(targetID)\", \"text\": \"\(text)\"}"
        webSocket?.send(.string(msgJSON)) { _ in
            DispatchQueue.main.async {
                self.messages.append(ChatMessage(text: text, isMe: true, partnerId: targetID))
            }
        }
    }
    
    private func listen() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let msg):
                if case .string(let text) = msg { self?.parse(text) }
                self?.listen()
            case .failure:
                DispatchQueue.main.async { self?.isConnected = false }
                DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) { self?.connectToHQ() }
            }
        }
    }
    
    private func parse(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String, type == "msg",
              let senderId = json["from_id"] as? String,
              let msgText = json["text"] as? String else { return }
        
        DispatchQueue.main.async {
            self.messages.append(ChatMessage(text: msgText, isMe: false, partnerId: senderId))
        }
    }
}
