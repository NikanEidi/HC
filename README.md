# HC — Neo-Tokyo Data Terminal

> A cyberpunk-themed iPadOS work hour tracker built with SwiftUI and MVVM architecture.

![Platform](https://img.shields.io/badge/Platform-iPadOS-blue?style=flat-square)
![Swift](https://img.shields.io/badge/Swift-6.0-orange?style=flat-square)
![Architecture](https://img.shields.io/badge/Architecture-MVVM-purple?style=flat-square)
![License](https://img.shields.io/badge/License-Private-red?style=flat-square)

---

## Overview

**HC** is a premium work session tracker designed for iPad. It features a Neo-Tokyo / cyberpunk visual identity built on a Vantablack canvas with neon glassmorphism effects, custom glitch transitions, and a live terminal-style output log.

### Key Features

- **Glass Calendar** — Multi-date selection with laser red/gold weekends and neon purple/cyan weekday highlights
- **Custom Time Sliders** — Frictionless neon sliders with haptic feedback on 15-minute snap increments
- **Glitch Flip Transition** — 3D chromatic aberration + shatter effect between Calendar ↔ Timesheet views
- **Terminal Log** — Live-updating monospaced output panel with blinking cursor
- **Clipboard Export** — One-tap copy of formatted work report with haptic confirmation

---

## Architecture

```
HC/
├── APP/
│   └── HCApp.swift                   # Entry point
├── Models/
│   └── WorkSession.swift             # Data model (UUID, date, times)
├── ViewModels/
│   └── TrackerViewModel.swift        # @Observable brain
├── Views/
│   ├── Calendar/
│   │   └── GlassCalendarView.swift   # Front card
│   ├── Components/
│   │   ├── GlassmorphismBG.swift     # Background layer
│   │   ├── GlitchFlipContainer.swift # Transition engine
│   │   └── NeonTimeSlider.swift      # Custom slider
│   ├── Main/
│   │   └── TrackerHomeView.swift     # Root composition
│   └── Timesheet/
│       └── TimeInputTableView.swift  # Back card
└── Utils/
    └── ClipboardManager.swift        # UIPasteboard + haptics
```

---

## Color Palette

| Token | Hex | Role |
|-------|-----|------|
| Vantablack | `#050505` | Base canvas |
| Neon Purple | `#BF40FF` | Selected weekdays |
| Neon Cyan | `#00F5FF` | Primary interactive |
| Laser Red | `#FF1744` | Weekends |
| Laser Gold | `#FFD700` | Weekend accents |
| Terminal Green | `#2EFF87` | Log output |

---

## Clipboard Output Format

```
25 May: 4:30 to 14:30
Hour: 10:00
28 May: 7:00 to 16:00
Hour: 9:00
29 May: 7:00 to 14:00
Hour: 7:00
Total Hours: 26:00
```

---

## Requirements

- Xcode 16+
- iOS / iPadOS 17.0+
- Swift 6.0

---

## Author

**Nikan Eidi**
