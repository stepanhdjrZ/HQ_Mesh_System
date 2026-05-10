import SwiftUI
import AVKit

// MARK: - Главная тема HQ
struct HQTheme {
    static let accent = Color.blue
    static let background = Color(.systemBackground)
    static let secondaryBackground = Color(.systemGray6)
}

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var meshActive = true
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                VStack(spacing: 0) {
                    // Наш Радар (Mesh Status)
                    MeshRadarHeader(isActive: $meshActive)
                    
                    List {
                        ChatRowView(name: "Степан (Founder)", message: "Mesh-узлы активны 🛰️", time: "23:10", isOnline: true)
                        ChatRowView(name: "HQ Beta Tester", message: "Кружочек записан!", time: "22:05", isOnline: false)
                    }
                    .listStyle(PlainListStyle())
                }
                .navigationTitle("HQ Messenger")
                .navigationBarItems(trailing: Image(systemName: "plus.circle").foregroundColor(HQTheme.accent))
            }
            .tabItem { Image(systemName: "message.fill"); Text("Чаты") }.tag(0)
            
            Text("Настройки Сети").tabItem { Image(systemName: "antenna.radiowaves.left.and.right"); Text("Mesh") }.tag(1)
        }
    }
}

// MARK: - Меш-Радар
struct MeshRadarHeader: View {
    @Binding var isActive: Bool
    @State private var pulse = false
    
    var body: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(isActive ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                    .scaleEffect(pulse ? 1.5 : 1.0)
                    .opacity(pulse ? 0 : 1)
            }
            .onAppear { withAnimation(Animation.easeInOut(duration: 1).repeatForever(autoreverses: false)) { pulse.toggle() } }
            
            Text(isActive ? "Связь через Ryzen 7 (Mesh OK)" : "Поиск узлов...")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
            
            Spacer()
            
            Text("50 ₽/мес").font(.caption2).padding(4).background(Color.blue.opacity(0.1)).cornerRadius(5)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(HQTheme.secondaryBackground)
    }
}

// MARK: - Экран Чата (Кружочки и Войсы)
struct ChatDetailView: View {
    @State private var messageText = ""
    @State private var isRecording = false
    
    var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Пример кружочка
                    VideoCircleMessage(isMy: false)
                    
                    // Пример войса
                    VoiceMessageBubble(isMy: true)
                    
                    MessageBubble(text: "На M4 и Ryzen всё летает!", isMy: true)
                }
                .padding()
            }
            
            // Панель ввода (Telegram Style)
            HStack(spacing: 12) {
                Button(action: {}) { Image(systemName: "paperclip").font(.title3) }
                
                TextField("Сообщение", text: $messageText)
                    .padding(10)
                    .background(HQTheme.secondaryBackground)
                    .cornerRadius(20)
                
                if messageText.isEmpty {
                    Button(action: { isRecording.toggle() }) {
                        Image(systemName: isRecording ? "stop.circle.fill" : "mic.fill")
                            .font(.title2)
                            .foregroundColor(isRecording ? .red : HQTheme.accent)
                    }
                    Button(action: {}) {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                    }
                } else {
                    Button(action: {}) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(HQTheme.accent)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Компонент: Кружочек
struct VideoCircleMessage: View {
    let isMy: Bool
    var body: some View {
        HStack {
            if isMy { Spacer() }
            ZStack(alignment: .bottom) {
                Circle()
                    .stroke(HQTheme.accent, lineWidth: 2)
                    .frame(width: 160, height: 160)
                
                // Заглушка видео
                Image(systemName: "person.crop.circle.fill.badge.plus")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 155, height: 155)
                    .clipShape(Circle())
                    .foregroundColor(.gray)
                
                Text("0:05")
                    .font(.caption2)
                    .padding(4)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(5)
                    .foregroundColor(.white)
                    .padding(.bottom, 8)
            }
            if !isMy { Spacer() }
        }
    }
}

// MARK: - Компонент: Голосовое
struct VoiceMessageBubble: View {
    let isMy: Bool
    var body: some View {
        HStack {
            if isMy { Spacer() }
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                Rectangle() // Упрощенная волна
                    .fill(isMy ? Color.white.opacity(0.5) : Color.blue.opacity(0.5))
                    .frame(width: 100, height: 20)
                Text("0:12")
            }
            .padding(12)
            .background(isMy ? HQTheme.accent : HQTheme.secondaryBackground)
            .foregroundColor(isMy ? .white : .primary)
            .cornerRadius(18)
            if !isMy { Spacer() }
        }
    }
}

// Вспомогательные компоненты для списка
struct ChatRowView: View {
    let name: String; let message: String; let time: String; let isOnline: Bool
    var body: some View {
        NavigationLink(destination: ChatDetailView()) {
            HStack {
                Circle().fill(Color.gray.opacity(0.3)).frame(width: 50, height: 50)
                VStack(alignment: .leading) {
                    Text(name).bold()
                    Text(message).font(.subheadline).foregroundColor(.gray).lineLimit(1)
                }
                Spacer()
                Text(time).font(.caption).foregroundColor(.gray)
            }
        }
    }
}

struct MessageBubble: View {
    let text: String; let isMy: Bool
    var body: some View {
        HStack {
            if isMy { Spacer() }
            Text(text).padding(12).background(isMy ? HQTheme.accent : HQTheme.secondaryBackground).foregroundColor(isMy ? .white : .primary).cornerRadius(18)
            if !isMy { Spacer() }
        }
    }
}
