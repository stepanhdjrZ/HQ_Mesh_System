import SwiftUI

struct HQPrimaryButton: ButtonStyle {
    var isDisabled: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(isDisabled ? Color.gray : Color.cyan)
            .cornerRadius(18)
            .foregroundColor(.black)
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(isDisabled ? 0.5 : 1.0)
            .shadow(color: Color.cyan.opacity(isDisabled ? 0 : 0.3), radius: 10, y: 5)
    }
}

struct HQInputStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
            .foregroundColor(.white)
            .font(.system(size: 16, weight: .medium, design: .default))
    }
}

extension View {
    func hqInput() -> some View {
        self.modifier(HQInputStyle())
    }
}
