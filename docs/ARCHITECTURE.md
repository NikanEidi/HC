# Architecture

## Overview

HC follows the **MVVM (Model-View-ViewModel)** architecture pattern using SwiftUI's
native `@Observable` macro for reactive state management. In v4.0, the architecture
extends with two independent input pipelines: a **voice command engine** that parses
natural language into ViewModel actions, and a **gesture pipeline** that bridges the
front-facing camera to the SwiftUI view hierarchy via hit-testing and preference keys.

```
+------------------+     +-------------------+     +------------------+
|      MODEL       |     |    VIEWMODEL      |     |      VIEWS       |
|                  |     |                   |     |                  |
|  WorkSession     |<--->|  TrackerViewModel |<--->|  TrackerHomeView |
|  - id: UUID      |     |  - sessions       |     |  - GlitchFlip    |
|  - date          |     |  - selectedDates  |     |  - Calendar      |
|  - startTime     |     |  - currentMonth   |     |  - Timesheet     |
|  - endTime       |     |                   |     |  - Terminal       |
|  - duration      |     |  + toggleDate()   |     |                  |
+------------------+     |  + totalHours()   |     +------------------+
                          |  + report()       |            ^    ^
                          |  + updateSession  |            |    |
                          |    Times()        |            |    |
                          +-------------------+            |    |
                                ^         ^                |    |
                                |         |                |    |
                  +-------------+    +----+---------+      |    |
                  | VOICE ENGINE|    | GESTURE      |      |    |
                  |             |    | PIPELINE     |      |    |
                  | VoiceCommand|    |              |      |    |
                  | Manager     |    | HandGesture  |------+    |
                  | - Speech    |    | Manager      | GestureCursorOverlay
                  | - NLP       |    | - AVFoundation|  (hit-testing via
                  | - TTS       |    | - Vision     |   PreferenceKeys)
                  +-------------+    | - One-Euro   |
                                     +--------------+
```

## Data Flow

### Touch / Pencil Input (primary)

1. **User taps a date** in `GlassCalendarView`
2. View calls `viewModel.toggleDate(date)`
3. ViewModel inserts a `WorkSession` with default 7:00-16:00 times
4. `@Observable` triggers SwiftUI to re-render all dependent views
5. Terminal panel (`TrackerHomeView.render()`) rebuilds its line array
6. Timesheet (`TimeInputTableView`) shows a new row with sliders

### Voice Input

1. `VoiceCommandManager` runs a continuous `SFSpeechRecognizer` session
2. Partial transcription results are checked for the wake word ("Hey Vision")
3. On wake word match, system enters active session and awaits command
4. Silence timer fires after speech stops (2.5s in active mode)
5. `extractIntent()` classifies the command (date selection, time mutation, navigation, etc.)
6. Intent is dispatched to `TrackerViewModel` actions (same mutations as touch input)
7. `AVSpeechSynthesizer` speaks a contextual confirmation
8. Recognition session restarts seamlessly with zero-gap request swapping

### Gesture Input (alternative)

1. `HandGestureManager` captures frames from the front camera via AVFoundation
2. Vision framework detects hand pose landmarks (`VNDetectHandPoseRequest`)
3. One-Euro adaptive filter smooths raw finger coordinates
4. `GestureCursorOverlay` maps filtered position to screen coordinates
5. Hit-testing against `PreferenceKey` frames identifies the target UI element
6. Gesture events (pinch, swipe, rotate) trigger ViewModel actions

## File Map

