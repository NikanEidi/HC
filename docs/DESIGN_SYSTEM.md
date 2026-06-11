# Forge Design System

## Philosophy

The **Midnight Forge** design system is built around three principles:

1. **Depth through darkness** -- The obsidian void creates perceived depth
2. **Color as signal** -- Every color has a specific semantic meaning
3. **Motion as feedback** -- Animations confirm user actions

---

## Color Palette

### Foundations (Deeper, Richer Cosmic Space Void)

| Token | Hex | RGB | Usage |
|-------|-----|-----|-------|
| `obsidian` | `#020204` | 2, 2, 4 | Card fills, elevated surfaces |
| `abyss` | `#010102` | 1, 1, 2 | Root canvas, deepest layer |
| `phantom` | `#040308` | 4, 3, 8 | Deep indigo accent layer |

### Primary Accents (Ultra-Vibrant Glowing Cyberpunk)

| Token | Hex | RGB | Usage |
|-------|-----|-----|-------|
| `arcane` | `#8426FF` | 133, 38, 255 | Electric Violet -- brand primary, weekday selections |
| `cipher` | `#00D8F2` | 0, 217, 242 | Hyper-Neon Cyan -- interactive elements, totals, today |
| `supernova` | `#FF26A6` | 255, 38, 166 | Vivid Neon Magenta -- highlights, dragon horns |

### Signal Colors (Glowing Burning Fire)

| Token | Hex | RGB | Usage |
|-------|-----|-----|-------|
| `ember` | `#FF7300` | 255, 115, 0 | Vivid Safety Orange -- weekend markers, warnings |
| `crimson` | `#FF263F` | 255, 38, 63 | Glowing Crimson Red -- weekend borders, destructive |

### Terminal & Success (Acid Jade/Mint)

| Token | Hex | RGB | Usage |
|-------|-----|-----|-------|
| `jade` | `#00F273` | 0, 242, 115 | Electric Jade -- terminal output, success states |
| `mint` | `#1AFFA6` | 26, 255, 166 | Glowing Neon Mint -- light green secondary accent |

### Neutrals (Premium Metallic Steel)

| Token | Hex | RGB | Usage |
|-------|-----|-----|-------|
| `frost` | `#F0F5FC` | 240, 245, 252 | Luminous Ice -- primary text |
| `steel` | `#7A8AA3` | 122, 138, 163 | Chrome Steel -- secondary text, labels |
| `ash` | `#333D4D` | 51, 61, 77 | Dark Charcoal -- tertiary, tick marks |

---

## GlassCard Modifier

The `.glassCard()` modifier creates a frosted glass surface:

```swift
.glassCard(radius: 22, border: 0.08, glow: Forge.arcane)
```

**Parameters:**
- `radius` -- Corner radius (default: 22pt)
- `border` -- Border gradient max opacity (default: 0.08)
- `glow` -- Outer shadow color (default: Forge.arcane)

**Layer Stack:**
1. `Forge.obsidian` at 85% opacity (solid base)
2. `.ultraThinMaterial` at 6% opacity (frosted glass)
3. Gradient stroke border (white, fading top-left to bottom-right)
4. Clip shape (continuous rounded rectangle)
5. Two shadows: colored glow + black depth

---

## Background Composition

The `GlassmorphismBG` view renders 6 composited layers:

| Layer | Name | Description |
|-------|------|-------------|
| L0 | Abyss | Solid `Forge.abyss` fill |
| L1 | Grid | Perspective grid (28 vertical + 18 horizontal lines) |
| L2 | Aurora | 3 breathing color orbs (arcane, cipher, ember) |
| L3 | Dragon | Ultra-detailed 30-row ASCII dragon blueprint via `DragonArtRenderer` |
| L4 | Scanlines | CRT phosphor lines + sweeping beam |
| L5 | Vignette | Radial gradient darkening edges |

**Animation Timings:**
- Aurora orbs: 6-second breathe cycle (easeInOut, autoreverses)
- Scan beam: 10-second linear sweep (no autoreverse)

