# Architecture

## Overview

HC follows the **MVVM (Model-View-ViewModel)** architecture pattern using SwiftUI's
native `@Observable` macro for reactive state management. In v3.0, the architecture
extends with a **gesture pipeline** that bridges the front-facing camera to the
SwiftUI view hierarchy via hit-testing and preference keys.

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
                          |  + report()       |            ^
                          +-------------------+            |
                                                           |
                          +-------------------+            |
                          | GESTURE PIPELINE  |            |
                          |                   |            |
                          | HandGestureManager|----------->|
                          | - AVFoundation    |  GestureCursorOverlay
                          | - Vision          |  (hit-testing via
                          | - One-Euro Filter |   PreferenceKeys)
                          +-------------------+
```

## Data Flow

1. **User taps a date** in `GlassCalendarView`
2. View calls `viewModel.toggleDate(date)` 
3. ViewModel inserts a `WorkSession` with default 7:00-16:00 times
4. `@Observable` triggers SwiftUI to re-render all dependent views
5. Terminal panel (`TrackerHomeView.render()`) rebuilds its line array
6. Timesheet (`TimeInputTableView`) shows a new row with sliders

**Gesture flow** (alternative input path):

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
    +-- HandGestureManager.swift
        Front-camera gesture engine (580 lines).
        AVFoundation capture session + Vision framework.
        Tracks index finger position, detects pinch (click),
        wrist rotation (flip), directional swipes, hand depth.
        One-Euro adaptive filter (OneEuroFilter, OneEuroFilter2D).
        Support types: FrameDelegate, AngleSample.
```

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
- **Pinch**: Distance between thumb tip and index tip below threshold → click
- **Wrist rotation**: Angle change from `AngleSample` buffer → card flip
- **Swipe**: Velocity + direction of index finger movement → calendar navigation
- **Depth**: Hand bounding box size relative to frame → zoom factor

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
