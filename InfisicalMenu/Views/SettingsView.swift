import SwiftUI
import Carbon

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

    // Shortcut state
    @State private var shortcutKeyCode: UInt32 = AppConfiguration.defaultShortcutKeyCode
    @State private var shortcutModifiers: UInt32 = AppConfiguration.defaultShortcutModifiers
    @State private var isRecordingShortcut = false
    @State private var shortcutConflict: String?
    @State private var shortcutMonitor: Any?

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
                    ScrollView(.vertical, showsIndicators: false) {
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

                            // Divider
                            Rectangle()
                                .fill(Color.vault.border)
                                .frame(height: 1)
                                .padding(.vertical, 4)

                            // Keyboard shortcut section
                            shortcutSection
                        }
                        .padding(.horizontal, 28)
                    }

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
                        stopRecording()
                        onDismiss()
                    }

                    Spacer()

                    VaultButton(
                        title: "Save",
                        style: .primary,
                        isDisabled: selectedProject == nil || selectedEnvironment == nil
                    ) {
                        stopRecording()
                        save()
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
            }
        }
        .frame(width: 440, height: 480)
        .preferredColorScheme(.dark)
        .onAppear {
            loadData()
            loadShortcut()
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                appeared = true
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    // MARK: - Keyboard Shortcut Section

    private var shortcutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("KEYBOARD SHORTCUT")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color.vault.textSecondary)
                .tracking(1.2)

            HStack(spacing: 10) {
                // Shortcut display
                HStack(spacing: 6) {
                    if isRecordingShortcut {
                        Text("Press a key combo...")
                            .font(.system(size: 12))
                            .foregroundColor(Color.vault.accent)
                    } else {
                        Text(ShortcutHelper.displayString(keyCode: shortcutKeyCode, modifiers: shortcutModifiers))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.vault.text)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.vault.bg)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isRecordingShortcut ? Color.vault.accent : Color.vault.border, lineWidth: isRecordingShortcut ? 2 : 1)
                )
                .animation(.easeInOut(duration: 0.2), value: isRecordingShortcut)

                // Record / Stop button
                VaultButton(
                    title: isRecordingShortcut ? "Stop" : "Record",
                    style: isRecordingShortcut ? .primary : .secondary
                ) {
                    if isRecordingShortcut {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                }
            }

            // Conflict or status message
            if let conflict = shortcutConflict {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                    Text(conflict)
                        .font(.system(size: 10))
                }
                .foregroundColor(Color.vault.warning)
                .transition(.opacity)
            } else if !isRecordingShortcut {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 9))
                    Text("No conflicts detected")
                        .font(.system(size: 10))
                }
                .foregroundColor(Color.vault.success.opacity(0.7))
                .transition(.opacity)
            }

            // Reset to default
            let isDefault = shortcutKeyCode == AppConfiguration.defaultShortcutKeyCode
                && shortcutModifiers == AppConfiguration.defaultShortcutModifiers
            if !isDefault {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        shortcutKeyCode = AppConfiguration.defaultShortcutKeyCode
                        shortcutModifiers = AppConfiguration.defaultShortcutModifiers
                        shortcutConflict = nil
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 9))
                        Text("Reset to default (⌘ ⇧ K)")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(Color.vault.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Shortcut Recording

    private func loadShortcut() {
        if let config = AppConfiguration.load() {
            shortcutKeyCode = config.resolvedKeyCode
            shortcutModifiers = config.resolvedModifiers
        }
    }

    private func startRecording() {
        isRecordingShortcut = true
        shortcutConflict = nil

        // Listen for key events
        shortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            let carbonMods = ShortcutHelper.carbonModifiers(from: event.modifierFlags)

            // Require at least one modifier key
            guard carbonMods != 0 else { return event }

            // Ignore modifier-only keypresses (keyCode for modifier keys)
            let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
            guard !modifierKeyCodes.contains(event.keyCode) else { return event }

            let newKeyCode = UInt32(event.keyCode)
            let newModifiers = carbonMods

            withAnimation(.spring(response: 0.3)) {
                shortcutKeyCode = newKeyCode
                shortcutModifiers = newModifiers
            }

            // Check for conflicts
            let conflict = GlobalShortcutManager.shared.checkConflict(
                keyCode: newKeyCode,
                modifiers: newModifiers
            )
            withAnimation {
                shortcutConflict = conflict
            }

            stopRecording()
            return nil // consume the event
        }
    }

    private func stopRecording() {
        isRecordingShortcut = false
        if let monitor = shortcutMonitor {
            NSEvent.removeMonitor(monitor)
            shortcutMonitor = nil
        }
    }

    // MARK: - Data Loading

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

    // MARK: - Save

    private func save() {
        guard let project = selectedProject,
              let env = selectedEnvironment else { return }

        // Preserve existing config fields, add shortcut
        let existingConfig = AppConfiguration.load()
        let config = AppConfiguration(
            projectId: project.id,
            environment: env.slug,
            secretPath: secretPath,
            baseURL: existingConfig?.baseURL ?? AppConfiguration.defaultBaseURL,
            projectName: project.name,
            shortcutKeyCode: shortcutKeyCode,
            shortcutModifiers: shortcutModifiers
        )
        config.save()

        // Update the live global shortcut
        GlobalShortcutManager.shared.updateShortcut(
            keyCode: shortcutKeyCode,
            modifiers: shortcutModifiers
        )

        viewModel.configurationSaved()
        withAnimation { statusMessage = "Saved!" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            onDismiss()
        }
    }
}
