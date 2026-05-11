import SwiftUI

struct ChatView: View {
    let contactName: String
    @State private var text = ""
    
    var body: some View {
        VStack {
            ScrollView {
                // Здесь будут наши кружочки и сообщения
                Text("Начало переписки. Шифрование активно.").font(.caption).foregroundColor(.gray).padding()
            }
            
            // Панель ввода
            HStack {
                Button(action: {}) { Image(systemName: "paperclip").font(.title2) }
                
                TextField("Сообщение...", text: $text)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                
                if text.isEmpty {
                    Button(action: {}) { Image(systemName: "mic").font(.title2) }
                    Button(action: {}) { Image(systemName: "camera").font(.title2) }
                } else {
                    Button(action: {}) { Image(systemName: "arrow.up.circle.fill").font(.title) }
                }
            }
            .padding()
        }
        .navigationTitle(contactName)
        .navigationBarTitleDisplayMode(.inline)
        // Кнопки звонков сверху
        .navigationBarItems(trailing: HStack(spacing: 15) {
            Button(action: { /* Аудиозвонок */ }) { Image(systemName: "phone") }
            Button(action: { /* Видеозвонок */ }) { Image(systemName: "video") }
        })
    }
}
