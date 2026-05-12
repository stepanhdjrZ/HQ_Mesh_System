import SwiftUI

struct AuthView: View {
    @EnvironmentObject var meshManager: MeshNetworkManager
    @State private var phone = ""
    @State private var code = ""
    @State private var isCodeSent = false
    @State private var isLoading = false
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            // ФОНОВЫЙ ГРАДИЕНТ
            LinearGradient(gradient: Gradient(colors: [Color.black, Color(red: 0.1, green: 0.2, blue: 0.3)]), startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            
            VStack(spacing: 30) {
                // ЛОГОТИП И ТИТЛ
                VStack(spacing: 15) {
                    Image("Mesh_Logo").resizable().scaledToFit().frame(width: 100, height: 100).cornerRadius(20)
                    Text("HQ Global Mesh").font(.system(size: 32, weight: .bold)).foregroundColor(.white)
                    Text("Построй свою независимую связь").font(.headline).foregroundColor(.gray).multilineTextAlignment(.center)
                }
                .padding(.top, 50)
                
                // ПОЛЯ ВВОДА
                VStack(spacing: 20) {
                    if !isCodeSent {
                        // ВВОД НОМЕРА
                        TextfieldCard(icon: "phone.fill", placeholder: "Номер телефона", text: $phone)
                    } else {
                        // ВВОД КОДА
                        TextfieldCard(icon: "key.fill", placeholder: "Код из СМС", text: $code)
                    }
                }
                .padding(.horizontal)
                
                if !errorMessage.isEmpty { Text(errorMessage).foregroundColor(.red).font(.caption) }
                
                // КНОПКА
                Button(action: handleAction) {
                    ZStack {
                        if isLoading { ProgressView().tint(.white) }
                        else { Text(isCodeSent ? "Вход" : "Получить код").bold().foregroundColor(.white) }
                    }
                    .frame(maxWidth: .infinity).padding().background(Color.blue).cornerRadius(12)
                }
                .padding(.horizontal).padding(.top, 10).disabled(isLoading)
                
                Spacer()
            }
        }
    }
    
    // ЛОГИКА GODMODE ВХОДА (Любой номер, код 1234)
    private func handleAction() {
        errorMessage = ""
        isLoading = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        if !isCodeSent {
            meshManager.requestSMSCode(for: phone) { success in
                self.isLoading = false
                self.isCodeSent = success
            }
        } else {
            meshManager.verifyCode(code) { success in
                self.isLoading = false
                if !success { self.errorMessage = "Неверный код. Попробуйте \(MockSMS.code)." }
            }
        }
    }
}

struct TextfieldCard: View {
    let icon: String; let placeholder: String; @Binding var text: String
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(.blue).frame(width: 30)
            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.gray))
                .foregroundColor(.white).keyboardType(.phonePad)
        }
        .padding().background(Color.white.opacity(0.1)).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}
