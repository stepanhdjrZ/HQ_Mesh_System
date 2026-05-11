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
        // Подключаемся к внешнему IP
        let url = URL(string: "ws://95.85.243.118:8080/ws")!
        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()
        
        let registerMsg = "{\"type\": \"register\", \"name\": \"\(UIDevice.current.name)\"}"
        webSocket?.send(.string(registerMsg)) { error in
            if error == nil {
                DispatchQueue.main.async { self.isConnected = true }
                self.listen()
            }
        }
    }
    
    func sendMessage(_ text: String) {
        let msgJSON = "{\"type\": \"msg\", \"text\": \"\(text)\"}"
        webSocket?.send(.string(msgJSON)) { _ in }
    }
    
    private func listen() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let msg):
                if case .string(let text) = msg { self?.parse(text) }
            case .failure: 
                DispatchQueue.main.async { self?.isConnected = false }
                // Попытка переподключения через 5 секунд
                DispatchQueue.global().asyncAfter(deadline: .now() + 5) { self?.connectToRyzen() }
                return
            }
            self?.listen()
        }
    }
    
    private func parse(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String, type == "msg",
              let msgText = json["text"] as? String else { return }
        
        DispatchQueue.main.async {
            self.messages.append(ChatMessage(text: msgText, isMe: false))
        }
    }
}
