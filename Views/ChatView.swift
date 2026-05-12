// Прокачанный пузырек сообщения в стиле HQ God Mode
struct MessageBubble: View {
    let msg: ChatMessage
    
    var body: some View {
        HStack {
            if msg.isMe { Spacer(minLength: 60) }
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(msg.text)
                    .font(.system(size: 16, weight: .regular))
                    .padding(.horizontal, 4)
                
                HStack(spacing: 4) {
                    Text(msg.timeString)
                        .font(.system(size: 10))
                        .opacity(0.6)
                    if msg.isMe {
                        Image(systemName: "checkmark.circle.fill") // Тот самый статус доставки
                            .font(.system(size: 10))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            // Твой фирменный градиент Империи для своих сообщений
            .background(
                msg.isMe ? 
                LinearGradient(colors: [Color.blue, Color.blue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing) : 
                LinearGradient(colors: [Color(.systemGray6), Color(.systemGray6)], startPoint: .top, endPoint: .bottom)
            )
            .foregroundColor(msg.isMe ? .white : .primary)
            .clipShape(RoundedCorner(radius: 20, corners: msg.isMe ? [.topLeft, .bottomLeft, .topRight] : [.topRight, .bottomRight, .topLeft]))
            .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
            
            if !msg.isMe { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 8)
    }
}

// Кастомная форма для «хвостиков» сообщений как в ТГ
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
