# HC -- Neo-Tokyo Dragon Terminal

> A cyberpunk-themed iPadOS work hour tracker built with SwiftUI and MVVM architecture.  
> Featuring a detailed ASCII dragon, ANSI-styled terminal output, glassmorphism UI,  
> and full Apple Pencil support.

![Platform](https://img.shields.io/badge/Platform-iPadOS-blue?style=flat-square)
![Swift](https://img.shields.io/badge/Swift-6.0-orange?style=flat-square)
![Architecture](https://img.shields.io/badge/Architecture-MVVM-purple?style=flat-square)
![License](https://img.shields.io/badge/License-Private-red?style=flat-square)

---

## Overview

**HC** is a premium work session tracker designed for iPad. It features a Neo-Tokyo
cyberpunk visual identity built on a Vantablack canvas with neon glassmorphism effects,
custom glitch transitions, Apple Pencil hover support, and a live ANSI-styled terminal
with a detailed ASCII dragon header.

### Features

- **Glass Calendar** -- Multi-date selection with laser red/gold weekends and neon purple/cyan weekday highlights
- **Custom Time Sliders** -- Frictionless neon sliders with haptic feedback on 15-minute snap increments
- **Glitch Flip Transition** -- 3D chromatic aberration + shatter effect between Calendar and Timesheet views
- **Dragon Terminal** -- Live ANSI-styled terminal with ASCII art dragon, line numbers, system boot sequence, and status bar
- **Clipboard Export** -- One-tap formatted work report with haptic confirmation
- **Apple Pencil** -- Full hover effect support across all interactive elements
- **CRT Scanlines** -- Animated scan beam overlay with perspective grid floor

---

## Architecture

```
HC/
|-- APP/
|   +-- HCApp.swift                   # Entry point
|-- Models/
|   +-- WorkSession.swift             # Data model (UUID, date, times, Equatable)
|-- ViewModels/
|   +-- TrackerViewModel.swift        # @Observable brain
|-- Views/
|   |-- Calendar/
|   |   +-- GlassCalendarView.swift   # Front card
|   |-- Components/
|   |   |-- GlassmorphismBG.swift     # Background + ASCII dragon watermark
|   |   |-- GlitchFlipContainer.swift # Transition engine
|   |   +-- NeonTimeSlider.swift      # Custom slider
|   |-- Main/
|   |   +-- TrackerHomeView.swift     # Root composition + dragon terminal
|   +-- Timesheet/
|       +-- TimeInputTableView.swift  # Back card
+-- Utils/
    +-- ClipboardManager.swift        # UIPasteboard + haptics
```

---

## Color Palette

| Token | Hex | Role |
|-------|-----|------|
| Vantablack | #050505 | Base canvas |
| Neon Purple | #BF40FF | Selected weekdays, accents |
| Neon Cyan | #00F5FF | Primary interactive, totals |
| Laser Red | #FF1744 | Weekends, alerts |
| Laser Gold | #FFD700 | Weekend accents |
| Terminal Green | #2EFF87 | Terminal log, export actions |

---

## Terminal Preview

```
                ___====-_  _-====___
          _--^^^#####//      \\#####^^^--_
       _-^##########// (    ) \\##########^-_
      -############//  |\^^/|  \\############-
    _/############//   (@::@)   \\############\_
   /#############((     \\//     ))#############\
  -###############\\    (oo)    //###############-
 -#################\\  / " \  //#################-

  [SYS] Dragon Terminal initialized 2026-06-08 13:30:00
  [SYS] Calendar engine .............. [OK]
  [SYS] Haptic subsystem ............. [OK]
  [SYS] Clipboard bridge ............. [OK]
  [SYS] Pencil input handler ......... [OK]

  +============================================+
  |          WORK SESSION REPORT                |
  +============================================+

  [WD] [01] 8 Jun: 7:00 --> 16:00
        Hour: 9:00
  [WE] [02] 9 Jun: 4:30 --> 14:30
        Hour: 10:00

  +--------------------------------------------+
  | >>> Total Hours: 19:00
  +--------------------------------------------+

root@hc:~$ _
```

---

## Clipboard Output Format

```
8 Jun: 7:00 to 16:00
Hour: 9:00
9 Jun: 4:30 to 14:30
Hour: 10:00
Total Hours: 19:00
```

---

## Apple Pencil Support

- Hover effects (.lift and .highlight) on all buttons and calendar cells
- Pencil drag fully supported on NeonTimeSliders with haptic snapping
- Hover state changes on calendar day cells for precision selection

---

## Requirements

- Xcode 16+
- iOS / iPadOS 17.0+
- Swift 6.0

---

## Author

**Nikan Eidi**
