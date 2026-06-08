# HC -- Midnight Forge Dragon Terminal

> A cyberpunk-themed iPadOS work hour tracker built with SwiftUI and MVVM.
> Featuring the **Forge** design system, detailed ASCII dragon art,
> ANSI-styled terminal output, glassmorphism UI, glitch transitions,
> and full Apple Pencil support.

![Platform](https://img.shields.io/badge/Platform-iPadOS-blue?style=flat-square)
![Swift](https://img.shields.io/badge/Swift-6.0-orange?style=flat-square)
![Architecture](https://img.shields.io/badge/Architecture-MVVM-purple?style=flat-square)
![License](https://img.shields.io/badge/License-Private-red?style=flat-square)

---

## Overview

**HC** is a premium work session tracker for iPad. It features the
**Midnight Forge** color system -- a curated palette of 13 colors built
on an obsidian void with arcane violet, cipher teal, ember amber,
and jade green accents.

The interface is split into two panels:
- **Left**: A GlitchFlipContainer that transitions between a glass calendar
  and a timesheet with chromatic aberration + shatter effects.
- **Right**: A live ANSI-styled terminal with ASCII dragon header,
  system boot sequence, and real-time session data.

---

## Forge Color Palette

| Token | Hex | Role |
|-------|-----|------|
| Obsidian | `#07070E` | Card backgrounds |
| Abyss | `#05050B` | Canvas void |
| Phantom | `#130E2E` | Deep indigo layer |
| Arcane | `#8B3CFC` | Primary brand accent |
| Cipher | `#06B6D4` | Interactive elements, totals |
| Supernova | `#A855F7` | Light purple highlights |
| Ember | `#F59E0B` | Weekend markers, warnings |
| Crimson | `#EF4444` | Destructive, weekend borders |
| Jade | `#10B981` | Terminal output, success |
| Mint | `#34D399` | Lighter green accent |
| Frost | `#E2E8F0` | Primary text |
| Steel | `#64748B` | Secondary text, labels |
| Ash | `#414C5E` | Tertiary, tick marks |

---

## Features

- **Glass Calendar** -- Multi-date selection with crimson/ember weekends and arcane/cipher weekday highlights
- **Custom Time Sliders** -- Frictionless neon sliders with haptic 15-min snap, triple-gradient track, glowing thumb
- **Glitch Flip** -- 3D chromatic aberration + 8-slice shatter effect (0.55s, 3 phases)
- **Dragon Terminal** -- Live ANSI output with ASCII dragon, line numbers, 5-module boot sequence, status bar
- **Clipboard Export** -- One-tap formatted report with success haptic
- **Apple Pencil** -- `.hoverEffect(.lift)` on buttons, `.hoverEffect(.highlight)` on calendar cells, pencil drag on sliders
- **CRT Scanlines** -- Animated phosphor sweep beam with perspective grid floor
- **Breathing Aurora** -- 3 color orbs with 6-second animation cycle

---

## Architecture

```
HC/
|-- APP/
|   +-- HCApp.swift                   # Entry point, dark mode enforced
|-- Models/
|   +-- WorkSession.swift             # Value type (UUID, date, times, duration)
|-- ViewModels/
|   +-- TrackerViewModel.swift        # @Observable brain, all state + logic
|-- Views/
|   |-- Calendar/
|   |   +-- GlassCalendarView.swift   # Front card, month grid
|   |-- Components/
|   |   |-- GlassmorphismBG.swift     # Forge palette + 5-layer background
|   |   |-- GlitchFlipContainer.swift # 3-phase transition engine
|   |   +-- NeonTimeSlider.swift      # Custom haptic slider
|   |-- Main/
|   |   +-- TrackerHomeView.swift     # Root layout + dragon terminal
|   +-- Timesheet/
|       +-- TimeInputTableView.swift  # Back card, session rows
+-- Utils/
    +-- ClipboardManager.swift        # UIPasteboard + haptic feedback
```

---

## Terminal Preview

```
                 \                    /
      _    /\     \\               / /    /\
     / \  / /\     \\             / /    / /\
    /   \/ /  \     \\           / /    /  \ \
   / /\  /    _\    \\         / /    _/   /\ \
  / /  \/ /\ / /     \\       / /    / /\ /  \ \
 / /   /  / / /       \\     / /    / / / \   \ \
/ /   / _/ / /         \\___/ /    / / /   \   \ \

  [SYS] Midnight Forge v2.0 -- 2026-06-08 13:45:00
  [SYS] Calendar engine ............. [OK]
  [SYS] Haptic subsystem ............ [OK]
  [SYS] Clipboard bridge ............ [OK]
  [SYS] Pencil input ................ [OK]
  [SYS] Glitch renderer ............. [OK]

  +================================================+
  |            WORK SESSION REPORT                  |
  +================================================+

  [WD] [01] 8 Jun: 7:00 --> 16:00
        Hour: 9:00
  [WE] [02] 9 Jun: 4:30 --> 14:30
        Hour: 10:00

  +------------------------------------------------+
  | >>> Total Hours: 19:00
  +------------------------------------------------+

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

- Hover effects (`.lift` / `.highlight`) on all buttons and calendar cells
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
