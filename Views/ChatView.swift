import SwiftUI
import UIKit

struct ChatView: View {
    let contactID: String
    @EnvironmentObject var meshManager: MeshNetworkManager
    @State private var inputText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(meshManager.messages.filter { $0.partnerId == contactID }) { msg in
                            MessageBubbleCell(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: meshManager.messages) { _ in
                    if let lastMsg = meshManager.messages.filter({ $0.partnerId == contactID }).last {
                        withAnimation { proxy.scrollTo(lastMsg.id, anchor: .bottom) }
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            
            // Chat Input Bar
            HStack(spacing: 12) {
                Button(action: {}) {
                    Image(systemName: "paperclip").font(.title2).foregroundColor(.secondary)
                }
                
                TextField("Сообщение...", text: $inputText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.secondary.opacity(0.2), lineWidth: 0.5))
                
                Button(action: handleSend) {
                    Image(systemName: inputText.isEmpty ? "mic.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(inputText.isEmpty ? .secondary : .blue)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty && false) // Ready for mic logic later
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(UIColor.systemBackground).ignoresSafeArea(edges: .bottom))
        }
        .navigationTitle(contactID)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func handleSend() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        meshManager.sendMessage(to: contactID, text: text)
        inputText = ""
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

struct MessageBubbleCell: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isMe { Spacer(minLength: 50) }
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(message.text)
                    .font(.body)
                Text(message.timeString)
                    .font(.system(size: 11))
                    .foregroundColor(message.isMe ? .white.opacity(0.7) : .secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(message.isMe ? Color.blue : Color(UIColor.secondarySystemGroupedBackground))
            .foregroundColor(message.isMe ? .white : .primary)
            .clipShape(ChatBubbleShape(isMe: message.isMe))
            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
            
            if !message.isMe { Spacer(minLength: 50) }
        }
    }
}

// Telegram-style Message Tails
struct ChatBubbleShape: Shape {
    let isMe: Bool
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: isMe ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight],
            cornerRadii: CGSize(width: 18, height: 18)
        )
        return Path(path.cgPath)
    }
}
