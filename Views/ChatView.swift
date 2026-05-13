import SwiftUI

struct ChatView: View {
    let contactID: String
    @EnvironmentObject var meshManager: MeshNetworkManager
    @State private var textInput = ""
    @State private var showOptions = false
    
    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.02, blue: 0.05).ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 15) {
                            ForEach(meshManager.messages.filter { $0.partnerId == contactID }) { msg in
                                MessageBubble(msg: msg).id(msg.id)
                            }
                        }.padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 20)
                    }
                    .onChange(of: meshManager.messages.count) { _ in
                        withAnimation(.spring()) {
                            proxy.scrollTo(meshManager.messages.last?.id, anchor: .bottom)
                        }
                    }
                }
                
                // MARK: - Input Bar
                HStack(spacing: 12) {
                    Button(action: {}) {
                        Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(.gray)
                    }
                    
                    TextField("Передать пакет...", text: $textInput)
                        .padding(12).background(Color.white.opacity(0.08)).cornerRadius(22).foregroundColor(.white)
                    
                    Button(action: send) {
                        ZStack {
                            Circle().fill(textInput.isEmpty ? Color.white.opacity(0.1) : Color.cyan).frame(width: 42, height: 42)
                            Image(systemName: "paperplane.fill").foregroundColor(textInput.isEmpty ? .gray : .black)
                        }
                    }.disabled(textInput.isEmpty)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Color.black.opacity(0.85).edgesIgnoringSafeArea(.bottom))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack {
                    Text("Узел " + contactID.prefix(8)).font(.headline).foregroundColor(.white)
                    Text("P2P Канал Активен").font(.system(size: 10)).foregroundColor(.cyan)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showOptions = true }) {
                    Image(systemName: "ellipsis.circle").foregroundColor(.cyan)
                }
            }
        }
        .actionSheet(isPresented: $showOptions) {
            ActionSheet(title: Text("Управление узлом"), buttons: [
                .destructive(Text("Заблокировать и очистить")) { meshManager.blockEmpireUser(contactID) },
                .cancel()
            ])
        }
    }
    
    private func send() {
        guard !textInput.isEmpty else { return }
        meshManager.dispatchMessage(to: contactID, text: textInput)
        textInput = ""
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }
}

struct MessageBubble: View {
    let msg: ChatMessage
    var body: some View {
        HStack {
            if msg.isMe { Spacer(minLength: 60) }
            
            VStack(alignment: msg.isMe ? .trailing : .leading, spacing: 4) {
                Text(msg.text).font(.system(size: 16))
                Text(msg.timeString).font(.system(size: 10, weight: .bold)).foregroundColor(msg.isMe ? .black.opacity(0.4) : .gray)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(
                msg.isMe 
                ? AnyView(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                : AnyView(Color.white.opacity(0.1))
            )
            .foregroundColor(msg.isMe ? .black : .white)
            .cornerRadius(22, corners: msg.isMe ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])
            
            if !msg.isMe { Spacer(minLength: 60) }
        }
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity; var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}