---

## Dragon Art (v3.0+)

The ASCII dragon has been upgraded to an **ultra-detailed 30-row blueprint**
rendered by the `DragonArtRenderer`. Each character is individually classified
and colored, producing a multi-chromatic dragon with animated effects.

### Character-Class Color Mapping

| Character | Class | Forge Color | Effect |
|-----------|-------|-------------|--------|
| `#` | Body scales | Cipher -> Jade -> Arcane -> Supernova -> Ember | Vertical position-based gradient |
| `O`, `:` | Eyes (rows 5-6) | Crimson -> Supernova | Animated pulse |
| `>`, `<` | Flame breath | Ember -> Crimson | Animated glow (0.8x pulse) |
| `{`, `}` | Flame brackets | Supernova -> Ember | Animated pulse |
| `*` | Sparkle particles | Mint -> Cipher | Animated pulse |
| `=` | Wing membrane (rows 7-11) / Ridges | Cipher -> Arcane / Supernova | Animated shimmer (0.6x) |
| `~` | Crown (rows 0-2) / Ridges | Supernova / Arcane -> Cipher | Animated (0.5x pulse) |
| `^` | Wing tips (rows 0-4) / Other | Jade / Jade -> Mint | Animated (0.6x pulse) |
| `/`, `\` | Wing edges | Arcane | 70% opacity |
| `(`, `)` | Structural curves | Cipher | 75% opacity |
| `V` | Talons (row >= 23) / Wing core (rows 6-7) | Supernova / Ember -> Supernova | Static / Animated |
| `v` | Tail feathers (row >= 23) | Steel -> Supernova | 40% blend |
| `Y` | Tail tip | Supernova | Static |
| `-`, `_` | Border strokes | Steel | 45% opacity |
| `.`, `,` | Dots | Mint | 50% opacity |
| `` ` `` | Feathers | Steel | 35% opacity |
| `\|` | Pipe separators | Steel | 50% opacity |
| `'` | Apostrophe | Cipher | 40% opacity |
| ` ` | Space | Steel | 8% opacity |

### Animated Effects
- **Flame breath**: `>`, `<` pulse between Ember and Crimson driven by `pulse * 0.8`
- **Eyes**: `O`, `:` on rows 5-6 interpolate between Crimson and Supernova
- **Sparkle particles**: `*` characters interpolate between Mint and Cipher
- **Wing membrane shimmer**: `=` on rows 7-11 interpolates Cipher -> Arcane at `pulse * 0.6`
- **Body gradient**: `#` uses row position ratio to create a full-body
  vertical gradient from cool (Cipher/Jade) at the top to warm (Supernova/Ember) at the bottom
- **Phase parameter**: A single `CGFloat` pulse value (0 to 1) with
  `easeInOut` 2.8s cycle drives all animated effects with per-class timing multipliers

---

## Gesture Cursor Design

The gesture cursor rendered by `GestureCursorOverlay` follows the
Forge design system's cyberpunk aesthetic:

### Cursor Components

| Element | Size | Style |
|---------|------|-------|
| Outer ring | 36pt diameter | Forge.cipher stroke, 2pt width |
| Inner dot | 8pt diameter | Forge.frost filled circle |
| Crosshair H | Full width | Forge.cipher at 15% opacity, 0.5pt |
| Crosshair V | Full height | Forge.cipher at 15% opacity, 0.5pt |

### Cursor States

| State | Visual |
|-------|--------|
| Tracking (idle) | Outer ring + inner dot, steady |
| Hover | Outer ring brightens, target element glows |
| Click (pinch) | Expanding ripple circle (cipher, fading out) |
| Lost tracking | Cursor fades out (0.3s easeOut) |

### Click Ripple Animation
- Trigger: Pinch gesture detected
- Start: 36pt diameter, cipher at 60% opacity
- End: 72pt diameter, cipher at 0% opacity
- Duration: 0.35 seconds, easeOut curve

---

## Voice Assistant UX

