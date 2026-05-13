import Foundation

// Состояние узла в глобальной сети
enum NodeStatus: String, Codable {
    case online    // Виден через Штаб
    case mesh      // Виден только по P2P
    case offline   // Вне зоны доступа
}

// Протокол сообщения с поддержкой статусов доставки
struct ChatMessage: Identifiable, Codable, Hashable {
    var id = UUID()
    let text: String
    let isMe: Bool
    let partnerId: String
    let timestamp: Date
    var status: MessageStatus = .sent
    
    enum MessageStatus: String, Codable {
        case sending, sent, delivered, read, failed
    }
    
    var timeString: String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"
        return f.string(from: timestamp)
    }
}

// Модель контакта (Узла)
struct Contact: Identifiable, Codable, Hashable {
    var id = UUID()
    let hqId: String
    let name: String
    var bio: String = "Участник сети HQ Global"
    var lastMessageDate: Date
    var unreadCount: Int = 0
    var isVerified: Bool = false
}
