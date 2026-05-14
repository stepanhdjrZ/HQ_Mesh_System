import SwiftUI

// 1. ИДЕАЛЬНЫЙ ФОН
struct HQBackground: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            LinearGradient(
                gradient: Gradient(colors: [Color.cyan.opacity(0.15), Color.blue.opacity(0.05)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blur(radius: 50)
            .ignoresSafeArea()
        }
    }
}

// 2. КАРТОЧКА КОНТАКТА
struct ContactRow<T>: View {
    var contact: T
    
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle().fill(Color.black.opacity(0.6))
                Circle().stroke(Color.cyan.opacity(0.4), lineWidth: 1)
                Image(systemName: "cpu")
                    .foregroundColor(.cyan)
                    .font(.system(size: 20))
            }
            .frame(width: 45, height: 45)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("УЗЕЛ ИМПЕРИИ") 
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                Text("ONLINE • SECURE CHANNEL")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(.cyan)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(15)
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}

// 3. ПУЗЫРЬ ЧАТА TELEGRAM-STYLE
struct MessageBubble<T>: View {
    var message: T
    
    var body: some View {
        let mirror = Mirror(reflecting: message)
        let text = (mirror.children.first(where: { $0.label == "text" || $0.label == "content" })?.value as? String) ?? "Encrypted Payload..."
        let isMe = (mirror.children.first(where: { $0.label == "isMe" || $0.label == "isSender" })?.value as? Bool) ?? true
        
        HStack {
            if isMe { Spacer() }
            
            Text(text)
                .font(.system(size: 15))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isMe ? Color.cyan.opacity(0.2) : Color.white.opacity(0.1))
                .foregroundColor(.white)
                .cornerRadius(18, corners: isMe ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])
                .overlay(
                    RoundedCorner(radius: 18, corners: isMe ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])
                        .stroke(isMe ? Color.cyan.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 1)
                )
            
            if !isMe { Spacer() }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

// 4. КИБЕР-РАДАР (Тот самый недостающий элемент!)
struct RadarView: View {
    var activeNodesCount: Int
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Внешнее пульсирующее кольцо
            Circle()
                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                .frame(width: 100, height: 100)
                .scaleEffect(isAnimating ? 1.5 : 0.5)
                .opacity(isAnimating ? 0 : 1)
                .animation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: false), value: isAnimating)
            
            // Внутреннее статичное кольцо
            Circle()
                .stroke(Color.cyan.opacity(0.5), lineWidth: 1)
                .frame(width: 50, height: 50)
            
            // Центральное ядро
            Circle()
                .fill(Color.cyan)
                .frame(width: 20, height: 20)
                .shadow(color: .cyan, radius: 10, x: 0, y: 0)
            
            // Счетчик узлов внутри ядра (если они есть)
            if activeNodesCount > 0 {
                Text("\(activeNodesCount)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
            }
        }
        .frame(width: 150, height: 150)
        .onAppear {
            isAnimating = true
        }
    }
}
