import SwiftUI
import UIKit

// MARK: - Particles Engine
struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
}

class ParticleSystem: ObservableObject {
    @Published var particles: [Particle] = []
    let count = 35
    
    func setup(in size: CGSize) {
        particles = (0..<count).map { _ in
            Particle(
                position: CGPoint(x: CGFloat.random(in: 0...size.width), y: CGFloat.random(in: 0...size.height)),
                velocity: CGVector(dx: CGFloat.random(in: -0.4...0.4), dy: CGFloat.random(in: -0.4...0.4))
            )
        }
    }
    func update(in size: CGSize) {
        for i in particles.indices {
            var p = particles[i]
            p.position.x += p.velocity.dx
            p.position.y += p.velocity.dy
            if p.position.x < 0 || p.position.x > size.width { p.velocity.dx *= -1 }
            if p.position.y < 0 || p.position.y > size.height { p.velocity.dy *= -1 }
            particles[i] = p
        }
    }
}

// MARK: - Main Auth View
struct AuthView: View {
    @EnvironmentObject var meshManager: MeshNetworkManager
    
    @State private var email = ""
    @State private var code = ""
    @State private var username = ""
    @State private var nickname = ""
    
    // APPLE REQUIREMENT: EULA Agreement
    @State private var acceptedEULA = false
    
    @StateObject private var system = ParticleSystem()
    @State private var animationTimer: Timer?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(colors: [Color(red: 0.02, green: 0.05, blue: 0.15), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
                
                // Mesh Background
                Canvas { context, size in
                    let particles = system.particles
                    for i in 0..<particles.count {
                        for j in (i+1)...<particles.count {
                            let p1 = particles[i].position; let p2 = particles[j].position
                            let distance = hypot(p1.x - p2.x, p1.y - p2.y)
                            if distance < 130 {
                                var path = Path(); path.move(to: p1); path.addLine(to: p2)
                                let opacity = 1.0 - (distance / 130)
                                context.stroke(path, with: .color(.cyan.opacity(opacity * 0.4)), lineWidth: 1)
                            }
                        }
                    }
                    for particle in particles {
                        let rect = CGRect(x: particle.position.x - 2, y: particle.position.y - 2, width: 4, height: 4)
                        context.fill(Path(ellipseIn: rect), with: .color(.blue.opacity(0.8)))
                    }
                }
                .ignoresSafeArea()
                .onAppear {
                    system.setup(in: geometry.size)
                    animationTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in system.update(in: geometry.size) }
                }
                .onDisappear { animationTimer?.invalidate() }
                
                // Content
                VStack(spacing: 0) {
                    VStack(spacing: 20) {
                        ZStack {
                            Circle().fill(LinearGradient(colors: [.blue.opacity(0.2), .cyan.opacity(0.1)], startPoint: .top, endPoint: .bottom)).frame(width: 110, height: 110).blur(radius: 10)
                            Image(systemName: "shield.righthalf.filled").font(.system(size: 65, weight: .thin)).foregroundColor(.cyan).shadow(color: .cyan.opacity(0.8), radius: 15)
                        }.padding(.top, 60)
                        
                        Text("HQ Global").font(.system(size: 42, weight: .black, design: .rounded)).foregroundColor(.white).shadow(color: .blue.opacity(0.5), radius: 20)
                        Text(subtitleText).font(.subheadline).foregroundColor(.white.opacity(0.7)).multilineTextAlignment(.center).lineSpacing(4).frame(height: 50)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 24) {
                        Group {
                            if meshManager.authStep == .enterEmail {
                                VStack(spacing: 16) {
                                    PremiumField(icon: "envelope.fill", placeholder: "Адрес почты", text: $email, keyboard: .emailAddress)
                                    
                                    // APPLE REQUIREMENT: EULA Checkbox
                                    HStack {
                                        Button(action: { acceptedEULA.toggle(); UIImpactFeedbackGenerator(style: .light).impactOccurred() }) {
                                            Image(systemName: acceptedEULA ? "checkmark.square.fill" : "square")
                                                .foregroundColor(acceptedEULA ? .cyan : .gray)
                                                .font(.system(size: 20))
                                        }
                                        Text("Я принимаю Пользовательское соглашение (EULA) и Политику конфиденциальности")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 8)
                                }
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
                            Text(meshManager.authError).foregroundColor(.red).font(.footnote.bold()).padding(.top, 4).transition(.opacity)
                        }
                        
                        Button(action: processAction) {
                            ZStack {
                                if meshManager.isWaitingForServer { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)) }
                                else { Text(buttonText).font(.headline.weight(.bold)).foregroundColor(.white) }
                            }
                            .frame(maxWidth: .infinity).frame(height: 60)
                            .background(LinearGradient(colors: [.blue, Color(red: 0.1, green: 0.4, blue: 0.9)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .cornerRadius(20).shadow(color: .blue.opacity(0.4), radius: 15, y: 8)
                        }
                        .disabled(meshManager.isWaitingForServer || (meshManager.authStep == .enterEmail && !acceptedEULA))
                        .opacity((meshManager.authStep == .enterEmail && !acceptedEULA) ? 0.5 : 1.0)
                        .padding(.top, 10)
                    }
                    .padding(30)
                    .background(RoundedRectangle(cornerRadius: 30).fill(Color.white.opacity(0.05)).background(Material.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 30)))
                    .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 50)
                }
            }
        }
    }
    
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
    
    private func processAction() {
        meshManager.authError = ""
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        switch meshManager.authStep {
        case .enterEmail:
            let clean = email.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty && acceptedEULA { meshManager.requestEmailCode(email: clean) }
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

struct PremiumField: View {
    let icon: String; let placeholder: String; @Binding var text: String; let keyboard: UIKeyboardType
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon).font(.system(size: 20)).foregroundColor(.cyan).frame(width: 30)
            ZStack(alignment: .leading) {
                if text.isEmpty { Text(placeholder).foregroundColor(.white.opacity(0.3)) }
                TextField("", text: $text).foregroundColor(.white).keyboardType(keyboard).textInputAutocapitalization(.never).disableAutocorrection(true)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 18)
        .background(Color.black.opacity(0.3)).cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}
