import SwiftUI

struct AddSecretView: View {
    @ObservedObject var viewModel: AppViewModel
    let onDismiss: () -> Void

    @State private var key = ""
    @State private var value = ""
    @State private var errorMessage: String?
    @State private var isCreating = false
    @State private var showSuccess = false

    var body: some View {
        ZStack {
            WindowBackground()

            if showSuccess {
                successOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                formContent
                    .transition(.opacity)
            }
        }
        .frame(width: 420, height: 300)
        .preferredColorScheme(.dark)
    }

    private var formContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("New Secret")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color.vault.text)

                    if let config = AppConfiguration.load(), let name = config.projectName {
                        Text(name + " / " + config.environment)
                            .font(.system(size: 11))
                            .foregroundColor(Color.vault.textTertiary)
                    }
                }
                Spacer()
                Image(systemName: "plus.square.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color.vault.accent.opacity(0.5))
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 20)

            VStack(spacing: 14) {
                VaultTextField(label: "Secret Name", text: $key, isMonospaced: true)
                VaultTextField(label: "Secret Value", text: $value, isSecure: true)
            }
            .padding(.horizontal, 28)

            if let error = errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 10))
                    Text(error)
                        .font(.system(size: 11))
                }
                .foregroundColor(Color.vault.error)
                .padding(.horizontal, 28)
                .padding(.top, 10)
                .transition(.opacity)
            }

            Spacer()

            HStack {
                VaultButton(title: "Cancel", style: .ghost) {
                    onDismiss()
                }

                Spacer()

                VaultButton(
                    title: isCreating ? "Creating..." : "Create Secret",
                    style: .primary,
                    isLoading: isCreating,
                    isDisabled: key.isEmpty || value.isEmpty
                ) {
                    Task {
                        isCreating = true
                        errorMessage = nil
                        let success = await viewModel.createSecret(key: key, value: value)
                        isCreating = false
                        if success {
                            withAnimation(.spring(response: 0.4)) {
                                showSuccess = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                onDismiss()
                            }
                        } else {
                            withAnimation { errorMessage = viewModel.errorMessage ?? "Failed to create secret" }
                        }
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
    }

    private var successOverlay: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.vault.success.opacity(0.1))
                    .frame(width: 64, height: 64)

                Image(systemName: "checkmark")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Color.vault.success)
            }

            Text("Secret Created")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.vault.text)

            Text(key)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(Color.vault.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.vault.accentSoft)
                .cornerRadius(4)
        }
    }
}
