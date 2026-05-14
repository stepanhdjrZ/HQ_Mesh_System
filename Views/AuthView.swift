import Foundation
import SwiftUI
import Combine

// 🎯 ВОТ ОН, НАШ ПОТЕРЯННЫЙ ПАРТИЗАН
enum MeshAuthStep {
    case enterEmail
    case enterCode
    case setupProfile
}

final class AuthViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var code: String = ""
    @Published var username: String = ""
    @Published var nickname: String = ""
    @Published var acceptedEULA: Bool = false
    
    // Продвинутая валидация
    var isEmailValid: Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return NSPredicate(format:"SELF MATCHES %@", emailRegEx).evaluate(with: email)
    }
    
    var canSubmitEmail: Bool {
        isEmailValid && acceptedEULA
    }
    
    // Логика UI-состояний
    func getHeaderTitle(step: MeshAuthStep) -> String {
        switch step {
        case .enterEmail: return "Вход в Империю"
        case .enterCode: return "Проверка туннеля"
        case .setupProfile: return "Профиль узла"
        }
    }
    
    func getHeaderSubtitle(step: MeshAuthStep) -> String {
        switch step {
        case .enterEmail: return "Введите вашу почту для получения ключа доступа."
        case .enterCode: return "Мы отправили секретный код. Введите его для синхронизации."
        case .setupProfile: return "Последний шаг. Выберите имя, которое увидят другие узлы."
        }
    }
}
