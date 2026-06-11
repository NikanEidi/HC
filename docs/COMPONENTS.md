# Components Reference

Detailed documentation for every SwiftUI component and utility in HC.

---

## VoiceCommandManager

**File:** `Utils/VoiceCommandManager.swift`

Continuous voice assistant that listens for a wake word, parses natural
language commands via NLP/regex, executes ViewModel actions, and responds
with text-to-speech.

**Class:** `@MainActor class VoiceCommandManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate`

**Published State:**
- `liveTranscript: String` -- Current speech transcription text
- `systemStatus: String` -- "STANDBY" or "ACTIVE"
- `voiceLogs: [String]` -- Rolling log buffer (max 15 entries)
- `isListening: Bool` -- Whether audio engine is running

**External Wiring:**
- `hoveredDate: Date?` -- Currently gesture-hovered date (for context)
- `onActivateCamera: (() -> Void)?` -- Callback to enable gesture camera
- `onDeactivateCamera: (() -> Void)?` -- Callback to disable gesture camera
- `onSwitchView: ((Bool) -> Void)?` -- Callback to flip calendar/timesheet
- `setup(viewModel:)` -- Initializes with ViewModel reference and requests permissions

**Audio Pipeline:**
- `AVAudioEngine` with input node tap (bus 0, 1024 buffer size)
- `SFSpeechRecognizer` (en-US locale) with continuous recognition
- Audio session: `.playAndRecord` mode with `.defaultToSpeaker` and `.duckOthers`
- `SpeechRequestHolder` for thread-safe buffer bridging

**Wake Word Detection:**
- Candidates: "hey vision", "hi vision", and ~20 phonetic variants
- Fuzzy matching via Levenshtein distance with 0.85 similarity threshold
- Sliding window (1-3 words) across tokenized transcript

**NLP Parser (`VoiceCommandParser.parse()`):**
- Priority-ordered intent classification (camera > copy > switch view > navigate month > bulk deselect > date+time pipeline)
- Number preprocessing scoped to date parsing only
- `NSDataDetector` for date entity extraction
- Regex patterns for "day of month", "month day-list", day ranges
- Relative date parsing (today, tomorrow, yesterday, next weekday)
- Weekday pattern matching (weekdays, weekends, specific day names)
- Implicit day extraction with AM/PM context filtering
- Pronoun resolution to last selected dates
- Time range parsing (duration, standard shift, range, single time)

**TTS Engine:**
- `AVSpeechSynthesizer` with cached premium male en-US/en-GB voice
- Speech rate: 0.52, pitch multiplier: 1.0
- Echo suppression: recognition cancelled during TTS playback
- Delegate-based lifecycle for post-speech session restart

**Timers:**
- Silence timer: 2.5s (active mode), 2.0s (same-breath command), 5.0s (greeting wait), 4.0s (post-TTS)
- Absolute timeout: 8s (returns to STANDBY)
- Greeting delay: 600ms (cancelled if user speaks immediately)
- Error cooldown: 8s (prevents repeated error messages)

---

## CommandIntent

**File:** `Utils/VoiceCommandManager.swift`

Enum representing parsed NLP intents from voice commands.

**Cases:**

| Case | Associated Values | Triggered By |
|------|-------------------|--------------|
| `selectDate` | `dates: [Date]` | "select", "add", "mark", "pick", "highlight" |
| `removeDate` | `dates: [Date]` | "remove", "delete", "deselect", "unselect", "clear" |
| `timeMutation` | `dates: [Date], startMinutes: Int, endMinutes: Int` | "set 9 to 5", "log 8 hours" |
| `navigateMonth` | `targetMonth: Date` | "go to July", "show September" |
| `activateCamera` | -- | "open your eyes", "open vision" |
| `deactivateCamera` | -- | "close your eyes", "close vision" |
| `copyReport` | -- | "copy", "export" |
| `switchView` | `showTimesheet: Bool` | "show timesheet", "switch to calendar" |
| `unknown` | `command: String` | Unrecognized input |

---

## SpeechRequestHolder

**File:** `Utils/VoiceCommandManager.swift`

Thread-safe container bridging the audio tap thread and the recognition request.

**Class:** `final class SpeechRequestHolder: @unchecked Sendable`

- Uses `NSLock` for synchronization
- `request` property: get/set with lock guard
- Allows the background audio tap to append PCM buffers without actor isolation violations

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

Renders the ASCII dragon blueprint with per-character color mapping
and animated visual effects via `getDragonCharColor()`.

**Character Classes (15+):**
Each character is classified and colored based on identity, row position, and animation pulse:

