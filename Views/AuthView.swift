import SwiftUI
import UIKit

// MARK: - Фоновые Частицы (Магия Меш-сети)
struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
}

class ParticleSystem: ObservableObject {
    @Published var particles: [Particle] = []
    let count = 40
    
    func setup(in size: CGSize) {
        particles = (0..<count).map { _ in
            Particle(
                position: CGPoint(x: CGFloat.random(in: 0...size.width), y: CGFloat.random(in: 0...size.height)),
                velocity: CGVector(dx: CGFloat.random(in: -0.5...0.5), dy: CGFloat.random(in: -0.5...0.5))
            )
        }
    }
    
    func update(in size: CGSize) {
        for i in particles.indices {
            var p = particles[i]
            p.position.x += p.velocity.dx
            p.position.y += p.velocity.dy
            
            // Отскок от краев экрана
            if p.position.x < 0 || p.position.x > size.width { p.velocity.dx *= -1 }
            if p.position.y < 0 || p.position.y > size.height { p.velocity.dy *= -1 }
            
            particles[i] = p
        }
    }
}

// MARK: - ГЛАВНЫЙ ЭКРАН ВХОДА
struct AuthView: View {
    @EnvironmentObject var meshManager: MeshNetworkManager
    
    @State private var email = ""
    @State private var code = ""
    @State private var username = ""
    @State private var nickname = ""
    
    @StateObject private var system = ParticleSystem()
    @State private var animationTimer: Timer?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. Глубокий градиентный фон
                LinearGradient(
                    colors: [Color(red: 0.02, green: 0.05, blue: 0.15), Color.black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ).ignoresSafeArea()
                
                // 2. Живая Mesh-сеть на фоне (WOW ЭФФЕКТ)
                Canvas { context, size in
                    let particles = system.particles
                    
                    // Рисуем линии между близкими узлами
                    for i in 0..<particles.count {
                        for j in (i+1)..<particles.count {
                            let p1 = particles[i].position
                            let p2 = particles[j].position
                            let distance = hypot(p1.x - p2.x, p1.y - p2.y)
                            
                            if distance < 120 {
                                var path = Path()
                                path.move(to: p1)
                                path.addLine(to: p2)
                                let opacity = 1.0 - (distance / 120)
                                context.stroke(path, with: .color(.blue.opacity(opacity * 0.4)), lineWidth: 1)
                            }
                        }
                    }
                    
                    // Рисуем сами узлы (точки)
                    for particle in particles {
                        let rect = CGRect(x: particle.position.x - 2, y: particle.position.y - 2, width: 4, height: 4)
                        context.fill(Path(ellipseIn: rect), with: .color(.cyan.opacity(0.8)))
                    }
                }
                .ignoresSafeArea()
                .onAppear {
                    system.setup(in: geometry.size)
                    animationTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
                        system.update(in: geometry.size)
                    }
                }
                .onDisappear { animationTimer?.invalidate() }
                
                // 3. КОНТЕНТ ПОВЕРХ СЕТКИ
                VStack(spacing: 0) {
                    // Хедер
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.blue.opacity(0.2), .cyan.opacity(0.1)], startPoint: .top, endPoint: .bottom))
                                .frame(width: 110, height: 110)
                                .blur(radius: 10)
                            
                            Image(systemName: "shield.righthalf.filled")
                                .font(.system(size: 65, weight: .thin))
                                .foregroundColor(.cyan)
                                .shadow(color: .cyan.opacity(0.8), radius: 15)
                        }
                        .padding(.top, 60)
                        
                        Text("HQ Global")
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .blue.opacity(0.5), radius: 20)
                        
                        Text(subtitleText)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .frame(height: 50)
                    }
                    
                    Spacer()
                    
                    // Эффект матового стекла для формы
                    VStack(spacing: 24) {
                        Group {
                            if meshManager.authStep == .enterEmail {
                                PremiumField(icon: "envelope.fill", placeholder: "Адрес почты", text: $email, keyboard: .emailAddress)
                                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                            } else if meshManager.authStep == .enterCode {
                                PremiumField(icon: "key.fill", placeholder: "Код из письма", text: $code, keyboard: .numberPad)
                                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                            } else if meshManager.authStep == .setupProfile {
                                VStack(spacing: 16) {
                                    PremiumField(icon: "at", placeholder: "username", text: $username, keyboard: .default)
                                    PremiumField(icon: "person.fill", placeholder: "Отображаемое Имя", text: $nickname, keyboard: .default)
                                }
                                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                            }
                        }
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: meshManager.authStep)
                        
                        if !meshManager.authError.isEmpty {
                            Text(meshManager.authError)
                                .foregroundColor(.red)
                                .font(.footnote.bold())
                                .padding(.top, 8)
                                .transition(.opacity)
                        }
                        
                        // Кнопка действия
                        Button(action: processAction) {
                            ZStack {
                                if meshManager.isWaitingForServer {
                                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text(buttonText)
                                        .font(.headline.weight(.bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(
                                LinearGradient(colors: [.blue, Color(red: 0.1, green: 0.4, blue: 0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .cornerRadius(20)
                            .shadow(color: .blue.opacity(0.4), radius: 15, y: 8)
                        }
                        .disabled(meshManager.isWaitingForServer)
                        .padding(.top, 10)
                    }
                    .padding(30)
                    .background(
                        RoundedRectangle(cornerRadius: 30)
                            .fill(Color.white.opacity(0.05))
                            .background(Material.ultraThinMaterial) // Эффект стекла
                            .clipShape(RoundedRectangle(cornerRadius: 30))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 50)
                }
            }
        }
    }
    
    // MARK: - Тексты
    private var subtitleText: String {
        switch meshManager.authStep {
        case .enterEmail: return "Децентрализованный протокол связи.\nАвторизация для получения Node ID."
        case .enterCode: return "Защищенный канал открыт.\nКод доступа отправлен на \(email)"
        case .setupProfile: return "Последний этап генерации ключей.\nВведите данные узла Империи."
        }
    }
    
    private var buttonText: String {
        switch meshManager.authStep {
        case .enterEmail: return "Инициировать связь"
        case .enterCode: return "Подтвердить доступ"
        case .setupProfile: return "Создать Узел"
        }
    }
    
    // MARK: - Логика
    private func processAction() {
        meshManager.authError = ""
        UIImpactFeedbackGenerator(style: .medium).impactOccurred() // Тактильная отдача
        
        switch meshManager.authStep {
        case .enterEmail:
            let clean = email.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty { meshManager.requestEmailCode(email: clean) }
        case .enterCode:
            let clean = code.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty { meshManager.authStep = .setupProfile }
        case .setupProfile:
            let cleanUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanNick = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanUser.isEmpty && !cleanNick.isEmpty {
                meshManager.registerUser(email: email, code: code, username: cleanUser, nickname: cleanNick)
            }
        }
    }
}

// MARK: - Премиум Текстовое Поле
struct PremiumField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    let keyboard: UIKeyboardType
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.cyan)
                .frame(width: 30)
            
            ZStack(alignment: .leading) {
                if text.isEmpty { Text(placeholder).foregroundColor(.white.opacity(0.3)) }
                TextField("", text: $text)
                    .foregroundColor(.white)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(Color.black.opacity(0.3))
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}
