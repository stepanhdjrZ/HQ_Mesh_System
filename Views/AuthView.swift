import SwiftUI

struct AuthView: View {
    @EnvironmentObject var manager: MeshNetworkManager
    @StateObject private var vm = AuthViewModel()
    
    var body: some View {
        ZStack {
            HQBackground() // Наш неоновый фон из UI/HQComponents
            
            VStack(spacing: 0) {
                // MARK: - Branding
                VStack(spacing: 20) {
                    Image(systemName: "shield.righthalf.filled")
                        .font(.system(size: 80, weight: .ultraLight))
                        .foregroundColor(.cyan)
                        .shadow(color: .cyan.opacity(0.5), radius: 20)
                    
                    Text(vm.getHeaderTitle(step: manager.authStep))
                        .font(.system(size: 34, weight: .black, design: .rounded))
                    
                    Text(vm.getHeaderSubtitle(step: manager.authStep))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.top, 60)
                
                Spacer()
                
                // MARK: - Dynamic Form
                VStack(spacing: 20) {
                    switch manager.authStep {
                    case .enterEmail:
                        TextField("Электронная почта", text: $vm.email)
                            .hqInput()
                            .keyboardType(.emailAddress)
                        
                        HStack {
                            Toggle("", isOn: $vm.acceptedEULA).labelsHidden()
                            Text("Принимаю условия протокола HQ").font(.caption).foregroundColor(.gray)
                            Spacer()
                        }
                        
                    case .enterCode:
                        TextField("Код из письма", text: $vm.code)
                            .hqInput()
                            .keyboardType(.numberPad)
                        
                    case .setupProfile:
                        TextField("Уникальный ID", text: $vm.username).hqInput()
                        TextField("Отображаемое имя", text: $vm.nickname).hqInput()
                    }
                    
                    Button(action: handleAction) {
                        ZStack {
                            if manager.isProcessing { ProgressView().tint(.black) }
                            else { Text("ПРОДОЛЖИТЬ").bold() }
                        }
                    }
                    .buttonStyle(HQPrimaryButton(isDisabled: manager.isProcessing || (manager.authStep == .enterEmail && !vm.acceptedEULA)))
                }
                .padding(30)
                .background(Color.white.opacity(0.05))
                .cornerRadius(30)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }
    
    private func handleAction() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        switch manager.authStep {
        case .enterEmail: manager.initiateAuth(email: vm.email)
        case .enterCode: manager.authStep = .setupProfile
        case .setupProfile: manager.completeRegistration(nick: vm.nickname, user: vm.username)
        }
    }
}
