import SwiftUI

struct ChatView: View {
    @State var contactID: String
    @EnvironmentObject var meshManager: MeshNetworkManager
    @State private var text = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // ФОН ЧАТА И СООБЩЕНИЯ
            ScrollView {
                let filteredMessages = meshManager.messages.filter { $0.partnerId == contactID }
                VStack(spacing: 8) {
                    ForEach(filteredMessages) { msg in
                        MessageBubble(msg: msg)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 15)
            }
            .background(Color(UIColor.secondarySystemBackground)) // Слегка серый фон, как в ТГ без обоев
            
            // ПАНЕЛЬ ВВОДА ВНИЗУ
            VStack(spacing: 0) {
                Divider() // Тонкая линия над клавиатурой
                HStack(spacing: 12) {
                    Button(action: {}) {
                        Image(systemName: "paperclip").font(.system(size: 22)).foregroundColor(.gray)
                    }
                    
                    HStack {
                        TextField("Сообщение", text: $text)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .font(.system(size: 16))
                        
                        Button(action: {}) {
                            Image(systemName: "face.smiling.fill").foregroundColor(.gray).padding(.trailing, 8)
                        }
                    }
                    .background(Color(UIColor.systemBackground))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color(UIColor.separator), lineWidth: 1))
                    
                    if !text.isEmpty {
                        Button(action: {
                            meshManager.sendMessage(to: contactID, text: text)
                            text = ""
                        }) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.blue)
                        }
                    } else {
                        Button(action: {}) {
                            Image(systemName: "mic").font(.system(size: 22)).foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(UIColor.systemGroupedBackground))
            }
        }
        .navigationTitle(contactID)
        .navigationBarTitleDisplayMode(.inline)
        // Аватарка в заголовке чата
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack {
                    Circle().fill(Color.blue).frame(width: 30, height: 30).overlay(Text(String(contactID.prefix(1))).font(.caption).foregroundColor(.white))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(contactID).font(.headline)
                        Text("в сети").font(.caption2).foregroundColor(.blue)
                    }
                }
            }
        }
    }
}

// ДИЗАЙН ПУЗЫРЯ
struct MessageBubble: View {
    let msg: ChatMessage
    var body: some View {
        HStack {
            if msg.isMe { Spacer(minLength: 50) }
            
            Text(msg.text)
                .font(.system(size: 16))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(msg.isMe ? Color(red: 0.1, green: 0.5, blue: 1.0) : Color(UIColor.systemBackground))
                .foregroundColor(msg.isMe ? .white : .primary)
                .cornerRadius(18)
                // Специфичное скругление уголков как в мессенджерах
                .clipShape(RoundedCornerShape(radius: 18, corners: msg.isMe ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight]))
                .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
            
            if !msg.isMe { Spacer(minLength: 50) }
        }
    }
}

// Вспомогательная структура для уголков баблов
struct RoundedCornerShape: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
