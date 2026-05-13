import SwiftUI
import UIKit

struct ChatView: View {
    let contactID: String
    @EnvironmentObject var meshManager: MeshNetworkManager
    @State private var inputText = ""
    @State private var showReportAlert = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.03, blue: 0.06).ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(meshManager.messages.filter { $0.partnerId == contactID }) { msg in
                                MessageBubbleCell(message: msg).id(msg.id)
                            }
                        }
                        .padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 10)
                    }
                    .onChange(of: meshManager.messages.count) { _ in
                        if let lastMsg = meshManager.messages.filter({ $0.partnerId == contactID }).last {
                            withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo(lastMsg.id, anchor: .bottom) }
                        }
                    }
                }
                
                HStack(spacing: 12) {
                    Button(action: {}) { Image(systemName: "paperclip").font(.title2).foregroundColor(.gray) }
                    TextField("Сообщение...", text: $inputText)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Color.white.opacity(0.05)).cornerRadius(20).foregroundColor(.white).disableAutocorrection(true)
                    
                    Button(action: handleSend) {
                        ZStack {
                            Circle().fill(inputText.isEmpty ? Color.white.opacity(0.1) : Color.cyan).frame(width: 40, height: 40)
                            Image(systemName: inputText.isEmpty ? "mic.fill" : "arrow.up").font(.system(size: 18, weight: .bold)).foregroundColor(inputText.isEmpty ? .gray : .black)
                        }
                    }.disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty && false)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Material.ultraThinMaterial.edgesIgnoringSafeArea(.bottom))
            }
        }
        .navigationTitle(contactID)
        .navigationBarTitleDisplayMode(.inline)
        // APPLE REQUIREMENT: Report/Block menu
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(role: .destructive, action: { showReportAlert = true }) { Label("Пожаловаться (Спам)", systemImage: "exclamationmark.bubble") }
                    Button(role: .destructive, action: { 
                        meshManager.blockUser(contactID)
                        presentationMode.wrappedValue.dismiss() // Выходим из чата
                    }) { Label("Заблокировать", systemImage: "hand.raised.fill") }
                } label: { Image(systemName: "ellipsis.circle").foregroundColor(.cyan) }
            }
        }
        .alert("Жалоба отправлена", isPresented: $showReportAlert) {
            Button("ОК", role: .cancel) { }
        } message: { Text("Модераторы проверят этот узел в течение 24 часов.") }
    }
    
    private func handleSend() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        meshManager.sendMessage(to: contactID, text: text)
        inputText = ""
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }
}

struct MessageBubbleCell: View {
    let message: ChatMessage
    var body: some View {
        HStack {
            if message.isMe { Spacer(minLength: 50) }
            VStack(alignment: .trailing, spacing: 4) {
                Text(message.text).font(.body)
                Text(message.timeString).font(.system(size: 10, weight: .medium)).foregroundColor(message.isMe ? .black.opacity(0.5) : .gray)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(message.isMe ? AnyView(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyView(Color.white.opacity(0.1).background(Material.ultraThinMaterial)))
            .foregroundColor(message.isMe ? .black : .white)
            .clipShape(ChatBubbleShape(isMe: message.isMe))
            .shadow(color: message.isMe ? .cyan.opacity(0.3) : .black.opacity(0.2), radius: 5, y: 2)
            if !message.isMe { Spacer(minLength: 50) }
        }
    }
}

struct ChatBubbleShape: Shape {
    let isMe: Bool
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: isMe ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight], cornerRadii: CGSize(width: 18, height: 18))
        return Path(path.cgPath)
    }
}
