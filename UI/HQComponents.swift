import SwiftUI

// MARK: - Пузырь сообщения в стиле Telegram
struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isMe { Spacer(minLength: 60) }
            
            VStack(alignment: message.isMe ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.system(size: 16, weight: .regular))
                
                HStack(spacing: 4) {
                    Text(message.timeString)
                        .font(.system(size: 10, weight: .bold))
                        .opacity(0.6)
                    
                    if message.isMe {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .black))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                message.isMe 
                ? AnyView(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                : AnyView(Color.white.opacity(0.1))
            )
            .foregroundColor(message.isMe ? .black : .white)
            .cornerRadius(18)
            
            if !message.isMe { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Карточка контакта
struct ContactRow: View {
    let contact: Contact
    
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.1)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 55, height: 55)
                
                Text(String(contact.name.prefix(1)).uppercased())
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(.cyan)
            }
            
            VStack(alignment: .leading, spacing: 5) {
                Text(contact.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                
                Text(contact.hqId)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if contact.unreadCount > 0 {
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 22, height: 22)
                    .overlay(Text("\(contact.unreadCount)").font(.caption2.bold()).foregroundColor(.black))
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Декоративный неоновый фон
struct HQBackground: View {
    var body: some View {
        ZStack {
            AppConstants.Colors.mainBackground.ignoresSafeArea()
            
            // Неоновые пятна
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 400)
                .blur(radius: 80)
                .offset(x: -150, y: -200)
            
            Circle()
                .fill(Color.cyan.opacity(0.05))
                .frame(width: 300)
                .blur(radius: 60)
                .offset(x: 150, y: 300)
        }
    }
}
