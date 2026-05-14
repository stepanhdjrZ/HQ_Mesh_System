import SwiftUI

struct AuthView: View {
    @StateObject private var viewModel = AuthViewModel()
    
    var body: some View {
        ZStack {
            // Глубокий темный фон
            Color.black.ignoresSafeArea()
            
            // Задний стеклянный градиент
            LinearGradient(gradient: Gradient(colors: [Color.cyan.opacity(0.4), Color.blue.opacity(0.1)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .blur(radius: 50)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // САМА ВИЗИТНАЯ КАРТОЧКА
                VStack(spacing: 20) {
                    // Шапка визитки
                    HStack {
                        Image(systemName: "cpu")
                            .font(.system(size: 30, weight: .light))
                            .foregroundColor(.cyan)
                        Spacer()
                        Text("HQ NODE ACCESS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 10)
                    
                    // Поле ввода почты
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ИДЕНТИФИКАТОР (EMAIL)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                        
                        TextField("agent@hq.com", text: $viewModel.email)
                            .font(.system(size: 18, design: .monospaced))
                            .foregroundColor(.white)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding(15)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.cyan.opacity(viewModel.isEmailValid ? 0.5 : 0.1), lineWidth: 1)
                            )
                    }
                    
                    // Галочка EULA (КРИТИЧНО ДЛЯ МОДЕРАЦИИ APPLE)
                    Toggle(isOn: $viewModel.acceptedEULA) {
                        Text("Я принимаю условия использования (EULA) и политику конфиденциальности.")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .cyan))
                    
                    // Кнопка входа
                    Button(action: {
                        // Тут будет логика отправки данных в Firebase
                    }) {
                        Text(viewModel.canSubmitEmail ? "СГЕНЕРИРОВАТЬ КЛЮЧ" : "ОЖИДАНИЕ ВВОДА")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(viewModel.canSubmitEmail ? Color.cyan : Color.white.opacity(0.1))
                            .foregroundColor(viewModel.canSubmitEmail ? .black : .gray)
                            .cornerRadius(10)
                    }
                    .disabled(!viewModel.canSubmitEmail)
                    .animation(.easeInOut, value: viewModel.canSubmitEmail)
                }
                .padding(30)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.6))
                        .background(BlurView(style: .systemUltraThinMaterialDark).clipShape(RoundedRectangle(cornerRadius: 20)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
    }
}

// Вспомогательный элемент для эффекта матового стекла
struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}
