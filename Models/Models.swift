import Foundation

struct ChatMessage: Identifiable, Codable, Equatable {
    var id = UUID()
    let text: String
    let isMe: Bool
    let partnerId: String
    let timestamp: Date
}

struct Contact: Identifiable, Codable {
    var id: String { hqId }
    let hqId: String
    var name: String
    var lastMessageDate: Date
}