The voice command engine follows the Forge design system for its
terminal output, haptic feedback, and conversational personality.

### Terminal Integration

Voice assistant state is rendered in the ANSI terminal panel:

| Element | Format | Color |
|---------|--------|-------|
| Status line | `Voice: ACTIVE \| Transcript: "..."` | Forge.cipher (status), Forge.frost (transcript) |
| System logs | `[SYS] Voice Engine: ACTIVE. Parsing command stream...` | Forge.jade |
| Error logs | `[ERR] Directive unrecognized: "..."` | Forge.crimson |
| Vision speech | `[SYS] Vision: "I have selected the 5th for you."` | Forge.cipher |
| NLP debug | `[NLP] Extracted: 2026-06-05` | Forge.steel |

### Voice Personality

The assistant speaks with a cyberpunk operator personality:
- Addresses the user as "Nik"
- Uses military/tech jargon: "optical matrix online", "ghost-click applied", "shifting calendar matrix"
- Contextual responses: single-date vs multi-date, success vs failure
- Error messages are throttled (8s cooldown) and varied (6 random phrases)

### Haptic Feedback for Voice

| Event | Haptic Type |
|-------|-------------|
| Wake word detected | Medium impact |
| Command executed successfully | Success notification |
| Command failed to parse | Error notification |
| Date toggled via voice | Rigid impact |
| View switched via voice | Rigid impact |
| Month navigated via voice | Rigid impact |

---

## Typography

All text uses the system monospaced font at various weights:

| Context | Size | Weight | Tracking |
|---------|------|--------|----------|
| Month header | 15pt | .black | 5 |
| Weekday headers | 9pt | .black | 1.8 |
| Day numbers | 16pt | .medium/.black | -- |
| Button labels | 11pt | .black | 2 |
| Terminal body | 12pt | .regular/.bold | -- |
| Status tags | 8-9pt | .bold | 1 |
| Slider labels | 10pt | .heavy | 2.5 |
| Slider readout | 22pt | .black | -- |
| Total hours | 28pt | .black | -- |

---

## Spacing System

| Context | Value |
|---------|-------|
| Root horizontal padding | 40pt |
| Root vertical padding | 32pt |
| Panel gap | 30pt |
| Card internal horizontal | 24pt |
| Card internal vertical top | 24pt |
| Grid cell height | 54pt |
| Grid cell spacing | 7pt |
| Session row padding | 20pt |
| Session row gap | 14pt |
| Slider vertical gap | 8pt |

---

## Interaction Patterns

### Haptic Feedback
- **Light**: Calendar date tap, navigation arrows
- **Medium**: Flip button, slider drag end, wake word detected
- **Light (0.3 intensity)**: Each slider snap increment
- **Rigid**: Voice-triggered date toggle, month navigation, view switch
- **Success notification**: Clipboard copy, successful voice command
- **Error notification**: Failed voice command parse

### Hover Effects (Apple Pencil)
- `.hoverEffect(.lift)`: All buttons (flip, export, copy, nav arrows, mic, camera)
- `.hoverEffect(.highlight)`: Calendar day cells
- `onHover`: Calendar cells (manual opacity change)

### Hand Gesture Feedback
- Cursor appears when hand enters camera frame
- Hover glow on UI elements when cursor overlaps their frame
- Click ripple animation on pinch gesture
- Cursor fades when hand tracking is lost

### Voice Feedback
- Wake word: medium haptic + "Hey Nik, how can I help you today?"
- Successful command: success haptic + contextual TTS response
- Failed command: error haptic + throttled error phrase
- Session timeout: silent return to STANDBY (no audio)

### Animations
- Selection scale: 1.03x with spring (0.22s response, 0.7 damping)
- Toast appear: spring (0.3s response, 0.7 damping)
- Toast dismiss: easeOut after 2s delay
- Terminal scroll: easeOut (0.25s)
- Cursor blink: 0.45s interval toggle
- Gesture cursor ripple: easeOut (0.35s)
