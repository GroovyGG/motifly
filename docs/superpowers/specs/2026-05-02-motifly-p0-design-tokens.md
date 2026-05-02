# Motifly P0 Design Tokens

**Scope:** UI tokens only (no navigation / IA changes). **Workflow:** evolve Figma Variables alongside [`MotiflyTokens`](../../../ios/Motifly/Design/MotiflyTokens.swift) in Xcode.

**Related code:** [`MotiflyTokens.swift`](../../../ios/Motifly/Design/MotiflyTokens.swift), [`MotiflyCardStyle.swift`](../../../ios/Motifly/Design/MotiflyCardStyle.swift).

### Typography (Josefin Sans)

- **Bundle:** [`JosefinSans-Variable.ttf`](../../../ios/Motifly/Fonts/JosefinSans-Variable.ttf) (Google Fonts, OFL — see [`OFL-JosefinSans.txt`](../../../ios/Motifly/Fonts/OFL-JosefinSans.txt)).
- **Registration:** [`Info.plist`](../../../ios/Motifly/Info.plist) key `UIAppFonts` → `JosefinSans-Variable.ttf` (file is copied to the app bundle root).
- **Swift:** `MotiflyTokens.Typeface.familyName` is `"Josefin Sans"`. Use `MotiflyTokens.TypeStyle.font(_:weight:)` or the presets (`body`, `sectionTitle`, etc.). The app root applies `TypeStyle.body` in [`MotiflyApp.swift`](../../../ios/Motifly/MotiflyApp.swift).

---

## Figma collections (P0)

Use **four collections** with **Light / Dark modes** for color (and any color-dependent surfaces).

### `Motifly / Color`

| Figma variable | Role |
|----------------|------|
| `color/background/screen` | Full-screen grouped background |
| `color/surface/card` | Card fill (secondary grouped) |
| `color/surface/elevated` | Warm memory / emphasis blocks (light); secondary grouped (dark) |
| `color/accent/primary` | Primary accent (tint, icons, progress) |
| `color/text/primary` | Primary label |
| `color/text/secondary` | Secondary label |
| `color/text/tertiary` | Tertiary label |
| `color/screen/dictation-tint` | Light mode only: dictation tab screen tint (see Swift mapping) |
| `color/lemma/verb` | Verb lemma highlight (light + dark greens) |

Optional later: `color/border/subtle`, `color/separator`.

### `Motifly / Space`

| Figma variable | pt |
|----------------|-----|
| `space/xs` | 4 |
| `space/sm` | 8 |
| `space/md` | 12 |
| `space/lg` | 14 |
| `space/xl` | 16 |
| `space/2xl` | 20 |
| `space/section-bottom` | 32 |

### `Motifly / Radius`

| Figma variable | pt |
|----------------|-----|
| `radius/sm` | 12 |
| `radius/md` | 14 |
| `radius/lg` | 16 |
| `radius/pill` | 18 |
| `radius/dictation-header` | 20 |

### `Motifly / Type`

Use **text styles** named to match roles (not every pt as a variable). Prefer Dynamic Type–friendly scales.

| Style name | Notes |
|------------|--------|
| `type/screen-title` | Tab / screen titles |
| `type/section-title` | Card section headers |
| `type/stat-value` | Large numbers on Home |
| `type/body` | Body / callout |
| `type/row-primary` | List primary line |
| `type/caption` | Captions and legends |

---

## Swift mapping (authoritative for shipped app)

| Figma path | Swift API |
|------------|-----------|
| `color/background/screen` | `MotiflyTokens.Colors.screenBackground` |
| `color/surface/card` | `MotiflyTokens.Colors.cardSurface` |
| `color/surface/elevated` | `MotiflyTokens.Colors.surfaceElevated(for:)` |
| `color/accent/primary` | `MotiflyTokens.Colors.accentPrimary` |
| `color/text/primary` | `MotiflyTokens.Colors.textPrimary` |
| `color/text/secondary` | `MotiflyTokens.Colors.textSecondary` |
| `color/text/tertiary` | `MotiflyTokens.Colors.textTertiary` |
| `color/screen/dictation-tint` | `MotiflyTokens.Colors.dictationScreenBackground(_:)` (dark uses grouped background) |
| `color/lemma/verb` | `MotiflyTokens.Colors.lemmaVerb(for:)` |
| `space/*` | `MotiflyTokens.Space.*` |
| `radius/*` | `MotiflyTokens.Radius.*` |
| `type/*` | `MotiflyTokens.TypeStyle.*` (Josefin Sans via `TypeStyle.font`) |
| `typeface/family` | `MotiflyTokens.Typeface.familyName` |
| Standard card chrome | `View.motiflyCardStyle()` |

---

## Incremental rollout

1. Add or adjust tokens in `MotiflyTokens`.
2. Replace hard-coded values in views.
3. Update Figma Variables to match (Figma follows code for this repo unless a deliberate visual change).

## Out of scope (P0)

- Noun lemma gender colors remain in [`NounWordCardView`](../../../ios/Motifly/Views/NounWordCardView.swift) until a follow-up adds `color/lemma/noun-m` / `noun-f` to tokens.
- No automated Figma → Swift export.
