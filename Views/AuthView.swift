import SwiftUI
import UIKit

// MARK: - Надежная система частиц (iOS 15 Safe)
struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var life: Double
}

class ParticleSystem: ObservableObject {
    @Published var particles: [Particle] = []
    let maxParticles = 30
    
    func setup(width: CGFloat, height: CGFloat) {
        particles = (0..<maxParticles).map { _ in
            Particle(
                position: CGPoint(x: CGFloat.random(in: 0...width), y: CGFloat.random(in: 0...height)),
                velocity: CGVector(dx: CGFloat.random(in: -0.2...0.2), dy: CGFloat.random(in: -0.2...0.2)),
                life: Double.random(in: 0.5...1.0)
            )
        }
    }
    
    func update(width: CGFloat, height: CGFloat) {
        for i in particles.indices {
            var p = particles[i]
            p.position.x += p.velocity.dx
            p.position.y += p.velocity.dy
            
            if p.position.x < 0 || p.position.x > width { p.velocity.dx *= -1 }
            if p.position.y < 0 || p.position.y > height { p.velocity.dy *= -1 }
            
            particles[i] = p
        }
    }
}

struct AuthView: View {
    @EnvironmentObject var meshManager: MeshNetworkManager
    
    @State private var email = ""
    @State private var code = ""
    @State private var username = ""
    @State private var nickname = ""
    @State private var acceptedEULA = false
    @State private var pulseLogo = false
    
    @StateObject private var system = ParticleSystem()
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.01, green: 0.02, blue: 0.08).ignoresSafeArea()
                
                // Оптимизированный фон (без Canvas для стабильности сборки)
                ZStack {
                    ForEach(system.particles) { particle in
                        Circle()
                            .fill(Color.cyan.opacity(particle.life * 0.5))
                            .frame(width: 4, height: 4)
                            .position(particle.position)
                    }
                }
                .onAppear { system.setup(width: geo.size.width, height: geo.size.height) }
                .onReceive(timer) { _ in system.update(width: geo.size.width, height: geo.size.height) }
                
                VStack(spacing: 0) {
                    // Header Area
                    VStack(spacing: 15) {
                        ZStack {
                            Circle()
                                .fill(RadialGradient(gradient: Gradient(colors: [.cyan.opacity(0.3), .clear]), center: .center, startRadius: 10, endRadius: 70))
                                .frame(width: 140, height: 140)
                                .scaleEffect(pulseLogo ? 1.05 : 0.95)
                                .animation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulseLogo)
                            
                            Image(systemName: "shield.righthalf.filled")
                                .font(.system(size: 70, weight: .light))
                                .foregroundColor(.cyan)
                                .shadow(color: .cyan.opacity(0.8), radius: 20)
                        }
                        .padding(.top, 50)
                        .onAppear { pulseLogo = true }
                        
                        Text("HQ Global")
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(dynamicSubtitle)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .frame(height: 50)
                    }
                    
                    Spacer()
                    
                    // Form Area
                    VStack(spacing: 20) {
                        Group {
                            if meshManager.authStep == .enterEmail {
                                VStack(spacing: 16) {
                                    PremiumInputCell(icon: "envelope.fill", placeholder: "Адрес почты", text: $email, keyboard: .emailAddress)
                                    HStack(alignment: .top, spacing: 12) {
                                        Button(action: {
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            acceptedEULA.toggle()
                                        }) {
                                            Image(systemName: acceptedEULA ? "checkmark.square.fill" : "square")
                                                .font(.system(size: 24))
                                                .foregroundColor(acceptedEULA ? .cyan : .gray)
                                        }
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Регистрируясь, вы принимаете").foregroundColor(.gray)
                                            Text("Соглашение и Политику").foregroundColor(.cyan).underline()
                                        }.font(.caption)
                                        Spacer()
                                    }.padding(.horizontal, 8)
                                }.transition(.opacity)
                            } 
                            else if meshManager.authStep == .enterCode {
                                PremiumInputCell(icon: "lock.shield.fill", placeholder: "Секретный код", text: $code, keyboard: .numberPad)
                                    .transition(.opacity)
                            } 
                            else if meshManager.authStep == .setupProfile {
                                VStack(spacing: 16) {
                                    PremiumInputCell(icon: "at", placeholder: "Уникальный ID", text: $username, keyboard: .default)
                                    PremiumInputCell(icon: "person.crop.circle", placeholder: "Отображаемое Имя", text: $nickname, keyboard: .default)
                                }.transition(.opacity)
                            }
                        }
                        .animation(.easeInOut, value: meshManager.authStep)
                        
                        if !meshManager.authError.isEmpty {
                            Text(meshManager.authError).foregroundColor(.red).font(.system(size: 13, weight: .bold))
                        }
                        
                        Button(action: executeAuthProtocol) {
                            ZStack {
                                if meshManager.isWaitingForServer {
                                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text(dynamicButtonTitle).font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity).frame(height: 60)
                            .background(LinearGradient(colors: [.blue, Color(red: 0.05, green: 0.3, blue: 0.9)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .cornerRadius(20)
                        }
                        .disabled(meshManager.isWaitingForServer)
                        .padding(.top, 10)
                    }
                    .padding(30)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(30)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 50)
                }
            }
        }
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
    
    private func executeAuthProtocol() {
        meshManager.authError = ""
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        switch meshManager.authStep {
        case .enterEmail:
            if email.isEmpty { meshManager.authError = "Введите почту"; return }
            if !acceptedEULA { meshManager.authError = "Необходимо принять соглашение"; return }
            meshManager.requestEmailCode(email: email)
        case .enterCode:
            if !code.isEmpty { meshManager.authStep = .setupProfile }
            else { meshManager.authError = "Введите код" }
        case .setupProfile:
            if !username.isEmpty && !nickname.isEmpty {
                meshManager.registerUser(email: email, code: code, username: username, nickname: nickname)
            } else { meshManager.authError = "Заполните все поля" }
        }
    }
}

struct PremiumInputCell: View {
    let icon: String; let placeholder: String; @Binding var text: String; let keyboard: UIKeyboardType
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon).font(.system(size: 20)).foregroundColor(.cyan).frame(width: 30)
            ZStack(alignment: .leading) {
                if text.isEmpty { Text(placeholder).foregroundColor(.white.opacity(0.3)).font(.body) }
                TextField("", text: $text).foregroundColor(.white).keyboardType(keyboard).autocapitalization(.none).disableAutocorrection(true).font(.system(size: 17, weight: .medium))
            }
        }
        .padding(18).background(Color.black.opacity(0.4)).cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}
