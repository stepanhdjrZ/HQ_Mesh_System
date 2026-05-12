import Foundation
import SwiftUI

class MeshNetworkManager: NSObject, ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var messages: [ChatMessage] = []
    @Published var contacts: [Contact] = []
    @Published var myHQID: String = ""
    
    enum ConnectionState { case disconnected, connecting, connected }
    
    private var webSocket: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    
    override init() {
        super.init()
        loadData()
        connectToHQ()
    }
    
    func connectToHQ() {
        DispatchQueue.main.async { self.connectionState = .connecting }
        let url = URL(string: "wss://hq-mesh.site/ws")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
        webSocket = URLSession.shared.webSocketTask(with: request)
        webSocket?.resume()
        
        let registerMsg = "{\"type\": \"register\", \"my_id\": \"\(myHQID)\"}"
        webSocket?.send(.string(registerMsg)) { error in
            if error == nil {
                DispatchQueue.main.async { self.connectionState = .connected }
                self.listen()
                self.startHeartbeat()
            } else {
                self.handleDisconnect()
            }
        }
    }
    
    private func startHeartbeat() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            self?.webSocket?.sendPing { error in
                if error != nil { self?.handleDisconnect() }
            }
        }
    }
    
    func sendMessage(to targetID: String, text: String) {
        let msgJSON = "{\"type\": \"private_msg\", \"to_id\": \"\(targetID)\", \"text\": \"\(text)\"}"
        webSocket?.send(.string(msgJSON)) { [weak self] error in
            if error == nil {
                DispatchQueue.main.async {
                    let newMsg = ChatMessage(text: text, isMe: true, partnerId: targetID, timestamp: Date())
                    self?.messages.append(newMsg)
                    self?.saveContact(id: targetID)
                }
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
                self?.handleDisconnect()
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
            let newMsg = ChatMessage(text: msgText, isMe: false, partnerId: senderId, timestamp: Date())
            self.messages.append(newMsg)
            self.saveContact(id: senderId)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
    
    private func handleDisconnect() {
        DispatchQueue.main.async { self.connectionState = .disconnected }
        pingTimer?.invalidate()
        DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.connectToHQ()
        }
    }
    
    private func saveContact(id: String) {
        if !contacts.contains(where: { $0.hqId == id }) {
            contacts.append(Contact(hqId: id, name: "Узел \(id.prefix(4))", lastMessageDate: Date()))
        }
    }
    
    private func loadData() {
        if let savedID = UserDefaults.standard.string(forKey: "myHQID") {
            self.myHQID = savedID
        } else {
            let newID = "HQ-\(UUID().uuidString.prefix(5))"
            UserDefaults.standard.set(newID, forKey: "myHQID")
            self.myHQID = newID
        }
    }
}
