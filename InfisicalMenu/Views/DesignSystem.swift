import SwiftUI

// MARK: - Colors

extension Color {
    static let vault = VaultColors()
}

struct VaultColors {
    let bg = Color(red: 0.07, green: 0.07, blue: 0.09)
    let surface = Color(red: 0.11, green: 0.11, blue: 0.14)
    let surfaceHover = Color(red: 0.15, green: 0.15, blue: 0.18)
    let border = Color.white.opacity(0.08)
    let borderFocus = Color(red: 0.96, green: 0.65, blue: 0.14).opacity(0.5)
    let accent = Color(red: 0.96, green: 0.65, blue: 0.14)       // Warm amber
    let accentSoft = Color(red: 0.96, green: 0.65, blue: 0.14).opacity(0.15)
    let text = Color.white.opacity(0.92)
    let textSecondary = Color.white.opacity(0.5)
    let textTertiary = Color.white.opacity(0.3)
    let success = Color(red: 0.2, green: 0.84, blue: 0.5)
    let error = Color(red: 1.0, green: 0.4, blue: 0.35)
    let warning = Color(red: 1.0, green: 0.72, blue: 0.3)
}

// MARK: - Reusable Components

struct VaultCard<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding(16)
            .background(Color.vault.surface)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.vault.border, lineWidth: 1)
            )
    }
}

struct VaultTextField: View {
    let label: String
    @Binding var text: String
    var isMonospaced: Bool = false
    var isSecure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .default))
                .foregroundColor(Color.vault.textSecondary)
                .tracking(1.2)

            Group {
                if isSecure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                }
            }
            .font(isMonospaced ? .system(size: 13, design: .monospaced) : .system(size: 13))
            .foregroundColor(Color.vault.text)
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.vault.bg)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.vault.border, lineWidth: 1)
            )
        }
    }
}

struct VaultPicker<T: Hashable & Identifiable>: View where T: CustomStringConvertible {
    let label: String
    @Binding var selection: T?
    let options: [T]
    let displayName: (T) -> String

    init(label: String, selection: Binding<T?>, options: [T], displayName: @escaping (T) -> String) {
        self.label = label
        self._selection = selection
        self.options = options
        self.displayName = displayName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .default))
                .foregroundColor(Color.vault.textSecondary)
                .tracking(1.2)

            Picker("", selection: $selection) {
                Text("Select...").tag(nil as T?)
                ForEach(options) { option in
                    Text(displayName(option)).tag(option as T?)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.vault.bg)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.vault.border, lineWidth: 1)
            )
        }
    }
}

struct VaultButton: View {
    let title: String
    var style: Style = .primary
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    enum Style {
        case primary, secondary, ghost
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                }
                Text(title)
                    .font(.system(size: 13, weight: style == .primary ? .semibold : .medium))
            }
            .padding(.horizontal, style == .ghost ? 8 : 20)
            .padding(.vertical, 8)
            .foregroundColor(foregroundColor)
            .background(backgroundColor)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.4 : 1.0)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return Color.vault.bg
        case .secondary: return Color.vault.text
        case .ghost: return Color.vault.textSecondary
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return Color.vault.accent
        case .secondary: return Color.vault.surface
        case .ghost: return .clear
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary: return Color.vault.accent
        case .secondary: return Color.vault.border
        case .ghost: return .clear
        }
    }
}

struct StepIndicator: View {
    let totalSteps: Int
    let currentStep: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? Color.vault.accent : Color.vault.border)
                    .frame(width: step == currentStep ? 24 : 8, height: 4)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentStep)
            }
        }
    }
}

struct PulsingKeyIcon: View {
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(Color.vault.accent.opacity(0.1))
                .frame(width: 88, height: 88)
                .scaleEffect(isPulsing ? 1.15 : 1.0)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isPulsing)

            // Inner glow
            Circle()
                .fill(Color.vault.accent.opacity(0.08))
                .frame(width: 72, height: 72)

            // Icon background
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.vault.accent, Color.vault.accent.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)
                .shadow(color: Color.vault.accent.opacity(0.4), radius: 12, y: 4)

            Image(systemName: "key.fill")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(Color.vault.bg)
                .rotationEffect(.degrees(-45))
        }
        .onAppear { isPulsing = true }
    }
}

struct CLICommandBlock: View {
    let command: String
    @State private var copied = false

    var body: some View {
        HStack(spacing: 0) {
            Text("$")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color.vault.accent)
                .padding(.trailing, 8)

            Text(command)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(Color.vault.text)

            Spacer()

            Button {
                ClipboardService.copy(command, clearAfter: 300)
                withAnimation(.spring(response: 0.3)) { copied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.spring(response: 0.3)) { copied = false }
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(copied ? Color.vault.success : Color.vault.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.vault.bg)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.vault.border, lineWidth: 1)
        )
    }
}

// MARK: - Window Background

struct WindowBackground: View {
    var body: some View {
        ZStack {
            Color.vault.bg

            // Subtle gradient orb top-right
            Circle()
                .fill(Color.vault.accent.opacity(0.03))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: 120, y: -100)

            // Subtle gradient orb bottom-left
            Circle()
                .fill(Color.vault.accent.opacity(0.02))
                .frame(width: 200, height: 200)
                .blur(radius: 60)
                .offset(x: -100, y: 100)
        }
    }
}

// Conformances for picker support
extension InfisicalOrg: CustomStringConvertible {
    var description: String { name }
}

extension InfisicalProject: CustomStringConvertible {
    var description: String { name }
}

extension InfisicalEnvironment: CustomStringConvertible {
    var description: String { name }
}

extension InfisicalTag: CustomStringConvertible {
    var description: String { name }
}

// MARK: - Color Hex Initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double((rgbValue & 0x0000FF)) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - VaultTextEditor (multiline)

struct VaultTextEditor: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var lineCount: Int = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .default))
                .foregroundColor(Color.vault.textSecondary)
                .tracking(1.2)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.system(size: 13))
                    .foregroundColor(Color.vault.text)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(height: CGFloat(lineCount) * 20)

                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 13))
                        .foregroundColor(Color.vault.textTertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
            }
            .background(Color.vault.bg)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.vault.border, lineWidth: 1)
            )
        }
    }
}
