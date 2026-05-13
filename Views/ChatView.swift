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
            Color(red: 0.02, green: 0.02, blue: 0.05).ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(meshManager.messages.filter { $0.partnerId == contactID }) { msg in
                                HQMessageBubble(message: msg).id(msg.id)
                            }
                        }.padding(.horizontal, 16).padding(.bottom, 20).padding(.top, 20)
                    }
                    .onChange(of: meshManager.messages.count) { _ in
                        if let lastMsg = meshManager.messages.filter({ $0.partnerId == contactID }).last {
                            withAnimation(.spring()) { proxy.scrollTo(lastMsg.id, anchor: .bottom) }
                        }
                    }
                }
                
                HStack(alignment: .bottom, spacing: 12) {
                    Button(action: {}) { Image(systemName: "paperclip").font(.system(size: 24)).foregroundColor(.gray).frame(height: 44) }
                    TextField("Сообщение...", text: $inputText).padding(.horizontal, 18).padding(.vertical, 12).background(Color.white.opacity(0.1)).cornerRadius(22).foregroundColor(.white)
                    Button(action: transmitPayload) {
                        ZStack {
                            Circle().fill(inputText.isEmpty ? Color.white.opacity(0.2) : Color.cyan).frame(width: 44, height: 44)
                            Image(systemName: inputText.isEmpty ? "mic.fill" : "paperplane.fill").foregroundColor(inputText.isEmpty ? .gray : .black)
                        }
                    }.disabled(inputText.isEmpty)
                }
                .padding(.horizontal, 16).padding(.vertical, 12).background(Color.black.opacity(0.8))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack {
                    Text("Узел " + String(contactID.prefix(6))).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                    Text("P2P Активен").font(.system(size: 10)).foregroundColor(.cyan)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showActionSheet = true }) { Image(systemName: "ellipsis.circle.fill").foregroundColor(.cyan) }
            }
        }
        .actionSheet(isPresented: $showActionSheet) {
            ActionSheet(title: Text("Управление узлом"), buttons: [
                .destructive(Text("Пожаловаться на спам")) { showReportAlert = true },
                .destructive(Text("Заблокировать")) { meshManager.blockNode(contactID); presentationMode.wrappedValue.dismiss() },
                .cancel()
            ])
        }
        .alert(isPresented: $showReportAlert) {
            Alert(title: Text("Жалоба передана"), message: Text("Модераторы проверят этот узел."), dismissButton: .default(Text("ОК")))
        }
    }
    
    private func transmitPayload() {
        guard !inputText.isEmpty else { return }
        meshManager.sendMessage(to: contactID, text: inputText)
        inputText = ""
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }
}

struct HQMessageBubble: View {
    let message: ChatMessage
    var body: some View {
        HStack(alignment: .bottom) {
            if message.isMe { Spacer(minLength: 60) }
            VStack(alignment: message.isMe ? .trailing : .leading, spacing: 4) {
                Text(message.text).font(.system(size: 16))
                Text(message.timeString).font(.system(size: 11, weight: .bold)).foregroundColor(message.isMe ? .black.opacity(0.5) : .gray)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(message.isMe ? LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.1)], startPoint: .top, endPoint: .bottom))
            .foregroundColor(message.isMe ? .black : .white).cornerRadius(20)
            if !message.isMe { Spacer(minLength: 60) }
        }
    }
}