```
HC/
|-- APP/
|   +-- HCApp.swift
|       Entry point. Sets .preferredColorScheme(.dark).
|       Launches TrackerHomeView as root.
|
|-- Models/
|   +-- WorkSession.swift
|       Pure value type. Identifiable + Equatable.
|       Computed: durationMinutes, durationString,
|       startTimeString, endTimeString.
|
|-- ViewModels/
|   +-- TrackerViewModel.swift
|       @Observable class. Owns all mutable state.
|       Handles: date selection, session CRUD,
|       time binding factories, calendar navigation,
|       clipboard report generation, gesture slider adjustments.
|
|-- Views/
|   |-- Calendar/
|   |   +-- GlassCalendarView.swift
|   |       Front face of the flip card.
|   |       Month grid with multi-select.
|   |       Weekend cells: crimson/ember borders.
|   |       Weekday cells: arcane/cipher borders.
|   |       Reports frames via CalendarGridFrameKey
|   |       and TappableFramesKey for gesture hit-testing.
|   |
|   |-- Components/
|   |   |-- GlassmorphismBG.swift
|   |   |   Forge color palette (13 colors).
|   |   |   6-layer background composition.
|   |   |   GlassCard ViewModifier.
|   |   |   DragonArtRenderer: ultra-detailed 30-row dragon
|   |   |   with per-character coloring (15+ classes),
|   |   |   flame breath, sparkle particles, animated phase.
|   |   |
|   |   |-- GlitchFlipContainer.swift
|   |   |   Generic 3D flip with chromatic aberration.
|   |   |   3-phase animation: build -> flip -> settle.
|   |   |
|   |   +-- NeonTimeSlider.swift
|   |       Custom drag slider, 0-1440 minutes range.
|   |       15-minute snap with haptic feedback.
|   |       Reports frame via SliderFramesKey for gesture interaction.
|   |
|   |-- Main/
|   |   +-- TrackerHomeView.swift
|   |       Root composition. Asymmetric 2-panel layout.
|   |       Left: GlitchFlipContainer (Calendar/Timesheet).
|   |       Right: ANSI terminal with dragon header.
|   |       Contains GestureCursorOverlay for gesture-to-UI
|   |       mapping with hit-testing against PreferenceKey frames.
|   |       Contains TLine/TLineType models for terminal rendering.
|   |       Hosts VoiceCommandManager as @StateObject.
|   |
|   +-- Timesheet/
|       |-- TimeInputTableView.swift
|       |   Back face of the flip card.
|       |   Scrollable session rows with dual sliders.
|       |   Gradient total bar at bottom.
|       |   Reports frame via CopyButtonFrameKey for gesture hit-testing.
|       |
|       +-- TimesheetPreferenceKeys.swift
|           PreferenceKey definitions for cross-view frame reporting.
|           CalendarGridFrameKey: calendar grid bounds.
|           CopyButtonFrameKey: copy button bounds.
|           SliderFrameInfo / SliderFramesKey: slider thumb frames.
|           TappableElement / TappableFramesKey: generic tappable regions.
|           reportTappableFrame(id:) View extension.
|
+-- Utils/
    |-- ClipboardManager.swift
    |   Static utility. UIPasteboard + haptic.
    |
    |-- HandGestureManager.swift
    |   Front-camera gesture engine.
    |   AVFoundation capture session + Vision framework.
    |   Tracks index finger position, detects pinch (click),
    |   wrist rotation (flip), directional swipes, hand depth.
    |   One-Euro adaptive filter (OneEuroFilter, OneEuroFilter2D).
    |   Support types: FrameDelegate, AngleSample.
    |
    +-- VoiceCommandManager.swift
        Continuous voice assistant (~1600 lines).
        SFSpeechRecognizer for wake word + command transcription.
        NLP intent parser: regex date/time extraction,
        fuzzy keyword matching, pronoun resolution,
        weekday pattern detection, month navigation.
        AVSpeechSynthesizer with cached premium voice.
        Thread-safe SpeechRequestHolder for audio buffering.
        CommandIntent enum: selectDate, removeDate, timeMutation,
        navigateMonth, activateCamera, deactivateCamera,
        copyReport, switchView, unknown.
```

## Voice System Architecture

The voice command engine transforms continuous audio into ViewModel actions
through a multi-stage pipeline:

