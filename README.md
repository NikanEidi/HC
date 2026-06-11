# HC -- Midnight Forge Dragon Terminal

> A cyberpunk-themed iPadOS work hour tracker built with SwiftUI and MVVM.
> Featuring the **Forge** design system, ultra-detailed ASCII dragon art,
> ANSI-styled terminal output, glassmorphism UI, glitch transitions,
> voice command control via speech recognition, hand gesture control via
> front camera, and full Apple Pencil support.

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
- **Right**: A live ANSI-styled terminal with ultra-detailed ASCII dragon header,
  system boot sequence, voice assistant status, and real-time session data.

The app features a **voice command engine** -- a continuous speech
assistant powered by Apple's Speech and NaturalLanguage frameworks.
Say "Hey Vision" to activate, then speak natural language commands to
select dates, set times, navigate months, copy reports, and more.
The assistant responds with text-to-speech using a premium male voice.

---

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/ARCHITECTURE.md) | MVVM data flow, voice pipeline, gesture pipeline, file map, design decisions |
| [Design System](docs/DESIGN_SYSTEM.md) | Forge palette, GlassCard, dragon art, gesture cursor, voice UX, typography |
| [Components](docs/COMPONENTS.md) | Every SwiftUI component and utility documented in detail |
| [Setup](docs/SETUP.md) | Requirements, permissions, build instructions, usage guide |

---

## Forge Color Palette

| Token | Hex | Role |
|-------|-----|------|
| Obsidian | `#020204` | Card backgrounds |
| Abyss | `#010102` | Canvas void |
| Phantom | `#040308` | Deep indigo layer |
| Arcane | `#8426FF` | Electric Violet -- primary brand accent |
| Cipher | `#00D8F2` | Hyper-Neon Cyan -- interactive elements, totals |
| Supernova | `#FF26A6` | Vivid Neon Magenta -- highlights |
| Ember | `#FF7300` | Vivid Safety Orange -- weekend markers, warnings |
| Crimson | `#FF263F` | Glowing Crimson Red -- destructive, weekend borders |
| Jade | `#00F273` | Electric Jade -- terminal output, success |
| Mint | `#1AFFA6` | Glowing Neon Mint -- lighter green accent |
| Frost | `#F0F5FC` | Luminous Ice -- primary text |
| Steel | `#7A8AA3` | Chrome Steel -- secondary text, labels |
| Ash | `#333D4D` | Dark Charcoal -- tertiary, tick marks |

---

## Features

- **Voice Command Engine** -- Continuous speech assistant with sliding-window fuzzy wake word detection ("Hey Vision"), local NLP intent parsing via `VoiceCommandParser`, date/time extraction, pronoun resolution, and text-to-speech responses
- **Glass Calendar** -- Multi-date selection with crimson/ember weekends and arcane/cipher weekday highlights
- **Custom Time Sliders** -- Frictionless neon sliders with haptic 15-min snap, triple-gradient track, glowing thumb
- **Glitch Flip** -- 3D chromatic aberration + 8-slice shatter effect (0.55s, 3 phases)
- **Dragon Terminal** -- Live ANSI output with ASCII dragon blueprint, per-character coloring via `DragonArtRenderer` with 15+ character classes, animated flame breath and sparkle particles
- **Hand Gesture Control** -- Front-camera gesture engine powered by AVFoundation + Vision framework with One-Euro adaptive filter for jitter-free tracking, scale-invariant pinch detection with hysteresis
- **Clipboard Export** -- One-tap formatted report with success haptic
- **Apple Pencil** -- `.hoverEffect(.lift)` on buttons, `.hoverEffect(.highlight)` on calendar cells, pencil drag on sliders
- **CRT Scanlines** -- Animated phosphor sweep beam with perspective grid floor
- **Breathing Aurora** -- 3 color orbs with 6-second animation cycle

---

## Voice Command Engine

HC features a continuous voice assistant that listens passively for a
wake word, then activates to parse and execute natural language commands.

### Pipeline

1. **Passive Listening** -- `SFSpeechRecognizer` runs continuously, monitoring for the wake word
2. **Wake Word Detection** -- Sliding-window fuzzy matching (Levenshtein) against "Hey Vision" / "Hi Vision" and ~20 phonetic variants with 0.85 similarity threshold
3. **Active Session** -- Greeting plays (600ms delay for one-breath commands), silence timer starts, assistant awaits command
4. **NLP Parsing** -- `VoiceCommandParser.parse()` classifies the command via regex + fuzzy keyword matching
5. **Execution** -- ViewModel actions fire (date toggle, time mutation, month navigation, etc.)
6. **TTS Response** -- `AVSpeechSynthesizer` speaks a contextual confirmation using a cached premium male voice
7. **Session End** -- After execution or 8s absolute timeout, returns to passive listening

### Supported Commands

