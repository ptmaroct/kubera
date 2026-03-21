# InfisicalMenu

A native macOS menubar app for quickly searching and managing secrets via the [Infisical](https://infisical.com) CLI.

![macOS](https://img.shields.io/badge/macOS-13%2B-black?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)

## Features

- **Menubar native** — lives in your system menubar as an NSMenu dropdown, no dock icon
- **Instant search** — filter secrets by name as you type
- **One-click copy** — click any secret to copy its value, auto-clears clipboard after 30s
- **Add secrets** — create new secrets without leaving your menubar
- **Global shortcut** — `Cmd + Shift + K` toggles the menu from anywhere
- **CLI-powered** — uses your existing `infisical` CLI session, zero credential management
- **Dark vault UI** — custom dark theme with amber accents and smooth animations

## Prerequisites

- macOS 13 (Ventura) or later
- [Infisical CLI](https://infisical.com/docs/cli/overview) installed and logged in

```bash
brew install infisical
infisical login
```

## Build & Run

```bash
# Build
swift build

# Create .app bundle and launch
bash scripts/bundle.sh
open build/InfisicalMenu.app
```

## First Launch

1. App detects your Infisical CLI session automatically
2. Select your project and environment from dropdowns
3. Click **Connect** — secrets appear in the menubar menu

## Usage

| Action | How |
|--------|-----|
| Open menu | Click the key icon in menubar, or `Cmd + Shift + K` |
| Search | Type in the search field at the top of the menu |
| Copy secret | Click any secret name — value is copied to clipboard |
| Add secret | Menu → Add New Secret |
| Open dashboard | Menu → Open Infisical Dashboard |
| Settings | Menu → Settings |

Clipboard auto-clears after 30 seconds for security.

## Project Structure

```
InfisicalMenu/
├── InfisicalMenuApp.swift          # App entry point
├── AppDelegate.swift               # NSStatusBar, NSMenu, window management
├── Models/
│   ├── Secret.swift                # Secret model (parsed from CLI JSON)
│   ├── AppConfiguration.swift      # Persisted project/env config
│   └── APIModels.swift             # Org/project/env models from API
├── Services/
│   ├── InfisicalCLIService.swift   # CLI + API calls (list, create, auth)
│   └── ClipboardService.swift      # Copy with auto-clear
├── ViewModels/
│   ├── AppViewModel.swift          # Central state management
│   └── OnboardingViewModel.swift   # Setup flow state
├── Views/
│   ├── DesignSystem.swift          # Colors, components, animations
│   ├── OnboardingView.swift        # First-launch setup wizard
│   ├── SettingsView.swift          # Project/env configuration
│   └── AddSecretView.swift         # Create new secret form
└── Utilities/
    ├── KeyboardShortcutNames.swift # Global hotkey (Carbon API)
    └── Constants.swift
```

## License

MIT