| Character | Class | Color |
|-----------|-------|-------|
| `#` | Body scales | Vertical gradient: Cipher -> Jade -> Arcane -> Supernova -> Ember |
| `O`, `:` | Eyes (rows 5-6) | Crimson -> Supernova animated pulse |
| `>`, `<` | Flame breath | Ember -> Crimson animated glow |
| `{`, `}` | Flame brackets | Supernova -> Ember animated |
| `*` | Sparkle particles | Mint -> Cipher animated pulse |
| `=` | Wing membrane / ridges | Cipher -> Arcane (rows 7-11), Supernova (elsewhere) |
| `~` | Ridges / crown | Supernova (rows 0-2), Arcane -> Cipher (elsewhere) |
| `^` | Wing tips | Jade (rows 0-4), Jade -> Mint animated |
| `/`, `\` | Wing edges | Arcane at 70% opacity |
| `(`, `)` | Structural curves | Cipher at 75% opacity |
| `V` | Talons (row >= 23) / Wing core (rows 6-7) | Supernova / Ember -> Supernova |
| `v` | Tail feathers (row >= 23) | Steel -> Supernova blend |
| `Y` | Tail tip | Supernova |
| `-`, `_` | Borders | Steel at 45% opacity |
| `.`, `,` | Dot details | Mint at 50% opacity |
| ` ` | Space | Steel at 8% opacity |

**Features:**
- Flame breath with animated ember/crimson cycling driven by pulse parameter
- Sparkle particles with mint/cipher animation
- Body scales with vertical color gradient based on row position
- `tokenizeDragonLine()` groups consecutive same-colored characters for performance
- `tokenizeBorderLine()` renders metadata tags with colored keywords

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
- Reports individual tappable cells via `TappableFramesKey` (id format: `date_N`)
- Navigation buttons report frames via `reportTappableFrame(id:)` (`prevMonth`, `nextMonth`)
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
| `CopyButtonFrameKey` | `CGRect` | Reports copy button bounds for gesture hover glow |
| `SliderFramesKey` | `[SliderFrameInfo]` | Reports slider track frames for gesture drag |
| `TappableFramesKey` | `[TappableElement]` | Reports generic tappable regions (buttons, calendar cells) |

**Support Types:**
- `SliderFrameInfo` -- Contains `sessionID: UUID`, `isStartSlider: Bool`, and `frame: CGRect`
- `TappableElement` -- Contains `id: String` and `frame: CGRect` for hit-testing

**View Extension:**
- `reportTappableFrame(id:)` -- Convenience modifier that wraps a view's
  frame in a `TappableElement` and reports it via `TappableFramesKey`

---

## HandGestureManager

**File:** `Utils/HandGestureManager.swift`

`@Observable` front-camera gesture engine powered by AVFoundation and
Apple's Vision framework. Tracks hand position and recognizes gestures
for touchless UI interaction. Supports both left and right hands.

**Public State Properties:**
- `fingerPosition: CGPoint` -- One-Euro filtered index finger position in screen-normalized coords (0,0 top-left to 1,1 bottom-right)
- `isTracking: Bool` -- Whether any hand is currently being tracked
- `isCameraAuthorized: Bool` -- Whether camera access has been authorized
- `isClickDetected: Bool` -- Fires true for ~150ms on pinch-release click
- `clickPosition: CGPoint` -- Screen-normalized position where click occurred
- `isFingerDown: Bool` -- True while thumb and index are pinched
- `shouldSwitchView: Bool` -- Momentarily true when wrist flip detected
- `horizontalSliderDelta: CGFloat` -- Horizontal velocity delta (points/frame) for slider adjustment
- `verticalScrollDelta: CGFloat` -- Vertical velocity delta (points/frame) for list scrolling
- `handDepth: CGFloat` -- Estimated hand depth (wrist-to-middleMCP distance)

**Gesture Types:**

| Gesture | Detection Method | Threshold |
|---------|-----------------|-----------|
| Pinch (click) | Scale-invariant ratio (thumb-index dist / hand size) with hysteresis | Down: 0.40, Up: 0.55, Cooldown: 0.30s |
| Wrist rotation (flip) | Unwrapped angle change from `AngleSample` buffer within 0.35s window | > 0.60 radians, Cooldown: 1.2s |
| Directional swipe | 5-sample velocity ring buffer, dominance ratio 1.5x | H: 0.010, V: 0.010 |
| Hand depth | Wrist-to-middleMCP Euclidean distance with EMA (alpha 0.10) | Continuous |

**One-Euro Filter Parameters:**
- `OneEuroFilter` -- Single-axis adaptive low-pass filter
- `OneEuroFilter2D` -- Dual-axis wrapper for 2D point smoothing
- Current config: `minCutoff: 0.20`, `beta: 0.015`, `dCutoff: 1.0`
- Tracking gain: 1.05 (centered on 0.5)

**Camera Configuration:**
- Front camera, VGA preset (640x480) for optimal Vision performance
- `automaticallyConfiguresApplicationAudioSession = false`
- No video mirroring (coordinate flip handled in `processHand`)
- Tracks `UIWindowScene` interface orientation for correct Vision orientation

**Support Types:**
- `FrameDelegate` -- `AVCaptureVideoDataOutputSampleBufferDelegate` bridge
- `AngleSample` -- Timestamped wrist angle sample for rotation detection
- `OneEuroFilter` / `OneEuroFilter2D` -- Adaptive low-pass filters

**Pipeline:**
1. AVFoundation captures front-camera frames at VGA resolution
2. Vision framework processes `VNDetectHandPoseRequest` (max 1 hand)
3. Landmarks extracted: indexTip, thumbTip, wrist, middleMCP (confidence > 0.15)
4. Coordinate mapping with orientation-dependent X flip + tracking gain
5. Index finger position passed through `OneEuroFilter2D` + clamped to [0,1]
6. Pinch, flip, swipe, and depth evaluated per frame
7. State dispatched to main thread for `GestureCursorOverlay` consumption
8. Hand loss: 10 consecutive empty frames triggers full state reset

---

## GestureCursorOverlay

**File:** `Views/Main/TrackerHomeView.swift`

Separate `View` struct within `TrackerHomeView` that renders the gesture cursor
and performs hit-testing against reported UI element frames. Extracted as its own
struct to isolate high-frequency state updates from the rest of the view hierarchy.

**Cursor Rendering (3 states):**
- **Idle (tracking)**: 24pt outer ring (cipher, 1.2pt stroke) + 4pt inner dot (cipher) + crosshair lines (0.08 opacity)
- **Hover**: 30pt outer ring (arcane) + 4pt inner dot + 18pt crosshair lines
- **Finger down (pinch)**: 14pt outer ring (jade, 2pt stroke) + 6pt inner dot (jade) + no crosshair
- **Click ripple**: 44pt -> 66pt expanding circle (jade, 0.6 opacity -> 0), 0.35s easeOut

**Hit-Testing:**
- `TappableFramesKey` frames: exact bounding box match, then 25pt proximity fallback
- `SliderFramesKey` frames: 150pt horizontal + 45pt vertical proximity for slider drag
- `CopyButtonFrameKey` frame: triggers glow effect on hover
- Smallest matching element wins (by area) for overlapping frames
- Context-aware filtering: calendar cells hidden when flipped to timesheet, and vice versa

**Interaction Modes:**
- **Calendar mode**: Pinch-down freezes cursor, release dispatches action on locked target
- **Timesheet mode (slider)**: Pinch-down starts slider drag, finger movement adjusts time
- **Timesheet mode (list)**: Pinch-down anywhere else initiates drag-to-scroll

**State:**
- `frozenCursorPosition` -- Locks cursor position on pinch-down in calendar mode
- `activeDraggingSlider` -- Currently dragged slider frame info
- `isDraggingList` / `dragListStartY` / `dragListStartScrollIndex` -- Drag-scroll state
- `lockedHoveredElementID` / `lockedGestureHoveredDate` -- Pinch-down target lock to prevent release drift

---

## TrackerHomeView

**File:** `Views/Main/TrackerHomeView.swift`

Root composition view with asymmetric 2-panel layout.

**Left Panel (45% width, max 490pt):**
- Top bar: Flip button + Export button + Mic toggle + Camera toggle + Status pill
- Body: GlitchFlipContainer (Calendar / Timesheet)

**Right Panel (remaining width):**
- Title bar: Traffic lights (crimson, ember, jade) + "HC://DRAGON-TERMINAL v3.1" + LIVE indicator
- Status bar: SYS | SESS | HRS | UP (live uptime counter)
- Body: Scrollable terminal with ASCII dragon header
- Voice status: Current voice engine state + transcript
- Voice logs: Rolling assistant log entries
- Prompt: `root@hc:~$` with blinking cursor (0.45s interval)

**Terminal Content:**
1. Dragon ASCII art header (24-line blueprint with per-row `DragonArtRenderer` coloring)
2. System boot messages (5 modules: Calendar engine, Haptic subsystem, Clipboard bridge, Pencil input, Glitch renderer)
3. Voice assistant status line + live transcript (supernova color)
4. Voice assistant rolling logs (jade for [OK], crimson for [ERR], steel for [SYS])
5. Work Session Report section (box-drawn borders)
6. Per-session entries with [WD]/[WE] tags and zero-padded indices
7. Total hours summary
8. Blinking cursor prompt (`root@hc:~$`)

**Internal Types:**
- `TLine` -- Terminal line model (content + type)
- `TLineType` -- Line category enum for styling

**Managed Objects:**
- `@StateObject voiceCommandManager` -- Voice assistant lifecycle
- `HandGestureManager` reference -- Gesture input state

**Overlays:**
- `GestureCursorOverlay` -- Gesture cursor + hit-testing layer

**Timers:**
- Cursor blink: 0.45s interval
- Uptime counter: 1s interval
