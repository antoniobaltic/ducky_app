# Flüsse & Seen — CLAUDE.md

## Overview

**Flüsse & Seen** is an iOS app for discovering Austrian bathing waters (lakes, rivers). It uses a composite **SwimScore** (0–10) combining weather, water temperature, and water quality to answer: "Should I swim today?" A rubber duck mascot ("Ducky") provides personality. The app is entirely in German (Austrian dialect).

**Data sources:**
- **AGES** — water quality, temperature, bacteria levels. API: `https://www.ages.at/typo3temp/badegewaesser_db.json`
- **Open-Meteo** — current weather (air temp, UV, feels-like, wind, precipitation). Free, no API key needed.

**Target:** iOS (with macOS compatibility guards in `PlatformModifiers.swift`)

---

## Project Structure

```
fluesseundseen/
├── fluesseundseenApp.swift          # @main, SwiftData container
├── ContentView.swift                # Tab bar, onboarding gate, environment injection
├── Models/
│   ├── BathingWater.swift           # Core data model, JSON decoding, displayName, swimScore()
│   ├── DuckState.swift              # Duck mood enum: begeistert/zufrieden/zoegernd/frierend/warnend
│   ├── FavouriteItem.swift          # SwiftData @Model for favourites
│   ├── LakeWikipediaContent.swift   # Wikipedia summary model
│   ├── Season.swift                 # Season enum, measurement freshness, seasonal theming
│   └── SwimScore.swift              # Composite score (0-10): weather, water temp, quality
├── Services/
│   ├── DataService.swift            # Singleton, AGES API fetch, disk cache, lake list lifecycle
│   ├── LakeContentService.swift     # Wikipedia fetch, confident match, disk cache (30-day TTL)
│   ├── LakePlaceService.swift       # Apple Maps MKMapItem lookup
│   ├── LocationService.swift        # Singleton, CLLocationManager wrapper
│   └── WeatherService.swift         # Singleton, Open-Meteo API, WMO code mapping, disk cache v3
├── Views/
│   ├── HomeView.swift               # Main discover tab: hero, search, sort/filter, lake list, ranking
│   ├── LakeDetailView.swift         # Detail page: hero, conditions, wikipedia, maps, score breakdown, health, weather
│   ├── MapView.swift                # Full-screen map with score pins, bottom sheet
│   ├── FavouritesView.swift         # Favourites tab with SwiftData
│   ├── OnboardingView.swift         # 3-page onboarding
│   ├── SettingsView.swift           # Appearance mode (system/light/dark), info
│   ├── ShareCardView.swift          # Shareable card with duck + stats
│   ├── PlatformModifiers.swift      # Cross-platform navigation bar helpers
│   └── Components/
│       ├── AppTheme.swift           # Design system: colors, fonts, radii, haptics, score colors, RecentLake
│       ├── DuckView.swift           # Animated rubber duck (SwiftUI shapes)
│       ├── LakeCard.swift           # Horizontal scroll card + LakeListRow (uses SwimScoreBadge)
│       ├── QualityBadge.swift       # Quality indicator pill + TrafficLightRow
│       ├── ScoreBreakdownView.swift # Score breakdown rows (weather, water, quality, bacteria)
│       ├── SwimScoreBadge.swift     # Score badge (small/medium/large/hero) + ScorePinView
│       ├── SeasonalEffects.swift    # Snowfall, falling leaves, spring blossoms
│       └── WaterEffects.swift       # WaveShape, WaterWaveView, FloatingBubbles, Ripple
```

---

## Architecture & Patterns

- **@Observable** (Observation framework) for services; all are singletons (`static let shared`)
- **SwiftData** for persistence: `FavouriteItem` is an `@Model`
- **@AppStorage** for simple prefs: `hasCompletedOnboarding`, `appearanceMode`
- **@Environment** injection: services injected via `.environment()` in ContentView

### Startup Invariants

- `HomeView` must call `WeatherService.bootstrapWeather(for:)` on launch.
- If full weather coverage is missing, the app shows a blocking loading overlay with progress + retry.
- Do not remove this invariant without an equivalent correctness guarantee.
- `DataService` caches AGES payload in caches directory; `WeatherService` caches in `weather_cache_v3.json`.

---

## Design System (AppTheme)

### Core Colors
| Name | Usage |
|------|-------|
| `oceanBlue` | Primary accent, buttons, links |
| `skyBlue` | Secondary blue, water |
| `teal` | Apple Maps, teal accents |
| `coral` | Warnings, hot temps |
| `sunshine` | Duck accent, UV |
| `freshGreen` | Quality excellent, health |
| `airTempGreen` | Air temperature (green, dark) |
| `lavender` | Feels-like, secondary stats |
| `warmPink` | Favourites |

### Score Colors
`AppTheme.scoreColor(for: level)` and `AppTheme.detailHeroGradient(for: level, isDark:)`

| Level | Range | Color |
|-------|-------|-------|
| `.perfekt` | 8–10 | Vibrant green |
| `.gut` | 6–7.9 | Teal/cyan |
| `.mittel` | 4–5.9 | Amber |
| `.schlecht` | 2–3.9 | Orange |
| `.warnung` | 0–1.9 | Red |