| Command | Example | Action |
|---------|---------|--------|
| Select dates | "select today", "select the 5th through the 10th" | Toggles dates on calendar |
| Deselect dates | "deselect today", "unselect the 5th", "remove the 8th" | Removes date selections |
| Bulk deselect | "deselect all", "remove all", "clear all" | Removes all active sessions |
| Set times | "set 9 to 5", "log 8 hours starting at 9 AM" | Updates session time range |
| Navigate month | "go to July", "show September" | Navigates calendar to target month |
| Switch view | "show timesheet", "switch to calendar" | Flips between calendar/timesheet |
| Copy report | "copy", "export" | Copies formatted report to clipboard |
| Camera on/off | "open your eyes", "close your eyes" | Toggles gesture camera |
| Weekday patterns | "select weekdays", "select Mondays and Wednesdays" | Bulk date selection |
| Relative dates | "select tomorrow", "select next Friday" | Relative date targeting |
| Pronouns | "remove them", "set those to 9 to 5" | Resolves to last selected dates |

### Audio Architecture

- **Zero-gap session restart** -- New recognition request is swapped in before the old session tears down, ensuring no audio buffers are lost during session transitions
- **Thread-safe buffer** -- `SpeechRequestHolder` uses `NSLock` to safely bridge the audio tap thread and the recognition request
- **Echo suppression** -- Recognition session is cancelled during TTS playback to prevent the assistant from transcribing its own voice
- **Error resilience** -- Transient recognizer errors (cancellation, no speech, network) are logged silently without speaking error messages

---

## Hand Gesture Control

HC features a full gesture control system using the iPad's front-facing
camera. The pipeline flows through four stages:

1. **Capture** -- AVFoundation camera session captures frames at device framerate
2. **Detection** -- Vision framework (`VNDetectHandPoseRequest`) extracts hand landmarks
3. **Filtering** -- One-Euro adaptive filter smooths finger position, eliminating jitter while preserving responsiveness
4. **Mapping** -- Filtered coordinates are mapped to screen space for hit-testing against UI elements

**Supported Gestures:**

| Gesture | Action |
|---------|--------|
| Index finger track | Cursor movement (One-Euro filtered) |
| Pinch (thumb + index) | Click / tap (scale-invariant with hysteresis) |
| Wrist rotation | Flip card (calendar / timesheet) |
| Directional swipe | Slider drag / list scroll |
| Hand depth (wrist-MCP) | Depth estimation for pinch calibration |

The `GestureCursorOverlay` renders a cyberpunk-styled cursor with outer ring,
inner dot, click ripple animation, and crosshair lines that follows the
tracked hand position in real-time.

---

## Terminal Preview

```
                            _===~_  _~===_
                      _--^^#####//     \#####^^--_
                   _-^##########// ( ) \##########^-_
                  -############// |\^^/| \############-
                _/############//  (o::o)  \############\_
               /#############((    \//    ))#############\
              -###############\\  (    )  //###############-
             -#################\\ / VV \ //#################-
            -###################\\/    \\//###################-
           _#/|##########/\######(  /\  )######/\##########|\#_
          |/  |#/\#/\#/\  \#/\##\ |  | /##/\#/ /\#/\#/\#|  \|
          `   |/  V  V `   V \#\| |  | |/#/ V  ` V  V  \|   `
              `   `  `      ` / | |  | | \ `     `  `   `
                              (  | |  | |  )
                             __\ | |  | | /__
                            (vvv(VVV)(VVV)vvv)

  [SYS] Midnight Forge v3.1 -- 2026-06-11 14:00:00
  [SYS] Calendar engine ............. [OK]
  [SYS] Haptic subsystem ............ [OK]
  [SYS] Clipboard bridge ............ [OK]
  [SYS] Pencil input ................ [OK]
  [SYS] Glitch renderer ............. [OK]

  Voice: ACTIVE | Transcript: "select the fifth"
  [SYS] Voice Engine: ACTIVE. Parsing command stream...
  [SYS] Voice Input: "select the fifth"
  [SYS] Ghost-click applied to day 5.
  [SYS] Vision: "I have selected the 5th of June for you."

  +================================================+
  |            WORK SESSION REPORT                  |
  +================================================+

  [WD] [01] 5 Jun: 07:00 --> 16:00
        Hour: 9:00

  +------------------------------------------------+
  | >>> Total Hours: 9:00
  +------------------------------------------------+

root@hc:~$ _
```

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
|   |   +-- GlassCalendarView.swift   # Front card, month grid, gesture hover
|   |-- Components/
|   |   |-- GlassmorphismBG.swift     # Forge palette + 6-layer BG + DragonArtRenderer
|   |   |-- GlitchFlipContainer.swift # 3-phase transition engine
|   |   +-- NeonTimeSlider.swift      # Custom haptic slider, frame reporting
|   |-- Main/
|   |   +-- TrackerHomeView.swift     # Root layout + terminal + GestureCursorOverlay
|   +-- Timesheet/
|       |-- TimeInputTableView.swift  # Back card, session rows
|       +-- TimesheetPreferenceKeys.swift # PreferenceKey definitions for hit-testing
+-- Utils/
    |-- ClipboardManager.swift        # UIPasteboard + haptic feedback
    |-- HandGestureManager.swift      # Front-camera gesture engine (Vision + One-Euro)
    +-- VoiceCommandManager.swift     # Voice assistant (Speech + NLP + TTS)
```

---

## Clipboard Output Format

```
8 Jun: 07:00 to 16:00
Hour: 9:00
9 Jun: 04:30 to 14:30
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
- Microphone access (required for voice command engine)
- Front-facing camera (required for hand gesture control)

---

## Author

**Nikan Eidi**
