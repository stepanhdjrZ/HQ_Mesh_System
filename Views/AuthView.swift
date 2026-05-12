import SwiftUI

struct AuthView: View {
    @Binding var isRegistered: Bool
    @EnvironmentObject var meshManager: MeshNetworkManager
    
    @State private var step = 1 // 1: Телефон, 2: СМС-код, 3: Почта
    @State private var phoneNumber = ""
    @State private var smsCode = ""
    @State private var email = ""
    @State private var isLoading = false
    
    // Переменная для реального ID сессии (нужна для проверки реального СМС)
    @State private var verificationID: String? = nil 
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemBackground).edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // АНИМИРОВАННЫЙ ЗАГОЛОВОК
                    VStack(spacing: 15) {
                        Image(systemName: step == 3 ? "envelope.fill" : "bolt.shield.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                            .padding(.top, 40)
                        
                        Text(headerText)
                            .font(.system(size: 28, weight: .bold))
                        
                        Text(subHeaderText)
                            .multilineTextAlignment(.center)
                            .font(.body)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 30)
                    }
                    .padding(.bottom, 40)
                    
                    // ПОЛЯ ВВОДА В ЗАВИСИМОСТИ ОТ ШАГА
                    if step == 1 {
                        TextField("+7 999 000 00 00", text: $phoneNumber)
                            .keyboardType(.phonePad)
                            .font(.system(size: 24, weight: .medium))
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal, 40)
                    } else if step == 2 {
                        TextField("Код", text: $smsCode)
                            .keyboardType(.numberPad)
                            .font(.system(size: 34, weight: .bold, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .tracking(8) // Расстояние между цифрами как в ТГ
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal, 60)
                    } else if step == 3 {
                        TextField("Ваш Email (необязательно)", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .font(.system(size: 18))
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal, 40)
                    }
                    
                    Spacer()
                    
                    // КНОПКИ ДЕЙСТВИЯ
                    VStack(spacing: 15) {
                        Button(action: handleAction) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            } else {
                                Text(buttonText)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            }
                        }
                        
                        if step == 3 {
                            Button(action: finishRegistration) {
                                Text("Пропустить")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    // --- ДИНАМИЧЕСКИЙ ТЕКСТ ---
    var headerText: String {
        switch step {
        case 1: return "Ваш телефон"
        case 2: return "Введите код"
        case 3: return "Резервная почта"
        default: return ""
        }
    }
    
    var subHeaderText: String {
        switch step {
        case 1: return "Пожалуйста, подтвердите код страны и введите номер телефона."
        case 2: return "Мы отправили СМС с кодом на номер\n\(phoneNumber)"
        case 3: return "Добавьте почту для восстановления доступа к вашему HQ ID."
        default: return ""
        }
    }
    
    var buttonText: String {
        switch step {
        case 1, 2: return "Продолжить"
        case 3: return "Завершить регистрацию"
        default: return ""
        }
    }
    
    // --- ЛОГИКА (ГОТОВА К ПОДКЛЮЧЕНИЮ РЕАЛЬНОГО БЕКЕНДА) ---
    func handleAction() {
        if step == 1 && phoneNumber.count > 10 {
            isLoading = true
            // ТУТ БУДЕТ ЗАПРОС К FIREBASE ИЛИ ТВОЕМУ RYZEN ДЛЯ ОТПРАВКИ СМС
            // Сейчас просто переключаем UI для теста интерфейса
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                isLoading = false
                withAnimation { step = 2 }
            }
        } else if step == 2 && smsCode.count >= 4 {
            isLoading = true
            // ТУТ БУДЕТ ЗАПРОС ДЛЯ ПРОВЕРКИ КОДА
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                isLoading = false
                withAnimation { step = 3 }
            }
        } else if step == 3 {
            // Отправка email на сервер и завершение
            finishRegistration()
        }
    }
    
    func finishRegistration() {
        // Успешный вход
        UserDefaults.standard.set(true, forKey: "isRegistered")
        withAnimation { isRegistered = true }
    }
}
