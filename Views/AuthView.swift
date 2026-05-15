import SwiftUI

struct AuthView: View {
    @EnvironmentObject var regManager: RegistrationManager
    @State private var user = ""
    @State private var pass = ""
    @State private var isLoginMode = true
    
    var body: some View {
        ZStack {
            // Фон больше не ворует нажатия кнопок!
            MeshBackground().allowsHitTesting(false)
            
            VStack(spacing: 30) {
                Spacer()
                
                // Новая иконка Империи
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.cyan)
                    .shadow(color: .cyan.opacity(0.4), radius: 15)
                
                Text("HQ GLOBAL MESH")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                
                VStack(spacing: 15) {
                    TextField("Юзернейм", text: $user)
                        .textInputAutocapitalization(.never)
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1)))
                    
                    SecureField("Пароль", text: $pass)
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1)))
                }
                .padding(.horizontal, 30)
                
                if let error = regManager.errorMessage {
                    Text(error).foregroundColor(.red).font(.caption)
                }
                
                if regManager.isLoading {
                    ProgressView().tint(.cyan)
                } else {
                    Button(action: {
                        if isLoginMode {
                            regManager.login(user: user, pass: pass)
                        } else {
                            regManager.register(user: user, pass: pass)
                        }
                    }) {
                        Text(isLoginMode ? "ВОЙТИ" : "СОЗДАТЬ АККАУНТ")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.cyan)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 30)
                    
                    Button(action: { isLoginMode.toggle() }) {
                        Text(isLoginMode ? "Ещё не в Империи? Регистрация" : "Уже есть узел? Войти")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.cyan.opacity(0.7))
                    }
                }
                
                Spacer()
            }
        }
    }
}
