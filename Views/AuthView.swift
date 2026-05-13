import SwiftUI

struct AuthView: View {
    @EnvironmentObject var meshManager: MeshNetworkManager
    
    // States
    @State private var email = ""
    @State private var code = ""
    @State private var username = ""
    @State private var nickname = ""
    @State private var acceptedEULA = false
    @State private var logoScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Background Layer
            Color(red: 0.01, green: 0.02, blue: 0.06).ignoresSafeArea()
            
            // Atmospheric Glow
            RadialGradient(gradient: Gradient(colors: [Color.blue.opacity(0.12), .clear]), center: .topLeading, startRadius: 100, endRadius: 600).ignoresSafeArea()
            RadialGradient(gradient: Gradient(colors: [Color.cyan.opacity(0.08), .clear]), center: .bottomTrailing, startRadius: 100, endRadius: 500).ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Branding Header
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.cyan.opacity(0.1))
                            .frame(width: 130, height: 130)
                            .scaleEffect(logoScale)
                        
                        Image(systemName: "shield.righthalf.filled")
                            .font(.system(size: 70, weight: .thin))
                            .foregroundColor(.cyan)
                            .shadow(color: .cyan.opacity(0.6), radius: 15)
                    }
                    .padding(.top, 60)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                            logoScale = 1.15
                        }
                    }
                    
                    Text("HQ Global")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(1.5)
                    
                    Text(authSubtitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .frame(height: 60)
                }

                Spacer()

                // MARK: - Input Form
                VStack(spacing: 24) {
                    Group {
                        if meshManager.authStep == .enterEmail {
                            VStack(spacing: 16) {
                                HQInput(icon: "envelope.fill", placeholder: "Адрес электронной почты", text: $email, type: .emailAddress)
                                
                                HStack(spacing: 12) {
                                    Button(action: { acceptedEULA.toggle() }) {
                                        Image(systemName: acceptedEULA ? "checkmark.square.fill" : "square")
                                            .font(.title2).foregroundColor(acceptedEULA ? .cyan : .gray)
                                    }
                                    Text("Принимаю Пользовательское соглашение").font(.caption).foregroundColor(.gray)
                                    Spacer()
                                }.padding(.horizontal, 10)
                            }
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        } else if meshManager.authStep == .enterCode {
                            HQInput(icon: "lock.shield.fill", placeholder: "Код подтверждения", text: $code, type: .numberPad)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        } else {
                            VStack(spacing: 16) {
                                HQInput(icon: "at", placeholder: "Уникальный ID", text: $username, type: .default)
                                HQInput(icon: "person.crop.circle", placeholder: "Имя (Nickname)", text: $nickname, type: .default)
                            }
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: meshManager.authStep)

                    if !meshManager.authError.isEmpty {
                        Text(meshManager.authError).foregroundColor(.red).font(.caption.bold()).multilineTextAlignment(.center)
                    }

                    Button(action: handlePrimaryAction) {
                        ZStack {
                            if meshManager.isWaiting { ProgressView().tint(.black) }
                            else { Text(buttonTitle).font(.system(size: 18, weight: .bold)) }
                        }
                        .frame(maxWidth: .infinity).frame(height: 60)
                        .background(Color.cyan).cornerRadius(20).foregroundColor(.black)
                        .shadow(color: .cyan.opacity(0.3), radius: 10, y: 5)
                    }
                    .disabled(meshManager.isWaiting || (meshManager.authStep == .enterEmail && !acceptedEULA))
                    .opacity((meshManager.authStep == .enterEmail && !acceptedEULA) ? 0.6 : 1.0)
                }
                .padding(32)
                .background(Color.white.opacity(0.05))
                .cornerRadius(35)
                .overlay(RoundedRectangle(cornerRadius: 35).stroke(Color.white.opacity(0.1), lineWidth: 1))
                .padding(.horizontal, 20)
                .padding(.bottom, 50)
            }
        }
    }

    private var authSubtitle: String {
        switch meshManager.authStep {
        case .enterEmail: return "Активация децентрализованного узла.\nВведите почту для авторизации."
        case .enterCode: return "Защищенный туннель открыт.\nКод доступа отправлен на почту."
        case .setupProfile: return "Почти готово. Создайте свой\nуникальный профиль в Империи."
        }
    }

    private var buttonTitle: String {
        switch meshManager.authStep {
        case .enterEmail: return "ПОЛУЧИТЬ ДОСТУП"
        case .enterCode: return "ПОДТВЕРДИТЬ"
        case .setupProfile: return "ВОЙТИ В ИМПЕРИЮ"
        }
    }

    private func handlePrimaryAction() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        switch meshManager.authStep {
        case .enterEmail: meshManager.requestAccessCode(email: email)
        case .enterCode: meshManager.authStep = .setupProfile
        case .setupProfile: meshManager.registerEmpireNode(email: email, code: code, username: username, nickname: nickname)
        }
    }
}

struct HQInput: View {
    let icon: String; let placeholder: String; @Binding var text: String; let type: UIKeyboardType
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon).foregroundColor(.cyan).frame(width: 25)
            TextField(placeholder, text: $text)
                .foregroundColor(.white)
                .keyboardType(type)
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
        .padding(18).background(Color.black.opacity(0.4)).cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}