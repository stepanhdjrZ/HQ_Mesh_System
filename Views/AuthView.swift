import SwiftUI
import UIKit // КРИТИЧНО ДЛЯ КЛАВИАТУРЫ И ВИБРАЦИИ

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
                VStack(spacing: 15) {
                    Image(systemName: "hexagon.fill").font(.system(size: 80)).foregroundColor(.blue).shadow(color: .blue.opacity(0.5), radius: 20)
                    Text("HQ Global").font(.system(size: 34, weight: .black)).foregroundColor(.white)
                    Text(subtitle).font(.subheadline).foregroundColor(.gray).multilineTextAlignment(.center)
                }
                .padding(.top, 60)
                
                VStack(spacing: 20) {
                    if meshManager.authStep == .enterEmail {
                        HStack {
                            Image(systemName: "envelope.fill").foregroundColor(.blue).frame(width: 30)
                            TextField("Ваш Email", text: $email)
                                .foregroundColor(.white)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                        }.padding().background(Color.white.opacity(0.05)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    } 
                    else if meshManager.authStep == .enterCode {
                        HStack {
                            Image(systemName: "key.fill").foregroundColor(.blue).frame(width: 30)
                            TextField("Код из письма", text: $code)
                                .foregroundColor(.white)
                                .keyboardType(.numberPad)
                        }.padding().background(Color.white.opacity(0.05)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    } 
                    else if meshManager.authStep == .setupProfile {
                        HStack {
                            Image(systemName: "at").foregroundColor(.blue).frame(width: 30)
                            TextField("username", text: $username).foregroundColor(.white).autocapitalization(.none)
                        }.padding().background(Color.white.opacity(0.05)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        
                        HStack {
                            Image(systemName: "person.fill").foregroundColor(.blue).frame(width: 30)
                            TextField("Имя (Nickname)", text: $nickname).foregroundColor(.white)
                        }.padding().background(Color.white.opacity(0.05)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 30)
                
                if !meshManager.authError.isEmpty {
                    Text(meshManager.authError).foregroundColor(.red).font(.caption).padding(.horizontal)
                }
                
                Button(action: handleAction) {
                    ZStack {
                        if meshManager.isWaitingForServer { 
                            ProgressView().tint(.white) 
                        } else { 
                            Text(buttonTitle).bold().foregroundColor(.white) 
                        }
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
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        switch meshManager.authStep {
        case .enterEmail:
            if !email.isEmpty { meshManager.requestEmailCode(email: email) }
        case .enterCode:
            if !code.isEmpty { meshManager.authStep = .setupProfile }
        case .setupProfile:
            if !username.isEmpty && !nickname.isEmpty {
                meshManager.myUsername = username
                meshManager.myNickname = nickname
                meshManager.registerUser(email: email, code: code, username: username, nickname: nickname)
            }
        }
    }
}
