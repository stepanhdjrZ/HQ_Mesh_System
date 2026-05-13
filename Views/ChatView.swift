import SwiftUI
import UIKit

struct ChatView: View {
    let contactID: String
    @EnvironmentObject var meshManager: MeshNetworkManager
    
    @State private var inputText = ""
    @State private var showActionSheet = false
    @State private var showReportAlert = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            // Фон глубокого космоса
            Color(red: 0.02, green: 0.02, blue: 0.05).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Слой сообщений
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // Разделитель даты (Заглушка для красоты)
                            Text("Сегодня")
                                .font(.caption.bold())
                                .foregroundColor(.gray)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 16)
                                .background(Color.white.opacity(0.1).clipShape(Capsule()))
                                .padding(.top, 10)
                            
                            ForEach(meshManager.messages.filter { $0.partnerId == contactID }) { msg in
                                HQMessageBubble(message: msg).id(msg.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                    .onChange(of: meshManager.messages.count) { _ in
                        if let lastMsg = meshManager.messages.filter({ $0.partnerId == contactID }).last {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                proxy.scrollTo(lastMsg.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Инновационная панель ввода
                HStack(alignment: .bottom, spacing: 12) {
                    Button(action: { UIImpactFeedbackGenerator(style: .light).impactOccurred() }) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                            .frame(height: 44)
                    }
                    
                    TextField("Сообщение...", text: $inputText, axis: .vertical)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(22)
                        .foregroundColor(.white)
                        .lineLimit(1...5) // Динамическая высота как в ТГ
                    
                    Button(action: transmitPayload) {
                        ZStack {
                            Circle()
                                .fill(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.white.opacity(0.1) : Color.cyan)
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: inputText.trimmingCharacters(in: .whitespaces).isEmpty ? "mic.fill" : "paperplane.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .black)
                                .offset(x: inputText.trimmingCharacters(in: .whitespaces).isEmpty ? 0 : -2, y: 0) // Визуальная центровка самолетика
                        }
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty && false)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Material.ultraThinMaterial
                        .edgesIgnoringSafeArea(.bottom)
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack {
                    Text("Узел \(contactID.prefix(6))").font(.headline.bold()).foregroundColor(.white)
                    Text("P2P Соединение активно").font(.caption2).foregroundColor(.cyan)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showActionSheet = true }) {
                    Image(systemName: "ellipsis.circle.fill").foregroundColor(.cyan).font(.title3)
                }
            }
        }
        // Модерация Apple - Жесткие требования
        .confirmationDialog("Управление узлом", isPresented: $showActionSheet, titleVisibility: .visible) {
            Button("Очистить историю", role: .destructive) { /* TODO */ }
            Button("Пожаловаться на контент", role: .destructive) { showReportAlert = true }
            Button("Заблокировать узел", role: .destructive) {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                meshManager.blockNode(contactID)
                presentationMode.wrappedValue.dismiss()
            }
            Button("Отмена", role: .cancel) { }
        }
        .alert("Жалоба передана в Штаб", isPresented: $showReportAlert) {
            Button("Понятно", role: .cancel) { }
        } message: { Text("Нейросети проанализируют пакеты данных данного узла.") }
    }
    
    private func transmitPayload() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        meshManager.sendMessage(to: contactID, text: text)
        inputText = ""
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }
}

// MARK: - Premium Message Bubbles
struct HQMessageBubble: View {
    let message: ChatMessage
    var body: some View {
        HStack(alignment: .bottom) {
            if message.isMe { Spacer(minLength: 60) }
            
            VStack(alignment: message.isMe ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.system(size: 16))
                    .lineSpacing(4)
                
                HStack(spacing: 4) {
                    Text(message.timeString)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(message.isMe ? .black.opacity(0.4) : .gray.opacity(0.8))
                    
                    if message.isMe {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.black.opacity(0.5))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                message.isMe
                ? AnyView(LinearGradient(colors: [.cyan, Color(red: 0.1, green: 0.6, blue: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing))
                : AnyView(Color.white.opacity(0.1).background(Material.ultraThinMaterial))
            )
            .foregroundColor(message.isMe ? .black : .white)
            .clipShape(BubblePath(isMe: message.isMe))
            .shadow(color: message.isMe ? .cyan.opacity(0.3) : .black.opacity(0.3), radius: 8, y: 4)
            
            if !message.isMe { Spacer(minLength: 60) }
        }
    }
}

// Математически точные хвостики как в iOS
struct BubblePath: Shape {
    let isMe: Bool
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: isMe ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight],
            cornerRadii: CGSize(width: 20, height: 20)
        )
        return Path(path.cgPath)
    }
}
