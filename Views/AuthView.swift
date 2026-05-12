import SwiftUI

struct AuthView: View {
    @Binding var isRegistered: Bool
    @State private var step = 1 // 1: Телефон, 2: Код, 3: Почта
    @State private var phone = ""
    @State private var code = ""
    @State private var email = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                
                VStack(spacing: 15) {
                    Image(systemName: step == 3 ? "envelope.badge.shield.half.filled" : "bolt.shield.fill")
                        .font(.system(size: 70))
                        .foregroundColor(.blue)
                    
                    Text(stepTitle)
                        .font(.system(size: 28, weight: .bold))
                    
                    Text(stepSubTitle)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                VStack(spacing: 15) {
                    if step == 1 {
                        TextField("+7 999 000 00 00", text: $phone)
                            .keyboardType(.phonePad)
                            .modifier(AuthFieldModifier())
                    } else if step == 2 {
                        TextField("0000", text: $code)
                            .keyboardType(.numberPad)
                            .tracking(10)
                            .modifier(AuthFieldModifier())
                    } else {
                        TextField("Email (для восстановления)", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .modifier(AuthFieldModifier())
                    }
                    
                    Button(action: nextStep) {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(step == 3 ? "Завершить" : "Продолжить")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer()
            }
            .background(Color(UIColor.systemBackground))
        }
    }
    
    var stepTitle: String {
        switch step {
        case 1: return "Ваш номер"
        case 2: return "Подтверждение"
        default: return "Почта"
        }
    }
    
    var stepSubTitle: String {
        switch step {
        case 1: return "Введите номер телефона, чтобы создать свой уникальный HQ ID."
        case 2: return "Мы отправили СМС с кодом. Пожалуйста, введите его ниже."
        default: return "Привяжите почту, чтобы не потерять доступ к сети HQ Global."
        }
    }
    
    func nextStep() {
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isLoading = false
            withAnimation {
                if step < 3 { step += 1 }
                else { 
                    UserDefaults.standard.set(true, forKey: "isRegistered")
                    isRegistered = true 
                }
            }
        }
    }
}

struct AuthFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.title2)
            .multilineTextAlignment(.center)
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
    }
}
