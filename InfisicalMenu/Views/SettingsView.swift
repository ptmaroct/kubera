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

    // Shortcut state
    @State private var shortcutKeyCode: UInt32 = AppConfiguration.defaultShortcutKeyCode
    @State private var shortcutModifiers: UInt32 = AppConfiguration.defaultShortcutModifiers
    @State private var isRecordingShortcut = false
    @State private var shortcutConflict: String?
    @State private var shortcutMonitor: Any?

    var body: some View {
        ZStack {
            // Glass background
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Settings")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white.opacity(0.92))
                    Spacer()
                    Button {
                        stopRecording()
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)

                if isLoading {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.top, 8)
                    Spacer()
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 16) {
                            // Project & Environment card
                            glassCard {
                                VStack(spacing: 14) {
                                    settingsRow(
                                        icon: "folder.fill",
                                        label: "Project"
                                    ) {
                                        Menu {
                                            ForEach(projects) { project in
                                                Button {
                                                    selectedProject = project
                                                    selectedEnvironment = project.environments.first
                                                } label: {
                                                    HStack {
                                                        Text(project.name)
                                                        if selectedProject?.id == project.id {
                                                            Image(systemName: "checkmark")
                                                        }
                                                    }
                                                }
                                            }
                                        } label: {
                                            HStack(spacing: 4) {
                                                Text(selectedProject?.name ?? "Select...")
                                                    .font(.system(size: 13))
                                                    .foregroundColor(.white.opacity(0.85))
                                                Image(systemName: "chevron.up.chevron.down")
                                                    .font(.system(size: 8))
                                                    .foregroundColor(.white.opacity(0.4))
                                            }
                                        }
                                        .menuStyle(.borderlessButton)
                                        .menuIndicator(.hidden)
                                        .fixedSize()
                                    }

                                    Divider().opacity(0.2)

                                    settingsRow(
                                        icon: "leaf.fill",
                                        label: "Environment"
                                    ) {
                                        if let envs = selectedProject?.environments, !envs.isEmpty {
                                            Menu {
                                                ForEach(envs) { env in
                                                    Button {
                                                        selectedEnvironment = env
                                                    } label: {
                                                        HStack {
                                                            Text(env.name)
                                                            if selectedEnvironment?.id == env.id {
                                                                Image(systemName: "checkmark")
                                                            }
                                                        }
                                                    }
                                                }
                                            } label: {
                                                HStack(spacing: 4) {
                                                    Text(selectedEnvironment?.name ?? "Select...")
                                                        .font(.system(size: 13))
                                                        .foregroundColor(.white.opacity(0.85))
                                                    Image(systemName: "chevron.up.chevron.down")
                                                        .font(.system(size: 8))
                                                        .foregroundColor(.white.opacity(0.4))
                                                }
                                            }
                                            .menuStyle(.borderlessButton)
                                            .menuIndicator(.hidden)
                                            .fixedSize()
                                        }
                                    }
                                }
                            }

                            // Keyboard Shortcut card
                            glassCard {
                                VStack(spacing: 12) {
                                    settingsRow(
                                        icon: "keyboard",
                                        label: "Shortcut"
                                    ) {
                                        HStack(spacing: 8) {
                                            if isRecordingShortcut {
                                                Text("Press keys...")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(Color.vault.accent)
                                            } else {
                                                Text(ShortcutHelper.displayString(keyCode: shortcutKeyCode, modifiers: shortcutModifiers))
                                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                                    .foregroundColor(.white.opacity(0.85))
                                            }

                                            Button {
                                                if isRecordingShortcut {
                                                    stopRecording()
                                                } else {
                                                    startRecording()
                                                }
                                            } label: {
                                                Text(isRecordingShortcut ? "Stop" : "Set")
                                                    .font(.system(size: 10, weight: .semibold))
                                                    .foregroundColor(isRecordingShortcut ? Color.vault.bg : .white.opacity(0.7))
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 4)
                                                    .background(isRecordingShortcut ? Color.vault.accent : .white.opacity(0.1))
                                                    .cornerRadius(5)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }

                                    if let conflict = shortcutConflict {
                                        HStack(spacing: 4) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .font(.system(size: 9))
                                            Text(conflict)
                                                .font(.system(size: 10))
                                        }
                                        .foregroundColor(Color.vault.warning)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.leading, 28)
                                    }

                                    let isDefault = shortcutKeyCode == AppConfiguration.defaultShortcutKeyCode
                                        && shortcutModifiers == AppConfiguration.defaultShortcutModifiers
                                    if !isDefault {
                                        Button {
                                            shortcutKeyCode = AppConfiguration.defaultShortcutKeyCode
                                            shortcutModifiers = AppConfiguration.defaultShortcutModifiers
                                            shortcutConflict = nil
                                        } label: {
                                            Text("Reset to ⌘ ⇧ K")
                                                .font(.system(size: 10))
                                                .foregroundColor(.white.opacity(0.35))
                                        }
                                        .buttonStyle(.plain)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                    }
                                }
                            }

                            // About card
                            glassCard {
                                VStack(spacing: 12) {
                                    settingsRow(
                                        icon: "info.circle.fill",
                                        label: "Version"
                                    ) {
                                        Text("1.0.0")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.4))
                                    }

                                    Divider().opacity(0.2)

                                    settingsRow(
                                        icon: "link",
                                        label: "Source"
                                    ) {
                                        Button {
                                            if let url = URL(string: "https://github.com/ptmaroct/infiscal-macos") {
                                                NSWorkspace.shared.open(url)
                                            }
                                        } label: {
                                            HStack(spacing: 4) {
                                                Text("GitHub")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(Color.vault.accent)
                                                Image(systemName: "arrow.up.right")
                                                    .font(.system(size: 8, weight: .semibold))
                                                    .foregroundColor(Color.vault.accent.opacity(0.6))
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    Spacer(minLength: 8)
                }

                if let msg = statusMessage {
                    Text(msg)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(msg.contains("Saved") ? Color.vault.success : Color.vault.error)
                        .padding(.bottom, 4)
                }

                // Save button
                Button {
                    stopRecording()
                    save()
                } label: {
                    Text("Save")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.vault.accent)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(selectedProject == nil || selectedEnvironment == nil)
                .opacity(selectedProject == nil || selectedEnvironment == nil ? 0.4 : 1)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
        .frame(width: 400, height: 440)
        .preferredColorScheme(.dark)
        .onAppear {
            loadData()
            loadShortcut()
        }
        .onDisappear {
            stopRecording()
        }
    }

    // MARK: - Glass Card

    @ViewBuilder
    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(.ultraThinMaterial.opacity(0.6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.06), lineWidth: 1)
            )
    }

    // MARK: - Settings Row

    @ViewBuilder
    private func settingsRow<Content: View>(icon: String, label: String, @ViewBuilder trailing: () -> Content) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Color.vault.accent)
                .frame(width: 18)

            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))

            Spacer()

            trailing()
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

        shortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            let carbonMods = ShortcutHelper.carbonModifiers(from: event.modifierFlags)
            guard carbonMods != 0 else { return event }

            let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
            guard !modifierKeyCodes.contains(event.keyCode) else { return event }

            shortcutKeyCode = UInt32(event.keyCode)
            shortcutModifiers = carbonMods

            let conflict = GlobalShortcutManager.shared.checkConflict(
                keyCode: UInt32(event.keyCode),
                modifiers: carbonMods
            )
            shortcutConflict = conflict
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecordingShortcut = false
        if let monitor = shortcutMonitor {
            NSEvent.removeMonitor(monitor)
            shortcutMonitor = nil
        }
    }

    // MARK: - Data

    private func loadData() {
        // Show cached data SYNCHRONOUSLY — no async needed
        let cached = ProjectCache.shared.projects
        if !cached.isEmpty {
            projects = cached
            applyConfig()
            isLoading = false
        }

        // Then refresh in background
        Task {
            let fresh = await ProjectCache.shared.fetchProjects()
            if projects.isEmpty || fresh != projects {
                projects = fresh
                applyConfig()
            }
            isLoading = false
        }
    }

    private func applyConfig() {
        if let config = AppConfiguration.load() {
            selectedProject = projects.first(where: { $0.id == config.projectId })
            if let project = selectedProject {
                selectedEnvironment = project.environments.first(where: { $0.slug == config.environment })
            }
            secretPath = config.secretPath
        }
    }

    // MARK: - Save

    private func save() {
        guard let project = selectedProject,
              let env = selectedEnvironment else { return }

        let existingConfig = AppConfiguration.load()
        let config = AppConfiguration(
            projectId: project.id,
            environment: env.slug,
            secretPath: secretPath,
            baseURL: existingConfig?.baseURL ?? AppConfiguration.defaultBaseURL,
            projectName: project.name,
            organizationId: existingConfig?.organizationId,
            shortcutKeyCode: shortcutKeyCode,
            shortcutModifiers: shortcutModifiers
        )
        config.save()

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

// MARK: - NSVisualEffectView wrapper for glass blur

struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