```
┌────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│  AVAudioEngine │───>│ SFSpeechRecognizer│───>│  Wake Word       │
│  Hardware Tap  │    │ Partial Results  │    │  Detection       │
│  (Bus 0, 1024) │    │ (en-US locale)   │    │  (Levenshtein)   │
└────────────────┘    └──────────────────┘    └────────┬─────────┘
                                                        │
                                                        v
┌────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│  TrackerVM     │<───│  Intent Dispatch │<───│  NLP Parser      │
│  Action Trigger│    │  (CommandIntent  │    │  extractIntent() │
│                │    │   enum switch)   │    │  - date regex    │
└────────────────┘    └──────────────────┘    │  - time regex    │
        │                                      │  - NSDataDetector│
        v                                      │  - keyword match │
┌────────────────┐                             └──────────────────┘
│  AVSpeech      │
│  Synthesizer   │
│  (TTS Response)│
└────────────────┘
```

### State Machine

The voice engine operates as a two-state machine:

1. **STANDBY** -- Passive listening. Recognition session runs continuously.
   Partial transcription results are checked for the wake word only.
   No commands are parsed; no errors are spoken.

2. **ACTIVE** -- Triggered by wake word detection. The assistant greets
   the user (with a 600ms delay to allow same-breath commands), then
   waits for a command. A silence timer (2.5s) executes the accumulated
   transcript as a command. An absolute timeout (8s) returns to STANDBY.

### Zero-Gap Session Restart

Speech recognition sessions have a 1-minute limit imposed by Apple.
When a session ends (final result or error), a new session must start
immediately to maintain continuous listening. The engine creates and
installs the new `SFSpeechAudioBufferRecognitionRequest` before
tearing down the old session, ensuring the audio tap always has a
valid request to write to. This eliminates the audio gap that previously
caused the first wake word attempt to fail.

### Echo Suppression

When the TTS synthesizer is speaking, the recognition session is
cancelled entirely to prevent the engine from transcribing its own
voice output. After speech finishes (`AVSpeechSynthesizerDelegate`),
a new recognition session starts with a 4-second silence timer to
allow the user to respond.

### NLP Intent Classification

`extractIntent()` evaluates commands in priority order:

1. **Switch view** -- "show timesheet", "switch to calendar"
2. **Camera toggle** -- "open your eyes", "close your eyes"
3. **Clipboard copy** -- "copy", "export"
4. **Bulk deselect** -- "remove all", "deselect all", "clear all"
5. **Navigate month** -- "go to July", "show September"
6. **Date resolution** -- relative dates, NSDataDetector, regex patterns, weekday patterns, implicit day numbers
7. **Pronoun resolution** -- "remove them", "set those" -> last selected dates
8. **Time mutation** -- "9 to 5", "8 hours starting at 9 AM", "standard shift"
9. **Select/Remove dispatch** -- based on verb keywords + resolved dates
10. **Unknown** -- fallback with throttled error response (8s cooldown)

Number preprocessing (`preprocessNumbers()`) converts spoken ordinals
("twenty-first" -> "21") but is scoped exclusively to date parsing,
preventing corruption of intent keywords.

## Gesture System Architecture

The gesture pipeline transforms raw camera frames into precise UI interactions:

```
┌────────────────┐    ┌──────────────┐    ┌──────────────────┐
│  AVFoundation  │───>│ Vision.framework│───>│  One-Euro Filter │
│  Camera Capture│    │ Hand Pose     │    │  (Adaptive)      │
│  (front cam)   │    │ Detection     │    │                  │
└────────────────┘    └──────────────┘    └────────┬─────────┘
                                                    │
                                                    v
┌────────────────┐    ┌──────────────┐    ┌──────────────────┐
│  ViewModel     │<───│  Hit-Testing │<───│  Screen-Space    │
│  Action Trigger│    │  (Preference │    │  Coordinate Map  │
│                │    │   Key Frames)│    │                  │
└────────────────┘    └──────────────┘    └──────────────────┘
```

### Camera Pipeline
- `HandGestureManager` configures an `AVCaptureSession` with the front-facing camera
- Frames are processed via `FrameDelegate` (AVCaptureVideoDataOutputSampleBufferDelegate)
- Vision's `VNDetectHandPoseRequest` extracts 21 hand landmarks per frame

