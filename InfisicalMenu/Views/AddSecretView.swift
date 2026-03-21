import SwiftUI

struct AddSecretView: View {
    @ObservedObject var viewModel: AppViewModel
    @StateObject private var addVM = AddSecretViewModel()
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            WindowBackground()

            if addVM.showSuccess {
                successOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                formContent
                    .transition(.opacity)
            }
        }
        .frame(width: 480, height: 580)
        .preferredColorScheme(.dark)
        .onAppear {
            Task { await addVM.loadInitialData() }
        }
    }

    // MARK: - Form

    private var formContent: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 16)

            // Scrollable form fields
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    // Project & Environment
                    projectSection
                    environmentSection

                    // Divider
                    Rectangle()
                        .fill(Color.vault.border)
                        .frame(height: 1)
                        .padding(.vertical, 4)

                    // Core fields
                    VaultTextField(label: "Secret Name", text: $addVM.key, isMonospaced: true)
                    VaultTextField(label: "Secret Value", text: $addVM.value, isSecure: true)

                    // Advanced section
                    advancedSection
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 14)
            }

            // Error message
            if let error = addVM.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 10))
                    Text(error)
                        .font(.system(size: 11))
                        .lineLimit(2)
                }
                .foregroundColor(Color.vault.error)
                .padding(.horizontal, 28)
                .padding(.bottom, 8)
                .transition(.opacity)
            }

            // Footer buttons
            footer
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("New Secret")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.vault.text)
            Spacer()
            Image(systemName: "plus.square.fill")
                .font(.system(size: 14))
                .foregroundColor(Color.vault.accent.opacity(0.5))
        }
    }

    // MARK: - Project Section

    private var projectSection: some View {
        Group {
            if addVM.isLoadingProjects {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                    Text("Loading projects...")
                        .font(.system(size: 12))
                        .foregroundColor(Color.vault.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            } else {
                VaultPicker(
                    label: "Project",
                    selection: $addVM.selectedProject,
                    options: addVM.projects,
                    displayName: { $0.name }
                )
                .onChange(of: addVM.selectedProject) { _ in
                    addVM.onProjectSelected()
                }
            }
        }
    }

    // MARK: - Environment Section

    @ViewBuilder
    private var environmentSection: some View {
        if !addVM.environments.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("ENVIRONMENT")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color.vault.textSecondary)
                    .tracking(1.2)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(addVM.environments) { env in
                            envPill(env)
                        }
                    }
                }
            }
        }
    }

    private func envPill(_ env: InfisicalEnvironment) -> some View {
        let isSelected = addVM.selectedEnvironment?.id == env.id
        return Button {
            withAnimation(.spring(response: 0.3)) {
                addVM.selectedEnvironment = env
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

    // MARK: - Advanced Section

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Toggle button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    addVM.showAdvanced.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .rotationEffect(.degrees(addVM.showAdvanced ? 90 : 0))

                    Text("Advanced Options")
                        .font(.system(size: 12, weight: .medium))

                    Spacer()

                    // Show count of active advanced options
                    let advancedCount = advancedOptionsCount
                    if advancedCount > 0 && !addVM.showAdvanced {
                        Text("\(advancedCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color.vault.bg)
                            .frame(width: 18, height: 18)
                            .background(Color.vault.accent)
                            .clipShape(Circle())
                    }
                }
                .foregroundColor(Color.vault.textSecondary)
            }
            .buttonStyle(.plain)

            if addVM.showAdvanced {
                VStack(spacing: 14) {
                    // Secret Path
                    VaultTextField(label: "Secret Path", text: $addVM.secretPath, isMonospaced: true)

                    // Comment
                    VaultTextEditor(
                        label: "Comment",
                        text: $addVM.comment,
                        placeholder: "Add a description for this secret..."
                    )

                    // Tags
                    tagSelector
                }
                .padding(14)
                .background(Color.vault.surface.opacity(0.5))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.vault.border, lineWidth: 1)
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var advancedOptionsCount: Int {
        var count = 0
        if addVM.secretPath != "/" { count += 1 }
        if !addVM.comment.isEmpty { count += 1 }
        if !addVM.selectedTagIds.isEmpty { count += 1 }
        return count
    }

    // MARK: - Tag Selector

    private var tagSelector: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TAGS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color.vault.textSecondary)
                .tracking(1.2)

            if addVM.isLoadingTags {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                    Text("Loading tags...")
                        .font(.system(size: 11))
                        .foregroundColor(Color.vault.textTertiary)
                }
            } else if addVM.tags.isEmpty {
                Text("No tags available for this project")
                    .font(.system(size: 11))
                    .foregroundColor(Color.vault.textTertiary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 6)], spacing: 6) {
                    ForEach(addVM.tags) { tag in
                        tagChip(tag)
                    }
                }
            }
        }
    }

    private func tagChip(_ tag: InfisicalTag) -> some View {
        let isSelected = addVM.selectedTagIds.contains(tag.id)
        return Button {
            withAnimation(.spring(response: 0.3)) {
                if isSelected {
                    addVM.selectedTagIds.remove(tag.id)
                } else {
                    addVM.selectedTagIds.insert(tag.id)
                }
            }
        } label: {
            HStack(spacing: 4) {
                if let color = tag.color, !color.isEmpty {
                    Circle()
                        .fill(Color(hex: color))
                        .frame(width: 6, height: 6)
                }
                Text(tag.name)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? Color.vault.bg : Color.vault.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Color.vault.accent : Color.vault.bg)
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isSelected ? Color.vault.accent : Color.vault.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            VaultButton(title: "Cancel", style: .ghost) {
                onDismiss()
            }

            Spacer()

            VaultButton(
                title: addVM.isCreating ? "Creating..." : "Create Secret",
                style: .primary,
                isLoading: addVM.isCreating,
                isDisabled: !addVM.isValid
            ) {
                Task {
                    let success = await addVM.createSecret()
                    if success {
                        // Refresh main secret list
                        await viewModel.loadSecrets()
                        withAnimation(.spring(response: 0.4)) {
                            addVM.showSuccess = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            onDismiss()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Success Overlay

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

            Text(addVM.key)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(Color.vault.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.vault.accentSoft)
                .cornerRadius(4)

            if let project = addVM.selectedProject,
               let env = addVM.selectedEnvironment {
                HStack(spacing: 4) {
                    Text(project.name)
                        .font(.system(size: 11, weight: .medium))
                    Text("/")
                        .foregroundColor(Color.vault.textTertiary)
                    Text(env.name)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(Color.vault.textSecondary)
            }
        }
    }
}
