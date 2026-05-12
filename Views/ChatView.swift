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
                            .contextMenu {
                                Button(role: .destructive) {
                                    print("Блок: \(contactID)")
                                } label: {
                                    Label("Заблокировать", systemImage: "hand.raised.fill")
                                }
                                Button {
                                    print("Репорт: \(contactID)")
                                } label: {
                                    Label("Пожаловаться", systemImage: "exclamationmark.bubble.fill")
                                }
                            }
                    }
                }
                .padding()
            }
            .background(Color(UIColor.secondarySystemBackground))
            
            HStack(spacing: 12) {
                Image(systemName: "paperclip").font(.title2).foregroundColor(.gray)
                
                TextField("Сообщение", text: $text)
                    .padding(10)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.gray.opacity(0.2), lineWidth: 0.5))
                
                if text.isEmpty {
                    Image(systemName: "mic").font(.title2).foregroundColor(.gray)
                } else {
                    Button(action: {
                        meshManager.sendMessage(to: contactID, text: text)
                        text = ""
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }) {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 32)).foregroundColor(.blue)
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

struct MessageBubble: View {
    let msg: ChatMessage
    var body: some View {
        HStack {
            if msg.isMe { Spacer(minLength: 60) }
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(msg.text).font(.system(size: 16))
                Text(msg.timeString).font(.system(size: 10)).opacity(0.5)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(msg.isMe ? Color(red: 0.2, green: 0.5, blue: 1.0) : Color(UIColor.systemBackground))
            .foregroundColor(msg.isMe ? .white : .primary)
            .cornerRadius(18)
            .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
            
            if !msg.isMe { Spacer(minLength: 60) }
        }
    }
}
