import Foundation

struct ChatMessage: Identifiable, Codable, Equatable {
    var id = UUID()
    let text: String
    let isMe: Bool
    let partnerId: String
    let timestamp: Date
    
    // Форматируем время как "14:05"
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: timestamp)
    }
}

struct Contact: Identifiable, Codable {
    var id: String { hqId }
    let hqId: String
    var name: String
    var lastMessageDate: Date
}
