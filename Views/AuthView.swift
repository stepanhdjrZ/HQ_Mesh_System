import SwiftUI
import UIKit

// MARK: - Advanced Particle Physics Engine
struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var life: Double
}

class ParticleSystem: ObservableObject {
    @Published var particles: [Particle] = []
    let maxParticles = 45
    
    func setup(in size: CGSize) {
        particles = (0..<maxParticles).map { _ in
            Particle(
                position: CGPoint(x: CGFloat.random(in: 0...size.width), y: CGFloat.random(in: 0...size.height)),
                velocity: CGVector(dx: CGFloat.random(in: -0.3...0.3), dy: CGFloat.random(in: -0.3...0.3)),
                life: Double.random(in: 0.5...1.0)
            )
        }
    }
    
    func update(in size: CGSize) {
        for i in particles.indices {
            var p = particles[i]
            p.position.x += p.velocity.dx
            p.position.y += p.velocity.dy
            
            // Плавный отскок от границ Империи
            if p.position.x < 0 || p.position.x > size.width { p.velocity.dx *= -1 }
            if p.position.y < 0 || p.position.y > size.height { p.velocity.dy *= -1 }
            
            particles[i] = p
        }
    }
}

// MARK: - Premium Authorization View
struct AuthView: View {
    @EnvironmentObject var meshManager: MeshNetworkManager
    
    // Внутренние стейты формы
    @State private var email = ""
    @State private var code = ""
    @State private var username = ""
    @State private var nickname = ""
    
    // Юридический блок (Must-Have для AppStore)
    @State private var acceptedEULA = false
    @State private var showEULAError = false
    
    // Анимации
    @StateObject private var system = ParticleSystem()
    @State private var animationTimer: Timer?
    @State private var pulseLogo = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. Космический вакуум (Фон)
                LinearGradient(
                    colors: [Color(red: 0.01, green: 0.02, blue: 0.08), .black],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ).ignoresSafeArea()
                
