import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private let viewModel = AppViewModel()
    private var searchField: NSSearchField!
    private var onboardingWindow: NSWindow?
    private var addSecretWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var secretMenuItems: [NSMenuItem] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupMenu()
        setupKeyboardShortcut()

        if !viewModel.isConfigured {
            showOnboarding()
        }
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "key.fill", accessibilityDescription: "Infisical")
            button.image?.size = NSSize(width: 16, height: 16)
            button.image?.isTemplate = true
        }
    }

    // MARK: - Menu

    private func setupMenu() {
        menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        // Search field
        let searchItem = NSMenuItem()
        searchField = NSSearchField(frame: NSRect(x: 0, y: 0, width: 240, height: 28))
        searchField.placeholderString = "Search secrets..."
        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = false
        searchField.target = self
        searchField.action = #selector(searchFieldChanged(_:))
        searchField.focusRingType = .none

        let searchContainer = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 36))
        searchField.frame = NSRect(x: 10, y: 4, width: 240, height: 28)
        searchContainer.addSubview(searchField)
        searchItem.view = searchContainer
        menu.addItem(searchItem)
        menu.addItem(NSMenuItem.separator())

        // Secret items
        secretMenuItems.removeAll()
        let filtered = viewModel.filteredSecrets

        if viewModel.isLoading && viewModel.secrets.isEmpty {
            let loadingItem = NSMenuItem(title: "Loading...", action: nil, keyEquivalent: "")
            loadingItem.isEnabled = false
            menu.addItem(loadingItem)
        } else if !viewModel.isConfigured {
            let notConfiguredItem = NSMenuItem(title: "Not configured — open Settings", action: #selector(openSettings), keyEquivalent: "")
            notConfiguredItem.target = self
            menu.addItem(notConfiguredItem)
        } else if filtered.isEmpty {
            let emptyTitle = viewModel.searchText.isEmpty ? "No secrets found" : "No results for \"\(viewModel.searchText)\""
            let emptyItem = NSMenuItem(title: emptyTitle, action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for (index, secret) in filtered.enumerated() {
                let item = NSMenuItem(title: secret.key, action: #selector(copySecret(_:)), keyEquivalent: "")
                item.target = self
                item.tag = index
                item.toolTip = "Click to copy value"
                secretMenuItems.append(item)
                menu.addItem(item)
            }
        }

        menu.addItem(NSMenuItem.separator())

        // Add New Secret
        let addItem = NSMenuItem(title: "Add New Secret...", action: #selector(openAddSecret), keyEquivalent: "n")
        addItem.target = self
        menu.addItem(addItem)

        // Open Dashboard
        let dashboardItem = NSMenuItem(title: "Open Infisical Dashboard", action: #selector(openDashboard), keyEquivalent: "")
        dashboardItem.target = self
        menu.addItem(dashboardItem)

        menu.addItem(NSMenuItem.separator())

        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        // Quit
        let quitItem = NSMenuItem(title: "Quit InfisicalMenu", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        viewModel.searchText = ""
        rebuildMenu()

        if viewModel.isConfigured {
            Task {
                await viewModel.loadSecrets()
                await MainActor.run {
                    rebuildMenu()
                    // Restore focus to search field
                    searchField?.becomeFirstResponder()
                }
            }
        }

        // Focus search field
        DispatchQueue.main.async { [weak self] in
            self?.searchField?.becomeFirstResponder()
        }
    }

    // MARK: - Actions

    @objc private func searchFieldChanged(_ sender: NSSearchField) {
        viewModel.searchText = sender.stringValue
        rebuildMenu()
        // Keep search field focused and text intact
        searchField?.stringValue = viewModel.searchText
        DispatchQueue.main.async { [weak self] in
            self?.searchField?.becomeFirstResponder()
        }
    }

    @objc private func copySecret(_ sender: NSMenuItem) {
        let index = sender.tag
        let filtered = viewModel.filteredSecrets
        guard index >= 0, index < filtered.count else { return }
        let secret = filtered[index]
        viewModel.copySecret(secret)

        // Brief visual feedback — flash the menubar icon
        if let button = statusItem.button {
            let original = button.image
            button.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Copied")
            button.image?.isTemplate = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                button.image = original
            }
        }
    }

    @objc private func openAddSecret() {
        if addSecretWindow == nil || !addSecretWindow!.isVisible {
            let view = AddSecretView(viewModel: viewModel) { [weak self] in
                self?.addSecretWindow?.close()
            }
            addSecretWindow = makeStyledWindow(view: view, width: 420, height: 300)
        }
        addSecretWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openDashboard() {
        let config = AppConfiguration.load()
        let baseURL = config?.baseURL ?? "https://app.infisical.com"
        if let url = URL(string: baseURL) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openSettings() {
        if settingsWindow == nil || !settingsWindow!.isVisible {
            let view = SettingsView(viewModel: viewModel) { [weak self] in
                self?.settingsWindow?.close()
            }
            settingsWindow = makeStyledWindow(view: view, width: 440, height: 400)
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Onboarding

    func showOnboarding() {
        if onboardingWindow == nil || !onboardingWindow!.isVisible {
            let view = OnboardingView(viewModel: viewModel) { [weak self] in
                self?.onboardingWindow?.close()
            }
            onboardingWindow = makeStyledWindow(view: view, width: 500, height: 460)
        }
        onboardingWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Window Factory

    private func makeStyledWindow<V: View>(view: V, width: CGFloat, height: CGFloat) -> NSWindow {
        let hostingView = NSHostingView(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1.0)
        window.center()
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        return window
    }

    // MARK: - Keyboard Shortcut

    private func setupKeyboardShortcut() {
        GlobalShortcutManager.shared.register { [weak self] in
            guard let self, let button = self.statusItem.button else { return }
            DispatchQueue.main.async {
                button.performClick(nil)
            }
        }
    }
}
