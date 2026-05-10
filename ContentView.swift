import SwiftUI
import AVKit

// MARK: - Главный экран (Telegram Style)
struct ContentView: View {
    @State private var searchText = ""
    @State private var isMeshActive = true // Статус нашего Mesh-узла
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Наш "Радар" / Статус сети
                MeshStatusHeader(isActive: $isMeshActive)
                
                // Список чатов
                List {
                    // Пример чата (в будущем подтянем из базы твоего Ryzen)
                    NavigationLink(destination: ChatDetailView(userName: "Степан (Founder)")) {
                        ChatRow(name: "Степан (Founder)", 
                                lastMessage: "Mesh-узлы работают стабильно 🛰️", 
                                time: "22:41", 
                                isOnline: true)
                    }
                    
                    ChatRow(name: "HQ System", 
                            lastMessage: "Добро пожаловать в децентрализованную сеть.", 
                            time: "Вчера", 
                            isOnline: false)
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("HQ Messenger")
            .navigationBarItems(trailing: Image(systemName: "square.and.pencil"))
        }
    }
}

// MARK: - Компонент строки чата
struct ChatRow: View {
    let name: String
    let lastMessage: String
    let time: String
    let isOnline: Bool
    
    var body: some View {
        HStack(spacing: 15) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 55, height: 55)
                
                if isOnline {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }
            }
            
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(name).bold()
                    Spacer()
                    Text(time).font(.caption).foregroundColor(.gray)
                }
                Text(lastMessage)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 5)
    }
}

// MARK: - Экран чата (Кружочки и сообщения)
struct ChatDetailView: View {
    let userName: String
    @State private var messageText = ""
    
    var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 15) {
                    // Пример кружочка (Video Message)
                    VideoCirclePreview()
                    
                    MessageBubble(text: "Привет! Как там наш сервер на Ryzen?", isMy: false)
                    MessageBubble(text: "Всё супер, 9800X3D перемалывает пакеты мгновенно!", isMy: true)
                }
                .padding()
            }
            
            // Панель ввода (Telegram Style)
            HStack(spacing: 15) {
                Button(action: {}) { Image(systemName: "paperclip") }
                
                TextField("Сообщение", text: $messageText)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                
                // Если текста нет — показываем микрофон (голосовые) или камеру (кружочки)
                if messageText.isEmpty {
                    Button(action: {}) { Image(systemName: "mic").font(.title3) }
                    Button(action: {}) { Image(systemName: "camera").font(.title3) }
                } else {
                    Button(action: {}) { Image(systemName: "arrow.up.circle.fill").font(.title) }
                }
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .navigationBarTitle(userName, displayMode: .inline)
    }
}

// MARK: - Тот самый Кружочек (UI часть)
struct VideoCirclePreview: View {
    var body: some View {
        HStack {
            Spacer()
            ZStack {
                Circle()
                    .stroke(Color.blue, lineWidth: 3)
                    .frame(width: 150, height: 150)
                
                // Тут будет плеер видео AVPlayer
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 145, height: 145)
                    .clipShape(Circle())
                
                VStack {
                    Spacer()
                    Text("0:08").font(.caption2).padding(4).background(Color.black.opacity(0.5)).cornerRadius(5).foregroundColor(.white)
                }.padding(.bottom, 10)
            }
        }
    }
}

// MARK: - Бабл сообщения
struct MessageBubble: some View {
    let text: String
    let isMy: Bool
    
    var body: some View {
        HStack {
            if isMy { Spacer() }
            Text(text)
                .padding(12)
                .background(isMy ? Color.blue : Color(.systemGray5))
                .foregroundColor(isMy ? .white : .black)
                .cornerRadius(18)
            if !isMy { Spacer() }
        }
    }
}

// MARK: - Хедер статуса Mesh (Радар)
struct MeshStatusHeader: View {
    @Binding var isActive: Bool
    
    var body: some View {
        HStack {
            Circle()
                .fill(isActive ? Color.green : Color.red)
                .frame(width: 10, height: 10)
                .shadow(color: isActive ? .green : .red, radius: 4)
            
            Text(isActive ? "Mesh: Активен (1 узел рядом)" : "Mesh: Поиск узлов...")
                .font(.caption)
                .bold()
            
            Spacer()
            
            if !isActive {
                ProgressView().scaleEffect(0.7)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
}