### One-Euro Adaptive Filter
- `OneEuroFilter` / `OneEuroFilter2D` provide per-axis jitter suppression
- Adapts cutoff frequency based on movement speed (fast motion = less filtering)
- Parameters: `minCutoff`, `beta`, `dCutoff` tuned for responsive cursor tracking

### Gesture Recognition
- **Pinch**: Distance between thumb tip and index tip below threshold -> click
- **Wrist rotation**: Angle change from `AngleSample` buffer -> card flip
- **Swipe**: Velocity + direction of index finger movement -> calendar navigation
- **Depth**: Hand bounding box size relative to frame -> zoom factor

### Hit-Testing
- Views report their frames via `PreferenceKey` types (defined in `TimesheetPreferenceKeys.swift`)
- `GestureCursorOverlay` in `TrackerHomeView` collects all reported frames
- Cursor position is tested against known frames to determine the active target
- Matched targets trigger hover states, and gesture events invoke corresponding actions

## Key Design Decisions

### Why @Observable over @StateObject?

`@Observable` (iOS 17+) provides fine-grained property tracking.
Only views reading a specific property re-render when it changes.
`@StateObject` would cause full re-renders on any property mutation.

### Why @StateObject for VoiceCommandManager?

`VoiceCommandManager` uses `@MainActor` + `ObservableObject` (Combine-based)
rather than `@Observable` because it manages long-lived audio resources
(AVAudioEngine, SFSpeechRecognizer, AVSpeechSynthesizer) that require
careful lifecycle management tied to the SwiftUI view lifecycle.
`@StateObject` ensures the manager survives view re-renders and is
properly torn down when the view is dismissed.

### Why zero-gap session restart?

Apple's speech recognition sessions have a ~1 minute limit. When a
session ends, the audio tap continues writing buffers to
`SpeechRequestHolder.request`. If `request` is nil during the gap
between old session teardown and new session setup, those buffers
are silently dropped. By creating and installing the new request
before cancelling the old session, the audio tap always has a valid
target -- eliminating the "first attempt fails" problem.

### Why exact matching for short keywords?

Levenshtein fuzzy matching on short words (<=5 characters) produces
excessive false positives. "copy" would match "cop", "hop", etc.
Words 5 characters or shorter now require exact substring match,
while longer words (6+ characters) still get fuzzy matching at an
0.80 similarity threshold. This dramatically reduces false activations
while preserving tolerance for speech recognition garbling on longer words.

### Why binding factories instead of @Binding?

The `startMinutesBinding(for:)` / `endMinutesBinding(for:)` pattern
returns a `(get: () -> Int, set: (Int) -> Void)` tuple. This avoids
the need for `@Binding` to computed properties, which SwiftUI doesn't
support natively for array elements accessed by index.

### Why custom slider over SwiftUI Slider?

SwiftUI's native `Slider` doesn't support:
- Haptic feedback on value changes
- Custom thumb rendering (glow ring, pulse)
- Snap-to-increment behavior
- Apple Pencil hover effects

### Why GlitchFlipContainer over matchedGeometryEffect?

The flip needs custom chromatic aberration artifacts and scanline
noise that `matchedGeometryEffect` can't produce. The 3-phase
animation (build distortion -> flip -> settle) requires manual
`DispatchQueue` timing.

### Why One-Euro filter over simple smoothing?

Simple low-pass filters (e.g., exponential moving average) impose a fixed
trade-off between smoothness and latency. The One-Euro adaptive filter
adjusts its cutoff frequency based on movement speed: slow movements get
heavy smoothing (no jitter), fast movements get minimal smoothing (no lag).
This is critical for gesture cursor UX where both precision hovering and
rapid swipes must feel responsive.

### Why PreferenceKeys for gesture hit-testing?

SwiftUI doesn't expose view frames directly. `PreferenceKey` is the
idiomatic mechanism for child views to report geometry upward to a
parent coordinator (`GestureCursorOverlay`). This avoids
`GeometryReader` nesting and keeps views decoupled from the gesture system.
