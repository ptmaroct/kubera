import SwiftUI

struct AddSecretView: View {
    @ObservedObject var viewModel: AppViewModel
    @StateObject private var addVM = AddSecretViewModel()
    let onDismiss: () -> Void

    @State private var successMessage: String?

    var body: some View {
        ZStack {
            WindowBackground()
            formContent

            // Success toast
            if let msg = successMessage {
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color.vault.success)
                        Text(msg)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.vault.text)
                        Spacer()
                        Button {
                            withAnimation { successMessage = nil }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Color.vault.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.vault.success.opacity(0.12))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.vault.success.opacity(0.25), lineWidth: 1)
                    )
                    .padding(.horizontal, 28)
                    .padding(.top, 60)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .frame(width: 480, height: 540)
        .preferredColorScheme(.dark)
        .onAppear {
            Task { await addVM.loadInitialData() }
        }
    }

    // MARK: - Form

    private var formContent: some View {
        VStack(spacing: 0) {
            headerSection
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 16)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    environmentSection

                    Rectangle()
                        .fill(Color.vault.border)
                        .frame(height: 1)
                        .padding(.vertical, 2)

                    VaultTextField(label: "Secret Name", text: $addVM.key, isMonospaced: true, placeholder: "e.g. API_KEY")
                    VaultTextField(label: "Secret Value", text: $addVM.value, isSecure: true, placeholder: "Enter value")

                    VaultTextEditor(
                        label: "Comment",
                        text: $addVM.comment,
                        placeholder: "Optional description...",
                        lineCount: 2
                    )

                    tagSection
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 14)
            }

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

            footer
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
        }
    }

    // MARK: - Header (title + inline project dropdown)

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("New Secret")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.vault.text)

                if addVM.isLoadingProjects {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 10, height: 10)
                        Text("Loading...")
                            .font(.system(size: 11))
                            .foregroundColor(Color.vault.textTertiary)
                    }
                } else {
                    // Inline popup menu for project switching
                    Menu {
                        ForEach(addVM.projects) { project in
                            Button {
                                addVM.selectedProject = project
                                addVM.onProjectSelected()
                            } label: {
                                HStack {
                                    Text(project.name)
                                    if addVM.selectedProject?.id == project.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(addVM.selectedProject?.name ?? "Select project")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color.vault.accent)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(Color.vault.accent.opacity(0.5))
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
            }

            Spacer()

            Image(systemName: "plus.square.fill")
                .font(.system(size: 14))
                .foregroundColor(Color.vault.accent.opacity(0.5))
        }
    }

    // MARK: - Environment (multi-select)

    @ViewBuilder
    private var environmentSection: some View {
        if !addVM.environments.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("ENVIRONMENT")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color.vault.textSecondary)
                        .tracking(1.2)

                    if addVM.selectedEnvironmentIds.count > 1 {
                        Text("\(addVM.selectedEnvironmentIds.count) selected")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Color.vault.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.vault.accentSoft)
                            .cornerRadius(4)
                    }
                }

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
        let isSelected = addVM.selectedEnvironmentIds.contains(env.id)
        return Button {
            withAnimation(.spring(response: 0.3)) {
                addVM.toggleEnvironment(env)
            }
        } label: {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                }
                Text(env.name)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? Color.vault.bg : Color.vault.textSecondary)
            .padding(.horizontal, isSelected ? 12 : 14)
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

    // MARK: - Tags

    private var tagSection: some View {
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
            } else {
                if !addVM.tags.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 6)], spacing: 6) {
                        ForEach(addVM.tags) { tag in
                            tagChip(tag)
                        }
                    }
                }

                // Create tag — comma, semicolon, or enter
                HStack(spacing: 8) {
                    HStack(spacing: 0) {
                        Image(systemName: "tag")
                            .font(.system(size: 10))
                            .foregroundColor(Color.vault.textTertiary)
                            .padding(.leading, 10)

                        TextField("Type tag, press comma or enter...", text: $addVM.newTagName)
                            .font(.system(size: 12))
                            .foregroundColor(Color.vault.text)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 7)
                            .onSubmit {
                                Task { await addVM.createTag() }
                            }
                            .onChange(of: addVM.newTagName) { newValue in
                                if newValue.hasSuffix(",") || newValue.hasSuffix(";") {
                                    addVM.newTagName = String(newValue.dropLast()).trimmingCharacters(in: .whitespaces)
                                    if !addVM.newTagName.isEmpty {
                                        Task { await addVM.createTag() }
                                    }
                                }
                            }
                    }
                    .background(Color.vault.bg)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.vault.border, lineWidth: 1)
                    )

                    if !addVM.newTagName.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button {
                            Task { await addVM.createTag() }
                        } label: {
                            Group {
                                if addVM.isCreatingTag {
                                    ProgressView()
                                        .scaleEffect(0.5)
                                        .frame(width: 14, height: 14)
                                } else {
                                    Image(systemName: "plus")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                            }
                            .foregroundColor(Color.vault.bg)
                            .frame(width: 28, height: 28)
                            .background(Color.vault.accent)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .disabled(addVM.isCreatingTag)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                }
                .animation(.spring(response: 0.3), value: addVM.newTagName.isEmpty)
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
                Text(tag.displayName)
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
                    let createdName = addVM.key
                    let success = await addVM.createSecret()
                    if success {
                        await viewModel.loadSecrets()
                        addVM.key = ""
                        addVM.value = ""
                        addVM.comment = ""
                        addVM.selectedTagIds = []

                        withAnimation(.spring(response: 0.4)) {
                            successMessage = "\(createdName) created successfully"
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            withAnimation { successMessage = nil }
                        }
                    }
                }
            }
        }
    }
}
