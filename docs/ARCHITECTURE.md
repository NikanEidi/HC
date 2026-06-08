# Architecture

## Overview

HC follows the **MVVM (Model-View-ViewModel)** architecture pattern using SwiftUI's
native `@Observable` macro for reactive state management.

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
                          |  + report()       |
                          +-------------------+
```

## Data Flow

1. **User taps a date** in `GlassCalendarView`
2. View calls `viewModel.toggleDate(date)` 
3. ViewModel inserts a `WorkSession` with default 7:00-16:00 times
4. `@Observable` triggers SwiftUI to re-render all dependent views
5. Terminal panel (`TrackerHomeView.render()`) rebuilds its line array
6. Timesheet (`TimeInputTableView`) shows a new row with sliders

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
|       clipboard report generation.
|
|-- Views/
|   |-- Calendar/
|   |   +-- GlassCalendarView.swift
|   |       Front face of the flip card.
|   |       Month grid with multi-select.
|   |       Weekend cells: crimson/ember borders.
|   |       Weekday cells: arcane/cipher borders.
|   |
|   |-- Components/
|   |   |-- GlassmorphismBG.swift
|   |   |   Forge color palette (13 colors).
|   |   |   5-layer background composition.
|   |   |   GlassCard ViewModifier.
|   |   |
|   |   |-- GlitchFlipContainer.swift
|   |   |   Generic 3D flip with chromatic aberration.
|   |   |   3-phase animation: build -> flip -> settle.
|   |   |
|   |   +-- NeonTimeSlider.swift
|   |       Custom drag slider, 0-1440 minutes range.
|   |       15-minute snap with haptic feedback.
|   |
|   |-- Main/
|   |   +-- TrackerHomeView.swift
|   |       Root composition. Asymmetric 2-panel layout.
|   |       Left: GlitchFlipContainer (Calendar/Timesheet).
|   |       Right: ANSI terminal with dragon header.
|   |
|   +-- Timesheet/
|       +-- TimeInputTableView.swift
|           Back face of the flip card.
|           Scrollable session rows with dual sliders.
|           Gradient total bar at bottom.
|
+-- Utils/
    +-- ClipboardManager.swift
        Static utility. UIPasteboard + haptic.
```

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
