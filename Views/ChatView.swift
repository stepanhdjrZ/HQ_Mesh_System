import SwiftUI

struct ChatView: View {
    @State var contactID: String
    @EnvironmentObject var meshManager: MeshNetworkManager
    @State private var text = ""
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(meshManager.messages.filter { $0.partnerId == contactID }) { msg in
                        MessageBubble(msg: msg)
                    }
                }
                .padding(.top, 10)
            }
            .background(Color(UIColor.secondarySystemBackground))
            
            // Панель ввода в стиле ТГ
            HStack(spacing: 12) {
                Button(action: {}) {
                    Image(systemName: "paperclip").font(.title2).foregroundColor(.gray)
                }
                
                TextField("Сообщение", text: $text)
                    .padding(10)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(20)
                
                if text.isEmpty {
                    Image(systemName: "mic").font(.title2).foregroundColor(.gray)
                } else {
                    Button(action: {
                        meshManager.sendMessage(to: contactID, text: text)
                        text = ""
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(UIColor.systemGroupedBackground))
        }
        .navigationTitle(contactID)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Красивый пузырек с градиентом
struct MessageBubble: View {
    let msg: ChatMessage
    var body: some View {
        HStack {
            if msg.isMe { Spacer(minLength: 60) }
            VStack(alignment: .trailing, spacing: 4) {
                Text(msg.text)
                    .font(.system(size: 16))
                Text(msg.timeString).font(.system(size: 10)).opacity(0.5)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(msg.isMe ? Color.blue : Color(UIColor.systemBackground))
            .foregroundColor(msg.isMe ? .white : .primary)
            .clipShape(RoundedCorner(radius: 18, corners: msg.isMe ? [.topLeft, .bottomLeft, .topRight] : [.topRight, .bottomRight, .topLeft]))
            .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
            if !msg.isMe { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 10)
    }
}

// Вспомогательная форма для углов (обязательно вне других структур)
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
