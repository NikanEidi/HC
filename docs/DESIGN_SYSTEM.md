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

The `GlassmorphismBG` view renders 5 composited layers:

| Layer | Name | Description |
|-------|------|-------------|
| L0 | Abyss | Solid `Forge.abyss` fill |
| L1 | Grid | Perspective grid (28 vertical + 18 horizontal lines) |
| L2 | Aurora | 3 breathing color orbs (arcane, cipher, ember) |
| L3 | Dragon | Classic ASCII art dragon watermark |
| L4 | Scanlines | CRT phosphor lines + sweeping beam |
| L5 | Vignette | Radial gradient darkening edges |

**Animation Timings:**
- Aurora orbs: 6-second breathe cycle (easeInOut, autoreverses)
- Scan beam: 10-second linear sweep (no autoreverse)

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

### Animations
- Selection scale: 1.03x with spring (0.22s response, 0.7 damping)
- Toast appear: spring (0.3s response, 0.7 damping)
- Toast dismiss: easeOut after 2s delay
- Terminal scroll: easeOut (0.25s)
- Cursor blink: 0.45s interval toggle
