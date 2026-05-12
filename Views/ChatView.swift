import SwiftUI

struct ChatView: View {
    @State var contactID: String
    @EnvironmentObject var meshManager: MeshNetworkManager
    @State private var text = ""
    @State private var showStickers = false
    
    // Твой фирменный пак стикеров для стартапа
    let hqStickers = ["🚀", "🛰️", "🔥", "👑", "💻", "🛡️", "🎮", "🔫", "⚡️", "😎"]
    
    var body: some View {
        VStack(spacing: 0) {
            // ПОЛЕ ЧАТА
            ScrollViewReader { proxy in
                ScrollView {
                    let filteredMessages = meshManager.messages.filter { $0.partnerId == contactID }
                    
                    VStack(spacing: 12) {
                        ForEach(filteredMessages) { msg in
                            MessageBubble(msg: msg)
                                .id(msg.id)
                        }
                    }
                    .padding(.vertical)
                }
                .background(Color(UIColor.systemGroupedBackground)) // Фон как в ТГ
                .onChange(of: meshManager.messages.count) { _ in
                    if let lastId = meshManager.messages.filter({ $0.partnerId == contactID }).last?.id {
                        withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                    }
                }
            }
            
            // ПАНЕЛЬ СТИКЕРОВ (выезжает по кнопке)
            if showStickers {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(hqStickers, id: \.self) { sticker in
                            Button(action: {
                                meshManager.sendMessage(to: contactID, text: sticker)
                                withAnimation { showStickers = false }
                            }) {
                                Text(sticker).font(.system(size: 45))
                            }
                        }
                    }
                    .padding()
                }
                .background(Color(UIColor.secondarySystemBackground))
                .frame(height: 90)
                .transition(.move(edge: .bottom))
            }
            
            // ПАНЕЛЬ ВВОДА (как в Телеграм)
            HStack(spacing: 12) {
                Button(action: { /* Скрепка */ }) {
                    Image(systemName: "paperclip").font(.title2).foregroundColor(.gray)
                }
                
                HStack {
                    TextField("Сообщение...", text: $text)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    
                    Button(action: { withAnimation { showStickers.toggle() } }) {
                        Image(systemName: "face.smiling.fill")
                            .foregroundColor(.gray)
                            .padding(.trailing, 10)
                    }
                }
                .background(Color(UIColor.systemBackground))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                
                if !text.isEmpty {
                    Button(action: {
                        meshManager.sendMessage(to: contactID, text: text)
                        text = ""
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 34))
                            .foregroundColor(.blue)
                    }
                } else {
                    Button(action: { /* Микрофон */ }) {
                        Image(systemName: "mic").font(.title2).foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(UIColor.secondarySystemBackground))
        }
        .navigationTitle(contactID)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {}) {
                    Image(systemName: "phone").foregroundColor(.blue)
                }
            }
        }
    }
}

// ДИЗАЙН ПУЗЫРЯ СООБЩЕНИЯ
struct MessageBubble: View {
    let msg: ChatMessage
    
    var body: some View {
        HStack {
            if msg.isMe { Spacer() }
            
            // Если сообщение это просто ОДИН стикер-эмодзи, делаем его гигантским без фона
            if msg.text.count == 1 && msg.text.unicodeScalars.first?.properties.isEmoji == true {
                Text(msg.text)
                    .font(.system(size: 65))
                    .padding(.horizontal, 15)
                    .padding(.vertical, 5)
            } else {
                // Обычное текстовое сообщение
                VStack(alignment: .trailing, spacing: 2) {
                    Text(msg.text)
                        .foregroundColor(msg.isMe ? .white : .primary)
                    
                    HStack(spacing: 4) {
                        Text(msg.timeString)
                            .font(.system(size: 10))
                            .foregroundColor(msg.isMe ? Color.white.opacity(0.7) : .gray)
                        if msg.isMe {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(msg.isMe ? Color.blue : Color(UIColor.systemBackground))
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
            }
            
            if !msg.isMe { Spacer() }
        }
        .padding(.horizontal, 12)
    }
}
