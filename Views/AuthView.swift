import SwiftUI
import UIKit

struct AuthView: View {
    @EnvironmentObject var meshManager: MeshNetworkManager
    @State private var email = ""
    @State private var code = ""
    @State private var username = ""
    @State private var nickname = ""

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.06, blue: 0.1), .black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "shield.righthalf.filled").font(.system(size: 80)).foregroundColor(.blue).shadow(color: .blue.opacity(0.4), radius: 15)
                    Text("HQ Global").font(.system(size: 36, weight: .black, design: .rounded)).foregroundColor(.white)
                    Text(subtitleForCurrentStep).font(.subheadline).foregroundColor(.gray).multilineTextAlignment(.center).padding(.horizontal, 20)
                }.padding(.top, 50)
                
                VStack(spacing: 16) {
                    switch meshManager.authStep {
                    case .enterEmail:
                        AuthTextField(icon: "envelope.fill", placeholder: "Ваш Email", text: $email, keyboard: .emailAddress)
                    case .enterCode:
                        AuthTextField(icon: "key.fill", placeholder: "Код из письма", text: $code, keyboard: .numberPad)
                    case .setupProfile:
                        AuthTextField(icon: "at", placeholder: "username", text: $username, keyboard: .default)
                        AuthTextField(icon: "person.fill", placeholder: "Имя (Nickname)", text: $nickname, keyboard: .default)
                    }
                }.padding(.horizontal, 24)
                
                if !meshManager.authError.isEmpty {
                    Text(meshManager.authError).foregroundColor(.red).font(.caption).padding(.horizontal)
                }
                
                Button(action: submitAction) {
                    ZStack {
                        if meshManager.isWaitingForServer {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(buttonTitleForCurrentStep).font(.headline).foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity).frame(height: 56).background(Color.blue).cornerRadius(16).shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
                }
                .padding(.horizontal, 24).padding(.top, 10).disabled(meshManager.isWaitingForServer)
                
                Spacer()
            }
        }
    }
    
    private var subtitleForCurrentStep: String {
        switch meshManager.authStep {
        case .enterEmail: return "Децентрализованная сеть. Введите почту для получения доступа."
        case .enterCode: return "Код безопасности отправлен на \(email)"
        case .setupProfile: return "Последний шаг: создайте публичный профиль Империи."
        }
    }
    
    private var buttonTitleForCurrentStep: String {
        switch meshManager.authStep {
        case .enterEmail: return "Продолжить"
        case .enterCode: return "Подтвердить код"
        case .setupProfile: return "Войти в сеть"
        }
    }
    
    private func submitAction() {
        meshManager.authError = ""
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        switch meshManager.authStep {
        case .enterEmail:
            let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanEmail.isEmpty { meshManager.requestEmailCode(email: cleanEmail) }
        case .enterCode:
            let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanCode.isEmpty { meshManager.authStep = .setupProfile }
        case .setupProfile:
            let cleanUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanNick = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanUser.isEmpty && !cleanNick.isEmpty {
                meshManager.registerUser(email: email, code: code, username: cleanUser, nickname: cleanNick)
            }
        }
    }
}

struct AuthTextField: View {
    let icon: String; let placeholder: String; @Binding var text: String; let keyboard: UIKeyboardType
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon).foregroundColor(.blue).frame(width: 24)
            TextField(placeholder, text: $text)
                .foregroundColor(.white)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
        }
        .padding().background(Color.white.opacity(0.08)).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}
