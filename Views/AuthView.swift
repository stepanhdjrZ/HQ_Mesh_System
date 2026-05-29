import SwiftUI

struct AuthView: View {
    @EnvironmentObject var regManager: RegistrationManager
    @State private var user = ""
    @State private var pass = ""
    @State private var isLoginMode = true
    
    // Анимации
    @State private var isAnimating = false
    @FocusState private var focusedField: Field?
    
    enum Field { case user, pass }
    
    var body: some View {
        ZStack {
            // Элитный темный фон со свечением
            Color.black.ignoresSafeArea()
            
            RadialGradient(gradient: Gradient(colors: [Color.cyan.opacity(0.15), .black]), center: .top, startRadius: 100, endRadius: 600)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            
            VStack(spacing: 35) {
                Spacer()
                
                // Логотип с анимацией дыхания
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.cyan)
                    .shadow(color: .cyan.opacity(isAnimating ? 0.8 : 0.3), radius: isAnimating ? 25 : 10)
                    .scaleEffect(isAnimating ? 1.05 : 0.95)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                            isAnimating = true
                        }
                    }
                
                VStack(spacing: 8) {
                    Text("HQ GLOBAL MESH")
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(2)
                    
                    Text("БЕЗОПАСНАЯ ИМПЕРИЯ СВЯЗИ")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.cyan.opacity(0.8))
                        .tracking(4)
                }
                
                // Стеклянные поля ввода
                VStack(spacing: 20) {
                    HStack {
                        Image(systemName: "person.crop.circle")
                            .foregroundColor(.cyan)
                        TextField("Юзернейм", text: $user)
                            .focused($focusedField, equals: .user)
                            .textInputAutocapitalization(.never)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(focusedField == .user ? Color.cyan : Color.white.opacity(0.1), lineWidth: 1))
                    
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.cyan)
                        SecureField("Пароль", text: $pass)
                            .focused($focusedField, equals: .pass)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(focusedField == .pass ? Color.cyan : Color.white.opacity(0.1), lineWidth: 1))
                }
                .padding(.horizontal, 30)
                
                if let error = regManager.errorMessage {
                    Text(error)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red)
                        .transition(.opacity)
                }
                
                // Премиальная кнопка
                if regManager.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                        .scaleEffect(1.5)
18:53
.padding(.top, 10)
                } else {
                    Button(action: {
                        let impactMed = UIImpactFeedbackGenerator(style: .medium)
                        impactMed.impactOccurred() // Вибрация при нажатии
                        
                        withAnimation {
                            if isLoginMode {
                                regManager.login(user: user, pass: pass)
                            } else {
                                regManager.register(user: user, pass: pass)
                            }
                        }
                    }) {
                        Text(isLoginMode ? "ВОЙТИ В СЕТЬ" : "СОЗДАТЬ УЗЕЛ")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                LinearGradient(gradient: Gradient(colors: [Color.cyan, Color.blue]), startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(16)
                            .shadow(color: .cyan.opacity(0.5), radius: 15, x: 0, y: 5)
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 10)
                    
                    // Переключатель режима
                    Button(action: {
                        withAnimation(.spring()) {
                            isLoginMode.toggle()
                            regManager.errorMessage = nil
                        }
                    }) {
                        Text(isLoginMode ? "Новый участник? Присоединиться" : "Уже в Империи? Войти")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                            .underline()
                    }
                }
                
                Spacer()
            }
        }
        .ignoresSafeArea(.keyboard)
    }
}
