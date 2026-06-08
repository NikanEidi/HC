# Setup & Development

## Requirements

- **Xcode** 16.0 or later
- **iOS / iPadOS** 17.0+ deployment target
- **Swift** 6.0
- **macOS** Sonoma 14.0+ (for Xcode 16)
- **Device**: iPad recommended (optimized for landscape)

---

## Quick Start

```bash
# Clone the repository
git clone https://github.com/NikanEidi/HC.git
cd HC

# Open in Xcode
open HC.xcodeproj
```

1. Select the **HC** scheme in Xcode toolbar
2. Choose an iPad simulator (iPad Pro 13-inch recommended)
3. Press **Cmd+R** to build and run
4. The app launches directly into `TrackerHomeView`

---

## Project Structure

```
HC/
|-- HC.xcodeproj           # Xcode project configuration
|-- HC/                    # Source code
|   |-- APP/               # App entry point
|   |-- Models/            # Data models
|   |-- ViewModels/        # @Observable ViewModels
|   |-- Views/             # SwiftUI views
|   |   |-- Calendar/      # Calendar card
|   |   |-- Components/    # Shared components
|   |   |-- Main/          # Root view
|   |   +-- Timesheet/     # Timesheet card
|   +-- Utils/             # Utilities
|-- docs/                  # Documentation
|-- README.md              # Project overview
+-- .gitignore             # Git ignore rules
```

---

## Building from Command Line

```bash
# Build for iPad simulator
xcodebuild -project HC.xcodeproj \
  -scheme HC \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  build

# Clean build
xcodebuild -project HC.xcodeproj -scheme HC clean build
```

---

## Testing on Device

1. Connect your iPad via USB or Wi-Fi
2. In Xcode, select your device from the destination picker
3. You may need to trust the developer certificate on your iPad:
   **Settings > General > Device Management > Developer App**
4. Press **Cmd+R** to build and deploy

---

## How to Use the App

### Select Work Days
1. Launch the app -- you see the **Calendar** on the left
2. Tap dates to select work days (they highlight with neon borders)
3. Weekend dates show in red/amber, weekdays in purple/cyan

### Adjust Times
1. Tap **TIMESHEET** button to flip to the time editor
2. Drag the **FROM** slider to set start time
3. Drag the **TO** slider to set end time
4. Sliders snap to 15-minute intervals with haptic feedback
5. Duration updates in real-time

### Export Report
1. While on the Timesheet view, tap **EXPORT**
2. The formatted report is copied to your clipboard
3. A toast confirms: "[OK] EXPORTED TO CLIPBOARD"
4. Paste anywhere (Notes, Messages, Email, etc.)

### Terminal Panel
- The right panel shows a live ANSI-styled terminal
- It updates automatically as you add/modify sessions
- Shows total hours, per-session breakdown, and system status

---

## Commit Convention

This project uses conventional commits:

| Prefix | Usage |
|--------|-------|
| `feat:` | New features |
| `fix:` | Bug fixes |
| `docs:` | Documentation only |
| `refactor:` | Code restructuring |
| `chore:` | Build/tooling changes |

---

## Versioning

Tags follow semantic versioning:
- **v2.0** -- Midnight Forge palette overhaul
- **v2.1** -- Dragon art fix + time alignment
- **v2.2** -- Documentation + final dragon art
