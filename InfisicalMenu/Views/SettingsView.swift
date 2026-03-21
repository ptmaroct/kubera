import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    let onDismiss: () -> Void

    @State private var projects: [InfisicalProject] = []
    @State private var selectedProject: InfisicalProject?
    @State private var selectedEnvironment: InfisicalEnvironment?
    @State private var secretPath: String = "/"
    @State private var isLoading = true
    @State private var statusMessage: String?
    @State private var appeared = false

    var body: some View {
        ZStack {
            WindowBackground()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Settings")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.vault.text)
                        if let config = AppConfiguration.load(), let name = config.projectName {
                            Text("Connected to \(name)")
                                .font(.system(size: 11))
                                .foregroundColor(Color.vault.textTertiary)
                        }
                    }
                    Spacer()
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color.vault.textTertiary)
                }
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 20)

                if isLoading {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading projects...")
                        .font(.system(size: 12))
                        .foregroundColor(Color.vault.textSecondary)
                        .padding(.top, 8)
                    Spacer()
                } else {
                    VStack(spacing: 14) {
                        VaultPicker(
                            label: "Project",
                            selection: $selectedProject,
                            options: projects,
                            displayName: { $0.name }
                        )
                        .onChange(of: selectedProject) { _ in
                            if let project = selectedProject {
                                selectedEnvironment = project.environments.first
                            }
                        }

                        if let envs = selectedProject?.environments, !envs.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("ENVIRONMENT")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(Color.vault.textSecondary)
                                    .tracking(1.2)

                                HStack(spacing: 6) {
                                    ForEach(envs) { env in
                                        let isSelected = selectedEnvironment?.id == env.id
                                        Button {
                                            withAnimation(.spring(response: 0.3)) {
                                                selectedEnvironment = env
                                            }
                                        } label: {
                                            Text(env.name)
                                                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                                                .foregroundColor(isSelected ? Color.vault.bg : Color.vault.textSecondary)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 6)
                                                .background(isSelected ? Color.vault.accent : Color.vault.bg)
                                                .cornerRadius(6)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .stroke(isSelected ? Color.vault.accent : Color.vault.border, lineWidth: 1)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        VaultTextField(label: "Secret Path", text: $secretPath, isMonospaced: true)
                    }
                    .padding(.horizontal, 28)

                    // Shortcut info
                    VaultCard {
                        HStack(spacing: 10) {
                            Image(systemName: "command")
                                .font(.system(size: 12))
                                .foregroundColor(Color.vault.accent)

                            Text("Cmd + Shift + K")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(Color.vault.text)

                            Spacer()

                            Text("Toggle menu")
                                .font(.system(size: 11))
                                .foregroundColor(Color.vault.textTertiary)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 16)

                    Spacer()
                }

                if let msg = statusMessage {
                    Text(msg)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(msg.contains("Saved") ? Color.vault.success : Color.vault.error)
                        .padding(.bottom, 4)
                        .transition(.opacity)
                }

                // Footer buttons
                HStack {
                    VaultButton(title: "Cancel", style: .ghost) {
                        onDismiss()
                    }

                    Spacer()

                    VaultButton(
                        title: "Save",
                        style: .primary,
                        isDisabled: selectedProject == nil || selectedEnvironment == nil
                    ) {
                        save()
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
            }
        }
        .frame(width: 440, height: 400)
        .preferredColorScheme(.dark)
        .onAppear {
            loadData()
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                appeared = true
            }
        }
    }

    private func loadData() {
        Task {
            isLoading = true
            do {
                let orgs = try await InfisicalCLIService.fetchOrganizations()
                if let org = orgs.first {
                    projects = try await InfisicalCLIService.fetchProjects(orgId: org.id)
                }
            } catch {
                statusMessage = error.localizedDescription
            }

            if let config = AppConfiguration.load() {
                selectedProject = projects.first(where: { $0.id == config.projectId })
                if let project = selectedProject {
                    selectedEnvironment = project.environments.first(where: { $0.slug == config.environment })
                }
                secretPath = config.secretPath
            }

            isLoading = false
        }
    }

    private func save() {
        guard let project = selectedProject,
              let env = selectedEnvironment else { return }

        let config = AppConfiguration(
            projectId: project.id,
            environment: env.slug,
            secretPath: secretPath,
            baseURL: AppConfiguration.defaultBaseURL,
            projectName: project.name
        )
        config.save()
        viewModel.configurationSaved()
        withAnimation { statusMessage = "Saved!" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            onDismiss()
        }
    }
}