### Layout
- `cardRadius`: 20pt — `buttonRadius`: 16pt — `badgeRadius`: 12pt
- `springAnimation`, `gentleSpring`, `quickSpring` for transitions
- `.appCard()` modifier for all card containers

---

## Key Concepts

### SwimScore (Core Metric)

**Weights:**
- With current water temp: **weather 70%**, water temp **30%**
- Without current water temp (off-season/unknown): **weather 100%**

**Quality is deduction-only** (never boosts base score):
- Ausgezeichnet (A): `0.0` | Gut (G): `-0.4` | Ausreichend (AU): `-1.8` | Unknown: `0.0`

**Bacteria deduction** (from live E.Coli / Enterokokken values, capped at `-2.8`):
- E.Coli >500: `-0.5`, >1000: `-1.4`
- Enterokokken >200: `-0.5`, >400: `-1.4`

**Forced overrides:**
- `isClosed` → total `1.0` (`.warnung`)
- `mangelhaft` quality → total `1.5` (`.warnung`)

**Final score clamped** to `0.0...10.0` (min is 0.0, not 1.0).

### DuckState → SwimScore mapping

| DuckState | Score Level | Score Range | Emotional state |
|-----------|-------------|-------------|-----------------|
| `begeistert` | `.perfekt` | 8.0–10.0 | Euphoric, diving in |
| `zufrieden` | `.gut` | 6.0–7.9 | Content, approving |
| `zoegernd` | `.mittel` | 4.0–5.9 | Skeptical, hesitant |
| `frierend` | `.schlecht` | 2.0–3.9 | Cold, goosebumps |
| `warnend` | `.warnung` | 0.0–1.9 or forced | Warning, refusing |

### Temperature Freshness
- `currentWaterTemperature` returns `nil` outside current summer season → UI shows "Unbekannt"
- When nil: score uses weather-only (100%), label changes to "Wetter-Score"
- Hero footnote: `(Messungen: Juni bis August)` when water temp is unavailable

### Lake Naming
- `displayName` removes trailing `, <place>` when `<place>` matches municipality
- Raw `name` stays unchanged for API/service lookups

---

## UX Baseline (2026-02-27)

### Home (HomeView.swift)
- Header label: `Gewässer`
- `Top 5 in deiner Nähe` section shown only with location permission
- Sort options (all bi-directional): `Bester Score`, `Entfernung`, `A–Z`, `Lufttemperatur`, `Wassertemperatur`
- Search overlay filters by Bundesland only
- Removed filters must stay removed: quality filters, score preset filters
- Air-temp iconography uses `wind` symbol throughout
- Stat cards: `Gewässer`, `Guter Score`, `Top Qualität` — centered

### Map (MapView.swift)
- Bottom card: compact score badge, lake name, chips for air/water/distance, `Details` + `Route` actions
- No score verdict text in compact card
- Air-temp chip uses `wind` icon + `AppTheme.airTempGreen`

### Lake Detail (LakeDetailView.swift)
- Hero gradient and background are **score-level driven** (not duck-state seasonal)
- Hero headline: `Perfekte/Gute/Mittelmäßige/Schlechte/Kritische Badebedingungen`
- Hero quote: score-level dependent, 3 variants per level, randomly selected
- **Auf einen Blick** card: weather condition chip (WMO-driven color/icon), air chip (`wind` + `airTempGreen`), water chip (blue), distance chip (teal)
- **Apple Maps** card: merged Standort + Route; Apple Maps info at top, map below, route button at bottom
- **Wikipedia** card: "Browser" button in header only; no badges or bottom row
- **Score breakdown**: always expanded; weather row uses `wind` icon + `airTempGreen`
- **Gesundheit card** (merged): replaces separate Wasserqualität, Bakteriologie, and Sichttiefe cards. Header: `heart.text.clipboard.fill` (freshGreen) + "Gesundheit" + quality badge. Sections: Wasserqualität row, Bakteriologie rows (E.coli + Enterokokken), optional Sichttiefe row. Footer: measurement date + AGES attribution.
- **Wetter vor Ort card**: left icon is `sun.max.fill`; no icon on the right; condition shown as a `quickConditionChip` pill (same style as "Auf einen Blick") below the header; no plain-text condition at the bottom
- Decorative overlays must be `.allowsHitTesting(false)`
- Notifications feature is removed — do not reintroduce

### Scoring (SwimScore.swift)
See "SwimScore" section above for current weights and deductions.

---

## Development Workflow

- **Open project**: `fluesseundseen.xcodeproj`
- **Build**: Xcode or `xcodebuild -project fluesseundseen.xcodeproj -scheme fluesseundseen build`
- **No external dependencies** — all native frameworks, no API keys

### Change Safety Checklist
- Touching scoring → inspect `SwimScore` and `BathingWater.swimScore(weather:)`
- Touching season logic → inspect `Season.isMeasurementOutdated`
- Touching startup → validate cold, warm, stale-cache, and offline launch flows
- Touching HomeView behavior → verify sorting/filtering/search + pagination
