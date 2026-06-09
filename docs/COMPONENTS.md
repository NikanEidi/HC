# Components Reference

Detailed documentation for every SwiftUI component in HC.

---

## GlassmorphismBG

**File:** `Views/Components/GlassmorphismBG.swift`

Full-screen background with 6 composited visual layers, the
`Forge` color palette definition, and the `DragonArtRenderer`.

**State:**
- `breathe: CGFloat` -- Aurora orb animation phase (0 to 1)
- `scanOffset: CGFloat` -- CRT scan beam position (0 to 1)

**Sub-views:**
- `perspectiveGrid` -- Canvas with vanishing point grid lines
- `auroraOrbs` -- Canvas with 3 radial gradient orbs
- `dragonWatermark` -- DragonArtRenderer output (ultra-detailed 30-row blueprint)
- `scanlines` -- Canvas with horizontal lines + sweep beam
- `vignette` -- RadialGradient darkening edges

---

## DragonArtRenderer

**File:** `Views/Components/GlassmorphismBG.swift`

Renders the ultra-detailed 30-row ASCII dragon blueprint with
per-character color mapping and animated visual effects.

**Character Classes (15+):**
Each character in the dragon art is classified and colored independently:

| Character | Class | Color |
|-----------|-------|-------|
| `#` | Body | Forge.arcane gradient |
| `*` | Sparkle | Animated pulse (frost/cipher) |
| `~` | Flame | Ember/crimson gradient |
| `^` | Horn | Forge.supernova |
| `o` | Eye | Forge.crimson (glow) |
| `/` `\` | Wing edge | Forge.cipher |
| `(` `)` | Contour | Forge.steel |
| `V` | Teeth/claw | Forge.frost |
| `=` | Scale | Forge.jade |
| `-` | Outline | Forge.ash |
| `_` | Base | Forge.phantom |
| `.` | Dot | Forge.steel (dim) |
| `+` | Joint | Forge.mint |
| `v` | Tail | Forge.arcane (dim) |
| ` ` | Space | Transparent |

**Features:**
- Flame breath particles with animated opacity cycling
- Sparkle particles with randomized phase offsets
- Per-character `foregroundColor` mapping via character classification
- Animated phase parameter drives sparkle/flame pulse effects

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

**Frame Reporting:**
- Reports slider frame via `SliderFramesKey` (`SliderFrameInfo`)
- Enables `GestureCursorOverlay` to detect gesture hover/drag on sliders

---

## GlassCalendarView

**File:** `Views/Calendar/GlassCalendarView.swift`

Month-view calendar grid with multi-date selection.

**State:**
- `hovered: Date?` -- Currently pencil-hovered or gesture-hovered date
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

**Frame Reporting:**
- Reports grid bounds via `CalendarGridFrameKey`
- Reports individual tappable cells via `TappableFramesKey`
- Gesture hover glow responds to `GestureCursorOverlay` position

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

**Frame Reporting:**
- Reports COPY button frame via `CopyButtonFrameKey`
- Enables gesture-based copy activation via `GestureCursorOverlay`

---

## TimesheetPreferenceKeys

**File:** `Views/Timesheet/TimesheetPreferenceKeys.swift`

PreferenceKey definitions enabling cross-view frame reporting
for the gesture hit-testing system.

**PreferenceKey Types:**

| Key | Value Type | Purpose |
|-----|-----------|---------|
| `CalendarGridFrameKey` | `CGRect` | Reports calendar grid bounds for gesture targeting |
| `CopyButtonFrameKey` | `CGRect` | Reports copy button bounds for gesture click |
| `SliderFramesKey` | `[SliderFrameInfo]` | Reports slider thumb frames for gesture drag |
| `TappableFramesKey` | `[TappableElement]` | Reports generic tappable regions (buttons, cells) |

**Support Types:**
- `SliderFrameInfo` -- Contains slider ID, frame rect, and axis orientation
- `TappableElement` -- Contains element ID and frame rect for hit-testing

**View Extension:**
- `reportTappableFrame(id:)` -- Convenience modifier that wraps a view's
  frame in a `TappableElement` and reports it via `TappableFramesKey`

---

## HandGestureManager

**File:** `Utils/HandGestureManager.swift`

Front-camera gesture engine (580 lines) powered by AVFoundation and
Apple's Vision framework. Tracks hand position and recognizes gestures
for touchless UI interaction.

**State Properties:**
- `indexFingerPosition: CGPoint` -- Filtered finger position in screen coords
- `isPinching: Bool` -- Thumb-index pinch detected (click)
- `isTracking: Bool` -- Hand currently visible in frame
- `wristAngle: CGFloat` -- Current wrist rotation angle
- `handDepth: CGFloat` -- Estimated hand distance (bounding box size)
- `swipeDirection: SwipeDirection?` -- Detected swipe (.left, .right, .up, .down)

**Gesture Types:**

| Gesture | Detection Method | Threshold |
|---------|-----------------|-----------|
| Pinch (click) | Thumb tip ↔ index tip distance | < distance threshold |
| Wrist rotation (flip) | Angle delta from `AngleSample` buffer | > rotation threshold |
| Directional swipe | Index finger velocity + direction | > velocity threshold |
| Hand depth (zoom) | Hand bounding box area relative to frame | Continuous |

**One-Euro Filter Parameters:**
- `OneEuroFilter` -- Single-axis adaptive low-pass filter
- `OneEuroFilter2D` -- Dual-axis wrapper for 2D point smoothing
- `minCutoff` -- Minimum cutoff frequency (smoothness at rest)
- `beta` -- Speed coefficient (responsiveness during motion)
- `dCutoff` -- Derivative cutoff frequency

**Support Types:**
- `FrameDelegate` -- `AVCaptureVideoDataOutputSampleBufferDelegate` implementation
- `AngleSample` -- Timestamped wrist angle sample for rotation detection

**Pipeline:**
1. AVFoundation captures front-camera frames
2. Vision framework processes `VNDetectHandPoseRequest`
3. Hand landmarks extracted (21 joint points)
4. Index finger tip position passed through `OneEuroFilter2D`
5. Gesture recognizers evaluate pinch/swipe/rotation/depth
6. Filtered state published for `GestureCursorOverlay` consumption

---

## GestureCursorOverlay

**File:** `Views/Main/TrackerHomeView.swift`

Overlay view within `TrackerHomeView` that renders the gesture cursor
and performs hit-testing against reported UI element frames.

**Cursor Rendering:**
- Outer ring: 36pt circle, Forge.cipher stroke, 2pt width
- Inner dot: 8pt filled circle, Forge.frost
- Click ripple: Expanding circle animation on pinch detection
- Crosshair: Horizontal + vertical lines through cursor center

**Hit-Testing:**
- Collects frames from all `PreferenceKey` types
- Tests cursor position against `CalendarGridFrameKey` frames
- Tests cursor position against `CopyButtonFrameKey` frame
- Tests cursor position against `SliderFramesKey` frames
- Tests cursor position against `TappableFramesKey` frames
- Matched element receives hover glow / activation on pinch

**State:**
- Reads `HandGestureManager` position for cursor placement
- Reads gesture events to trigger corresponding ViewModel actions
- Animates cursor appearance (fade in/out based on hand tracking state)

---

## TrackerHomeView

**File:** `Views/Main/TrackerHomeView.swift`

Root composition view with asymmetric 2-panel layout.

**Left Panel (45% width, max 490pt):**
- Top bar: Flip button + Export button + Status pill
- Body: GlitchFlipContainer (Calendar / Timesheet)

**Right Panel (remaining width):**
- Title bar: Traffic lights + "DRAGON-TERMINAL v3.0" + LIVE indicator
- Status bar: SYS | SESS | HRS | UP (live uptime counter)
- Body: Scrollable terminal with ASCII dragon header
- Prompt: `root@hc:~$` with blinking cursor

**Terminal Content:**
1. Dragon ASCII art header (ultra-detailed 30-row blueprint)
2. System boot messages (6 modules, each with [OK] status)
3. Work Session Report section (box-drawn borders)
4. Per-session entries with [WD]/[WE] tags
5. Total hours summary
6. Blinking cursor prompt

**Internal Types:**
- `TLine` -- Terminal line model (content + type)
- `TLineType` -- Line category enum for styling

**Overlays:**
- `GestureCursorOverlay` -- Gesture cursor + hit-testing layer

**Timers:**
- Cursor blink: 0.45s interval
- Uptime counter: 1s interval
