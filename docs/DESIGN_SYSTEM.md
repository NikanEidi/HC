# Forge Design System

## Philosophy

The **Midnight Forge** design system is built around three principles:

1. **Depth through darkness** -- The obsidian void creates perceived depth
2. **Color as signal** -- Every color has a specific semantic meaning
3. **Motion as feedback** -- Animations confirm user actions

---

## Color Palette

### Foundations

| Token | Hex | RGB | Usage |
|-------|-----|-----|-------|
| `obsidian` | `#07070E` | 7, 7, 14 | Card fills, elevated surfaces |
| `abyss` | `#05050B` | 5, 5, 11 | Root canvas, deepest layer |
| `phantom` | `#130E2E` | 19, 14, 46 | Deep indigo accent layer |

### Primary Accents

| Token | Hex | RGB | Usage |
|-------|-----|-----|-------|
| `arcane` | `#8B3CFC` | 139, 60, 252 | Brand primary, weekday selections |
| `cipher` | `#06B6D4` | 6, 182, 212 | Interactive elements, totals, today |
| `supernova` | `#A855F7` | 168, 85, 247 | Lighter purple highlights |

### Signal Colors

| Token | Hex | RGB | Usage |
|-------|-----|-----|-------|
| `ember` | `#F59E0B` | 245, 158, 11 | Weekend markers, warnings |
| `crimson` | `#EF4444` | 239, 68, 68 | Weekend borders, destructive |

### Terminal & Success

| Token | Hex | RGB | Usage |
|-------|-----|-----|-------|
| `jade` | `#10B981` | 16, 185, 129 | Terminal output, success states |
| `mint` | `#34D399` | 52, 211, 153 | Light green secondary accent |

### Neutrals

| Token | Hex | RGB | Usage |
|-------|-----|-----|-------|
| `frost` | `#E2E8F0` | 226, 232, 240 | Primary text (cool white) |
| `steel` | `#64748B` | 100, 116, 139 | Secondary text, labels |
| `ash` | `#414C5E` | 65, 76, 94 | Tertiary, tick marks |

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

## Dragon Art (v3.0)

The ASCII dragon has been upgraded to an **ultra-detailed 30-row blueprint**
rendered by the `DragonArtRenderer`. Each character is individually classified
and colored, producing a multi-chromatic dragon with animated effects.

### Character-Class Color Mapping

| Character | Class | Forge Color | Effect |
|-----------|-------|-------------|--------|
| `#` | Body | arcane | Gradient fill |
| `*` | Sparkle | frost / cipher | Animated pulse |
| `~` | Flame | ember / crimson | Breathing glow |
| `^` | Horn | supernova | Static accent |
| `o` | Eye | crimson | Glow halo |
| `/` `\` | Wing edge | cipher | Directional shade |
| `(` `)` | Contour | steel | Structural |
| `V` | Teeth/claw | frost | Bright accent |
| `=` | Scale | jade | Pattern fill |
| `-` | Outline | ash | Dim structural |
| `_` | Base | phantom | Ground shadow |
| `.` | Dot | steel (dim) | Texture detail |
| `+` | Joint | mint | Connection point |
| `v` | Tail | arcane (dim) | Gradient trail |
| ` ` | Space | -- | Transparent |

### Animated Effects
- **Flame breath**: Characters classified as `~` pulse between ember and
  crimson with an opacity cycle driven by the animation phase parameter
- **Sparkle particles**: Characters classified as `*` have randomized
  phase offsets creating a twinkling effect across the dragon body
- **Phase parameter**: A single `CGFloat` phase value (0 to 1) drives
  all animated character effects with per-class timing offsets

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
- **Medium**: Flip button, slider drag end
- **Light (0.3 intensity)**: Each slider snap increment
- **Success notification**: Clipboard copy

### Hover Effects (Apple Pencil)
- `.hoverEffect(.lift)`: All buttons (flip, export, copy, nav arrows)
- `.hoverEffect(.highlight)`: Calendar day cells
- `onHover`: Calendar cells (manual opacity change)

### Hand Gesture Feedback
- Cursor appears when hand enters camera frame
- Hover glow on UI elements when cursor overlaps their frame
- Click ripple animation on pinch gesture
- Cursor fades when hand tracking is lost

### Animations
- Selection scale: 1.03x with spring (0.22s response, 0.7 damping)
- Toast appear: spring (0.3s response, 0.7 damping)
- Toast dismiss: easeOut after 2s delay
- Terminal scroll: easeOut (0.25s)
- Cursor blink: 0.45s interval toggle
- Gesture cursor ripple: easeOut (0.35s)
