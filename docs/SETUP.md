# Setup & Development

## Requirements

- **Xcode** 16.0 or later
- **iOS / iPadOS** 17.0+ deployment target
- **Swift** 6.0
- **macOS** Sonoma 14.0+ (for Xcode 16)
- **Device**: iPad recommended (optimized for landscape)
- **Microphone**: Required for voice command engine
- **Camera**: Front-facing camera required for hand gesture control

---

## Permissions

HC requires the following entitlements and `Info.plist` entries:

| Key | Value | Required For |
|-----|-------|--------------|
| `NSSpeechRecognitionUsageDescription` | "HC uses speech recognition to process voice commands for hands-free control." | Voice command engine |
| `NSMicrophoneUsageDescription` | "HC uses the microphone to listen for voice commands." | Voice command engine |
| `NSCameraUsageDescription` | "HC uses the front camera to track hand gestures for touchless control." | Hand gesture engine |

> **Note on voice:** Speech recognition uses Apple's `SFSpeechRecognizer`
> with the en-US locale. Audio is processed via the on-device or server-side
> recognizer depending on availability. No audio is stored or transmitted
> beyond Apple's speech recognition service. The microphone is used exclusively
> for voice command input.

> **Note on camera:** The camera is used exclusively for on-device hand gesture
> processing via Apple's Vision framework. No images or video are stored,
> transmitted, or recorded. All processing happens locally in real-time.

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

> **Note:** Voice commands require a physical device with a microphone.
> Speech recognition is limited in Simulator. Hand gesture control also
> requires a physical iPad with a front-facing camera.

---

## Project Structure

```
HC/
|-- HC.xcodeproj           # Xcode project configuration
|-- HC/                    # Source code
|   |-- APP/               # App entry point
|   |   +-- HCApp.swift
|   |-- Models/            # Data models
|   |   +-- WorkSession.swift
|   |-- ViewModels/        # @Observable ViewModels
|   |   +-- TrackerViewModel.swift
|   |-- Views/             # SwiftUI views
|   |   |-- Calendar/
|   |   |   +-- GlassCalendarView.swift
|   |   |-- Components/
|   |   |   |-- GlassmorphismBG.swift
|   |   |   |-- GlitchFlipContainer.swift
|   |   |   +-- NeonTimeSlider.swift
|   |   |-- Main/
|   |   |   +-- TrackerHomeView.swift
|   |   +-- Timesheet/
|   |       |-- TimeInputTableView.swift
|   |       +-- TimesheetPreferenceKeys.swift
|   +-- Utils/             # Utilities
|       |-- ClipboardManager.swift
|       |-- HandGestureManager.swift
|       +-- VoiceCommandManager.swift
|-- Demo/                  # Demo assets
|-- docs/                  # Documentation
|   |-- ARCHITECTURE.md
|   |-- COMPONENTS.md
|   |-- DESIGN_SYSTEM.md
|   +-- SETUP.md
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
5. Grant microphone permission when prompted (required for voice commands)
6. Grant camera permission when prompted (required for gesture control)

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

### Voice Commands
1. The voice engine starts automatically on app launch
2. Say **"Hey Vision"** or **"Hi Vision"** to activate the assistant
3. Wait for the greeting: "Hey Nik, how can I help you today?"
4. Speak your command naturally:

| What you say | What happens |
|-------------|-------------|
| "Select today" | Toggles today's date on the calendar |
| "Select the 5th through the 10th" | Selects a range of dates |
| "Select weekdays" | Selects all Mon-Fri in the current month |
| "Deselect today" / "Unselect today" | Removes a date selection |
| "Deselect all" / "Clear all" | Removes all active sessions |
| "Set 9 to 5" | Sets selected sessions to 9:00 AM - 5:00 PM |
| "Log 8 hours starting at 9 AM" | Duration-based time entry |
| "Go to July" / "Show September" | Navigates to a different month |
| "Show timesheet" / "Switch to calendar" | Flips between views |
| "Copy" / "Export" | Copies report to clipboard |
| "Open your eyes" | Activates the gesture camera |
| "Close your eyes" | Deactivates the gesture camera |

5. The assistant confirms each action with text-to-speech
6. After 8 seconds of inactivity, the assistant returns to standby

> **Tip:** You can speak a command in the same breath as the wake word:
> "Hey Vision, select tomorrow" works without waiting for the greeting.

> **Tip:** The assistant remembers your last selected dates. Say "remove them"
> or "set those to 9 to 5" to reference previous selections.

### Hand Gesture Control
1. Say "Hey Vision, open your eyes" or tap the camera button
2. Raise your hand in front of the iPad -- a cyberpunk cursor appears
3. Move your **index finger** to navigate the cursor across the screen
4. **Pinch** (thumb + index finger) to tap/click UI elements
5. **Rotate your wrist** to flip between Calendar and Timesheet
6. **Swipe** left/right to navigate calendar months
7. The cursor disappears automatically when your hand leaves the frame

> **Tip:** The One-Euro adaptive filter ensures smooth cursor tracking --
> slow movements are heavily stabilized while fast gestures remain responsive.

### Terminal Panel
- The right panel shows a live ANSI-styled terminal
- It updates automatically as you add/modify sessions
- Shows voice assistant status, transcript, and conversation logs
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
- **v3.0** -- Hand gesture control, ultra-detailed 30-row dragon blueprint, gesture cursor overlay, PreferenceKey hit-testing system, One-Euro adaptive filter
- **v4.0** -- Voice command engine (SFSpeechRecognizer + NLP + TTS), wake word detection, natural language date/time parsing, deselect/unselect commands, bulk operations, zero-gap session restart, echo suppression, cached TTS voice
