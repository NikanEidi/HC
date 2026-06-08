# Components Reference

Detailed documentation for every SwiftUI component in HC.

---

## GlassmorphismBG

**File:** `Views/Components/GlassmorphismBG.swift`

Full-screen background with 5 composited visual layers and the
`Forge` color palette definition.

**State:**
- `breathe: CGFloat` -- Aurora orb animation phase (0 to 1)
- `scanOffset: CGFloat` -- CRT scan beam position (0 to 1)

**Sub-views:**
- `perspectiveGrid` -- Canvas with vanishing point grid lines
- `auroraOrbs` -- Canvas with 3 radial gradient orbs
- `dragonWatermark` -- VStack of Text views forming ASCII dragon
- `scanlines` -- Canvas with horizontal lines + sweep beam
- `vignette` -- RadialGradient darkening edges

---

## GlassCard (ViewModifier)

**File:** `Views/Components/GlassmorphismBG.swift`

Applies frosted glass card styling to any view.

**Usage:**
```swift
MyView()
    .glassCard(radius: 22, border: 0.08, glow: Forge.arcane)
```

**Rendering:**
- Obsidian base fill at 85% opacity
- Ultra-thin material at 6% for frost effect
- Gradient border stroke (white, 0.5pt)
- Continuous rounded rectangle clip
- Dual shadow (colored glow + black depth)

---

## GlitchFlipContainer

**File:** `Views/Components/GlitchFlipContainer.swift`

Generic container flipping between two views with chromatic
aberration and shatter artifacts.

**Type Parameters:**
- `Front: View` -- The calendar (default visible)
- `Back: View` -- The timesheet (visible after flip)

**State:**
- `rotation: Double` -- Current 3D rotation (0 or 180)
- `glitch: CGFloat` -- Distortion intensity (0 to 1)
- `noise: CGFloat` -- Scanline noise opacity
- `split: CGFloat` -- RGB channel separation offset
- `offsets: [CGSize]` -- 8 horizontal slice displacements
- `sliceAlpha: [CGFloat]` -- 8 slice opacity values

**Animation Phases:**
1. **Build** (0.18x duration): Distortion ramps up
2. **Flip** (0.45x duration): 3D rotation + peak artifacts
3. **Settle** (0.35x duration): All effects fade to zero

**Total duration:** 0.55 seconds

---

## NeonTimeSlider

**File:** `Views/Components/NeonTimeSlider.swift`

Custom drag slider for time input (0-1440 minutes from midnight).

**Properties:**
- `label: String` -- Display label ("FROM" or "TO")
- `minutes: Binding<Int>` -- Current value in minutes
- `accent: Color` -- Track/thumb color (default: Forge.cipher)

**Behavior:**
- Snaps to 15-minute intervals
- Haptic feedback on each snap (light, 0.3 intensity)
- Medium haptic on drag end (0.45 intensity)
- Hours display: always 2-digit padded (07:00, not 7:00)
- Thumb scales up during drag (15pt to 20pt)
- Outer glow ring appears during drag (36pt circle)

**Track Composition:**
- Background: Capsule, ash at 18% opacity, 4pt height
- Tick marks: 24 hourly dividers, frost at 4%
- Active fill: Triple gradient (30% to 100% accent)
- Thumb: RadialGradient (frost center to accent edge)

---

## GlassCalendarView

**File:** `Views/Calendar/GlassCalendarView.swift`

Month-view calendar grid with multi-date selection.

**State:**
- `hovered: Date?` -- Currently pencil-hovered date
- `pulse: CGFloat` -- Header glow animation phase

**Layout:**
- Navigation: Left/right chevron buttons + month title
- Weekday row: MON-SUN headers (red for SAT/SUN)
- Day grid: 7-column LazyVGrid, 54pt cell height
- Badge: Selection count capsule (appears when count > 0)

**Cell States:**
- **Default**: frost at 55% opacity, 8% background
- **Weekend**: crimson at 40% text, 55% text on weekdays
- **Selected weekday**: arcane/cipher gradient border + cyan dot
- **Selected weekend**: crimson/ember gradient border + ember dot
- **Today (unselected)**: subtle cyan capsule underline
- **Hovered**: white at 2.5% background

---

## TimeInputTableView

**File:** `Views/Timesheet/TimeInputTableView.swift`

Scrollable list of work sessions with inline time sliders.

**Layout:**
- Header: ">>" label + "TIMESHEET" title + COPY button
- Session rows: Index badge + date + duration + dual sliders
- Empty state: "---" + "NO SESSIONS" text
- Total bar: ">>>" + "TOTAL HOURS" + gradient number (28pt)

**Session Row Composition:**
- Index: 2-digit mono badge (01, 02, 03...)
- Status dot: crimson (weekend) or arcane (weekday)
- Date: uppercase, 14pt black mono
- Duration: gradient text (cipher to arcane), 17pt
- FROM slider: cipher accent
- TO slider: arcane accent

---

## TrackerHomeView

**File:** `Views/Main/TrackerHomeView.swift`

Root composition view with asymmetric 2-panel layout.

**Left Panel (45% width, max 490pt):**
- Top bar: Flip button + Export button + Status pill
- Body: GlitchFlipContainer (Calendar / Timesheet)

**Right Panel (remaining width):**
- Title bar: Traffic lights + "DRAGON-TERMINAL v2.0" + LIVE indicator
- Status bar: SYS | SESS | HRS | UP (live uptime counter)
- Body: Scrollable terminal with ASCII dragon header
- Prompt: `root@hc:~$` with blinking cursor

**Terminal Content:**
1. Dragon ASCII art header (15 lines)
2. System boot messages (5 modules, each with [OK] status)
3. Work Session Report section (box-drawn borders)
4. Per-session entries with [WD]/[WE] tags
5. Total hours summary
6. Blinking cursor prompt

**Timers:**
- Cursor blink: 0.45s interval
- Uptime counter: 1s interval
