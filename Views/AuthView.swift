import SwiftUI

struct AuthView: View {
    @EnvironmentObject var meshManager: MeshNetworkManager
    @State private var email = ""
    @State private var code = ""
    @State private var username = ""
    @State private var nickname = ""

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.1), .black], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 15) {
                    Image(systemName: "hexagon.fill").font(.system(size: 80)).foregroundColor(.blue).shadow(color: .blue.opacity(0.5), radius: 20)
                    Text("HQ Global").font(.system(size: 34, weight: .black)).foregroundColor(.white)
                    Text(subtitle).font(.subheadline).foregroundColor(.gray).multilineTextAlignment(.center)
                }
                .padding(.top, 60)
                
                // Content based on Step
                VStack(spacing: 20) {
                    if meshManager.authStep == .enterEmail {
                        AuthField(icon: "envelope.fill", placeholder: "Ваш Email", text: $email, keyboard: .emailAddress)
                    } else if meshManager.authStep == .enterCode {
                        AuthField(icon: "key.fill", placeholder: "Код из письма", text: $code, keyboard: .numberPad)
                    } else if meshManager.authStep == .setupProfile {
                        AuthField(icon: "at", placeholder: "username", text: $username, keyboard: .default)
                        AuthField(icon: "person.fill", placeholder: "Имя (Nickname)", text: $nickname, keyboard: .default)
                    }
                }
                .padding(.horizontal, 30)
                
                if !meshManager.authError.isEmpty {
                    Text(meshManager.authError).foregroundColor(.red).font(.caption).padding(.horizontal)
                }
                
                // Action Button
                Button(action: handleAction) {
                    ZStack {
                        if meshManager.isWaitingForServer { ProgressView().tint(.white) }
                        else { Text(buttonTitle).bold().foregroundColor(.white) }
                    }
                    .frame(maxWidth: .infinity).padding().background(Color.blue).cornerRadius(15).shadow(color: .blue.opacity(0.3), radius: 10)
                }
                .padding(.horizontal, 30).disabled(meshManager.isWaitingForServer)
                
                Spacer()
            }
        }
    }
    
    private var subtitle: String {
        switch meshManager.authStep {
        case .enterEmail: return "Введите почту для получения кода доступа"
        case .enterCode: return "Мы отправили секретный код на \(email)"
        case .setupProfile: return "Последний шаг: создайте свой уникальный профиль"
        }
    }
    
    private var buttonTitle: String {
        switch meshManager.authStep {
        case .enterEmail: return "Получить код"
        case .enterCode: return "Подтвердить"
        case .setupProfile: return "Войти в Империю"
        }
    }
    
    private func handleAction() {
        meshManager.authError = ""
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        switch meshManager.authStep {
        case .enterEmail:
            meshManager.requestEmailCode(email: email)
        case .enterCode:
            // Переход к профилю локально, регистрация будет на след. шаге
            meshManager.authStep = .setupProfile
        case .setupProfile:
            meshManager.myUsername = username
            meshManager.myNickname = nickname
            meshManager.registerUser(email: email, code: code, username: username, nickname: nickname)
        }
    }
}

struct AuthField: View {
    let icon: String; let placeholder: String; @Binding var text: String; let keyboard: UIKeyboardType
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(.blue).frame(width: 30)
            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.gray))
                .foregroundColor(.white).keyboardType(keyboard).autocapitalization(.none)
        }
        .padding().background(Color.white.opacity(0.05)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}
