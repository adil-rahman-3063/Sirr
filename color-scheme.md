# Prayer Times App — Color Scheme

Theme shifts dynamically based on the current prayer period, tied to `DateTime.now()` and the same prayer-window logic used for the countdown/next-prayer feature.

---

## 1. Fajr (Pre-dawn)

| Role | Color | Hex |
|---|---|---|
| Background | Deep indigo/navy | `#1A1B3A` |
| Surface / card | Slightly lighter navy | `#242650` |
| Accent | Soft lavender-pink | `#E8B4BC` |
| Primary text | Off-white | `#F2F0F5` |
| Secondary text | Muted lavender-grey | `#A8A4C0` |

**Mood:** quiet, still — the sky just before sunrise.

---

## 2. Sunrise → Dhuhr (Morning / Midday)

| Role | Color | Hex |
|---|---|---|
| Background | Soft sky blue | `#E8F4F8` |
| Surface / card | White | `#FFFFFF` |
| Accent | Warm gold | `#D4A24C` |
| Primary text | Dark navy | `#1A1B3A` |
| Secondary text | Slate grey | `#5B6470` |

**Mood:** bright, airy, energetic.

---

## 3. Asr (Afternoon)

| Role | Color | Hex |
|---|---|---|
| Background | Warm cream/sand | `#F5E6D3` |
| Surface / card | Lighter sand | `#FBF3E8` |
| Accent | Burnt orange / terracotta | `#C56B3F` |
| Primary text | Deep brown | `#3A2A1E` |
| Secondary text | Muted brown-grey | `#8A7565` |

**Mood:** warm, golden-hour, settling.

---

## 4. Maghrib (Sunset)

| Role | Color | Hex |
|---|---|---|
| Background gradient | Deep orange → purple | `#FF6B4A` → `#4A3B6B` |
| Surface / card | Semi-transparent dark overlay | `#2A1F3DCC` |
| Accent | Warm coral | `#FF9466` |
| Primary text | White | `#FFFFFF` |
| Secondary text | Soft pink-grey | `#D9C4CE` |

**Mood:** the showstopper — vivid, emotional, most visually distinct screen.

---

## 5. Isha (Night)

| Role | Color | Hex |
|---|---|---|
| Background | Deep charcoal/black | `#12121A` |
| Surface / card | Slightly lighter charcoal | `#1C1C26` |
| Accent | Muted teal | `#5FAFA0` |
| Primary text | Soft white | `#E8E8ED` |
| Secondary text | Dim grey | `#75757F` |

**Mood:** minimal brightness, easy on the eyes at night.

---

## Constants (stay the same across all 5 themes)

- **Next-prayer card style** — same shape, elevation, and icon set across every theme so the app still feels like one product.
- **Error / warning color** — `#E05C5C` (works legibly on all 5 backgrounds).
- **Success / "prayer completed" color** — `#5FAF6F`.
- **Icon set** — consistent line-icon style; only the accent color re-tints per theme.

---

## Flutter Implementation Notes

- Define each period as a `ThemeData` (or a lightweight custom `ColorTokens` class) rather than duplicating full themes.
- Determine active period from the same prayer-window calculation already used for the countdown logic — no separate time check needed.
- Wrap the root in `AnimatedTheme` (or `AnimatedContainer` for individual surfaces) so transitions between periods animate smoothly instead of cutting abruptly.
- Consider a manual override toggle for users who want a fixed theme regardless of time (accessibility / personal preference).
