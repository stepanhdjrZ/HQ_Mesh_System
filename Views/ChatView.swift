import SwiftUI

struct ChatView: View {
    let contactName: String
    @State private var text = ""
    @State private var showCamera = false // Триггер для вызова камеры
    
    var body: some View {
        ZStack {
            // Премиальный темный фон с легким свечением
            Color.black.edgesIgnoringSafeArea(.all)
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.15), Color.black]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                ScrollView {
                    // Имитация системного сообщения о шифровании
                    HStack {
                        Spacer()
                        Text("Mesh-соединение установлено. Трафик зашифрован.")
                            .font(.caption2)
                            .bold()
                            .padding(10)
                            .background(Color.green.opacity(0.15))
                            .foregroundColor(.green)
                            .cornerRadius(15)
                        Spacer()
                    }
                    .padding(.top)
                }
                
                // Панель ввода (эффект матового стекла)
                HStack(spacing: 15) {
                    Button(action: { /* Позже добавим выбор файлов */ }) {
                        Image(systemName: "paperclip").font(.title2).foregroundColor(.gray)
                    }
                    
                    TextField("HQ Сообщение...", text: $text)
                        .padding(12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(20)
                        .foregroundColor(.white)
                    
                    if text.isEmpty {
                        Button(action: { /* Позже добавим запись звука */ }) {
                            Image(systemName: "mic.fill").font(.title2).foregroundColor(.white)
                        }
                        // Кнопка кружочков теперь открывает окно камеры!
                        Button(action: { showCamera = true }) {
                            Image(systemName: "video.bubble.fill").font(.title2).foregroundColor(.green)
                        }
                    } else {
                        Button(action: { /* Отправка на сервер */ }) {
                            Image(systemName: "arrow.up.circle.fill").font(.system(size: 32)).foregroundColor(.blue)
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial) // Тот самый дорогой блюр
                .cornerRadius(35)
                .padding(.horizontal, 10)
                .padding(.bottom, 5)
            }
        }
        .navigationTitle(contactName)
        .navigationBarTitleDisplayMode(.inline)
        // Делаем верхнюю панель черной, чтобы сочеталось с фоном
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationBarItems(trailing: HStack(spacing: 20) {
            Button(action: { /* WebRTC Аудио */ }) { Image(systemName: "phone.fill").foregroundColor(.white) }
            Button(action: { /* WebRTC Видео */ }) { Image(systemName: "video.fill").foregroundColor(.white) }
        })
        // Всплывающее окно камеры
        .sheet(isPresented: $showCamera) {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                // Вызываем нашу настоящую фронтальную камеру и обрезаем в круг
                RealCameraScreen()
                    .frame(width: 300, height: 300)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.green, lineWidth: 4))
                    .shadow(color: .green.opacity(0.5), radius: 20, x: 0, y: 0)
                
                VStack {
                    Spacer()
                    Button(action: { showCamera = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 30)
                }
            }
        }
    }
}