                // 2. Движок генеративной сетки Mesh
                Canvas { context, size in
                    let particles = system.particles
                    for i in 0..<particles.count {
                        for j in (i+1)...<particles.count {
                            let p1 = particles[i].position
                            let p2 = particles[j].position
                            let distance = hypot(p1.x - p2.x, p1.y - p2.y)
                            
                            // Соединяем узлы квантовой нитью, если они близко
                            if distance < 140 {
                                var path = Path()
                                path.move(to: p1)
                                path.addLine(to: p2)
                                let opacity = 1.0 - (distance / 140)
                                context.stroke(path, with: .color(.cyan.opacity(opacity * 0.5)), lineWidth: 1.5)
                            }
                        }
                    }
                    // Отрисовка самих узлов
                    for particle in particles {
                        let rect = CGRect(x: particle.position.x - 2.5, y: particle.position.y - 2.5, width: 5, height: 5)
                        context.fill(Path(ellipseIn: rect), with: .color(.blue.opacity(particle.life)))
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
                
                // 3. UI Поверхность (Формы)
                VStack(spacing: 0) {
                    // MARK: Branding Header
                    VStack(spacing: 15) {
                        ZStack {
                            Circle()
                                .fill(RadialGradient(gradient: Gradient(colors: [.cyan.opacity(0.3), .clear]), center: .center, startRadius: 10, endRadius: 70))
                                .frame(width: 140, height: 140)
                                .scaleEffect(pulseLogo ? 1.1 : 0.9)
                                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulseLogo)
                            
                            Image(systemName: "shield.righthalf.filled")
                                .font(.system(size: 70, weight: .ultraLight))
                                .foregroundColor(.cyan)
                                .shadow(color: .cyan.opacity(0.8), radius: 20)
                        }
                        .padding(.top, 50)
                        .onAppear { pulseLogo = true }
                        
                        Text("HQ Global")
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .blue.opacity(0.6), radius: 15, y: 5)
                            .tracking(2)
                        
                        Text(dynamicSubtitle)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                            .frame(height: 60)
                    }
                    
                    Spacer()
                    
                    // MARK: Glassmorphism Action Card
                    VStack(spacing: 24) {
                        // Динамические поля ввода
                        Group {
                            if meshManager.authStep == .enterEmail {
                                VStack(spacing: 18) {
                                    PremiumInputCell(icon: "envelope.fill", placeholder: "Адрес электронной почты", text: $email, keyboard: .emailAddress)
                                    
                                    // EULA Agreement - Обязательно для Apple
                                    HStack(alignment: .top, spacing: 12) {
                                        Button(action: {
                                            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                                            withAnimation { acceptedEULA.toggle(); showEULAError = false }
                                        }) {
                                            Image(systemName: acceptedEULA ? "checkmark.square.fill" : "square")
                                                .font(.system(size: 24))
                                                .foregroundColor(showEULAError ? .red : (acceptedEULA ? .cyan : .gray.opacity(0.5)))
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Регистрируясь, вы принимаете")
                                                .foregroundColor(.gray)
                                            Text("Пользовательское соглашение и Политику конфиденциальности")
                                                .foregroundColor(.cyan)
                                                .underline()
                                        }
                                        .font(.caption)
                                    }
                                    .padding(.horizontal, 8)
                                }
                                .transition(authTransition)
                            } 
                            else if meshManager.authStep == .enterCode {
                                PremiumInputCell(icon: "lock.shield.fill", placeholder: "Секретный код", text: $code, keyboard: .numberPad)
                                    .transition(authTransition)
                            } 
                            else if meshManager.authStep == .setupProfile {
                                VStack(spacing: 16) {
                                    PremiumInputCell(icon: "at", placeholder: "Уникальный ID (username)", text: $username, keyboard: .default)
                                    PremiumInputCell(icon: "person.crop.circle.badge.checkmark", placeholder: "Отображаемое Имя", text: $nickname, keyboard: .default)
                                }
                                .transition(authTransition)
                            }
                        }
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: meshManager.authStep)
                        
                        // Обработка ошибок
                        if !meshManager.authError.isEmpty {
                            Text(meshManager.authError)
                                .foregroundColor(.red)
                                .font(.footnote.bold())
                                .padding(.top, 4)
                                .transition(.opacity)
                        }
                        
                        // Главная кнопка действия
                        Button(action: executeAuthProtocol) {
                            ZStack {
                                if meshManager.isWaitingForServer {
                                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(1.2)
                                } else {
                                    Text(dynamicButtonTitle)
                                        .font(.headline.weight(.heavy))
                                        .foregroundColor(.white)
                                        .tracking(1)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                            .background(
                                LinearGradient(colors: [.blue, Color(red: 0.05, green: 0.3, blue: 0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .cornerRadius(22)
                            .shadow(color: .blue.opacity(0.5), radius: 20, y: 10)
                        }
                        .disabled(meshManager.isWaitingForServer)
                        .padding(.top, 10)
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 36)
                            .fill(Color.black.opacity(0.4))
                            .background(Material.ultraThinMaterial)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 36).stroke(LinearGradient(colors: [.white.opacity(0.2), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 60)
                }
            }
        }
    }
    
    // MARK: - Computed Visuals
    private var authTransition: AnyTransition {
        .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity))
    }
    
    private var dynamicSubtitle: String {
        switch meshManager.authStep {
        case .enterEmail: return "Децентрализованный протокол HQ.\nАктивируйте узел Империи."
        case .enterCode: return "Защищенный туннель установлен.\nКод доступа отправлен на почту."
        case .setupProfile: return "Ключи шифрования сгенерированы.\nЗадайте публичные параметры."
        }
    }
    
    private var dynamicButtonTitle: String {
        switch meshManager.authStep {
        case .enterEmail: return "ПОЛУЧИТЬ ДОСТУП"
        case .enterCode: return "ВЕРИФИЦИРОВАТЬ"
        case .setupProfile: return "АКТИВИРОВАТЬ УЗЕЛ"
        }
    }
    
    // MARK: - State Logic
    private func executeAuthProtocol() {
        meshManager.authError = ""
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        
        switch meshManager.authStep {
        case .enterEmail:
            let clean = email.trimmingCharacters(in: .whitespacesAndNewlines)
            if clean.isEmpty { meshManager.authError = "Введите почту"; return }
            if !acceptedEULA { 
                withAnimation { showEULAError = true }
                meshManager.authError = "Необходимо принять соглашение"
                return 
            }
            meshManager.requestEmailCode(email: clean)
            
        case .enterCode:
            let clean = code.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty { meshManager.authStep = .setupProfile }
            else { meshManager.authError = "Введите код из письма" }
            
        case .setupProfile:
            let cleanUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanNick = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanUser.isEmpty && !cleanNick.isEmpty {
                meshManager.registerUser(email: email, code: code, username: cleanUser, nickname: cleanNick)
            } else {
                meshManager.authError = "Заполните все поля"
            }
        }
    }
}

// MARK: - Reusable UI Tools
struct PremiumInputCell: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    let keyboard: UIKeyboardType
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(.cyan)
                .frame(width: 30)
            
            ZStack(alignment: .leading) {
                if text.isEmpty { Text(placeholder).foregroundColor(.white.opacity(0.3)).font(.body) }
                TextField("", text: $text)
                    .foregroundColor(.white)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .font(.body.weight(.medium))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(Color.black.opacity(0.4))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
}
