# AGENTS.md

This document is the operational guide for future work in `fluesseundseen`.

## Product Intent

- Build a joyful lake discovery app for Austria.
- Ducky is the mascot and should stay central in UX, copy, and emotional feedback.
- Visual style should be colorful, playful, and intuitive.
- Motion should feel alive: subtle waves, bubbles, spring transitions, and responsive feedback.

## Core User Promise

- Users rely on ranking by `SwimScore`.
- Score quality depends on weather + water + quality data.
- The app must not present score-based ranking as "ready" until weather coverage is complete for all loaded lakes.

## Architecture Overview

### Entry and Navigation
- App entry: `fluesseundseen/fluesseundseenApp.swift`
- Root composition: `fluesseundseen/ContentView.swift`
- Main tabs: `fluesseundseen/Views/HomeView.swift`, `fluesseundseen/Views/MapView.swift`, `fluesseundseen/Views/FavouritesView.swift`.

### Services
- `DataService` loads AGES bathing waters JSON, parses, caches on disk.
- `WeatherService` loads Open-Meteo weather per lake, caches on disk, manages full hydration.
- `LocationService` wraps CoreLocation permission + updates.

### Models
- `BathingWater`: decoded lake model + score helpers.
- `SwimScore`: composite scoring logic and level mapping.
- `Season`: off-season logic and stale-temperature handling.
- `DuckState`: mascot expression/state model.

## Data Sources

- Lake data: `https://www.ages.at/typo3temp/badegewaesser_db.json`
- Weather data: `https://api.open-meteo.com/v1/forecast`

## Caching + Startup Invariants

- `DataService` caches AGES payload in caches directory.
- `WeatherService` caches weather dictionary in `weather_cache_v3.json`.
- Weather cache can be used stale for instant launch ranking, then refreshed in background.
- On startup, `HomeView` must call `WeatherService.bootstrapWeather(for:)`.
- If full weather coverage is missing, the app shows a blocking loading overlay with progress and retry.
- Do not remove this invariant without replacing it with an equivalent correctness guarantee.

## Score Correctness Rules

- `bestScore` sorting should only be trusted when every displayed lake has weather in cache.
- Never silently accept partial weather for global ranking.
- If partial coverage exists, keep blocking/retrying until complete or explicitly communicate degraded mode.

## WeatherService Notes

- `fetchWeather(for:forceRefresh:)` deduplicates in-flight requests.
- `hydrateAllWeather(for:forceRefresh:)` supports full-lake hydration with concurrency control.
- `refreshAllWeatherInBackground(for:)` is used when cache is complete but stale.
- Keep all cache mutations main-actor isolated.
- Avoid introducing parallel dictionary writes outside `@MainActor`.

## UI and Motion Guidelines

- Keep Ducky visible in primary moments: onboarding, hero, loading, score storytelling.
- Prefer optimistic, friendly copy in German (current app language).
- Maintain the existing visual language in `AppTheme`.
- Use existing motion utilities before adding new animation systems.
- `WaterWaveView`, `WaveDivider`, `FloatingBubblesView`, spring animations in `AppTheme`.
- Add motion with restraint. Prefer meaningful state transitions over constant noise.

## Performance Guidelines

- Avoid expensive recomputation inside view body.
- Follow `HomeView.updateDisplayLakes` pattern: derive once, cache in state, debounce frequent triggers.
- Keep weather/network fan-out bounded by concurrency limits.
- Avoid duplicate API calls by using `WeatherService` as the single weather gateway.

## Development Workflow

- Open project: `fluesseundseen.xcodeproj`
- Build with Xcode or `xcodebuild -project fluesseundseen.xcodeproj -scheme fluesseundseen build`.

### Before Shipping
- Build succeeds with no errors.
- Launch flow verifies score-ready behavior.
- Pull-to-refresh and tab switching do not regress responsiveness.
- Dark/light appearance still works.

## Change Safety Checklist

- If touching scoring, inspect `SwimScore` and `BathingWater.swimScore(weather:)`.
- If touching season logic, inspect `Season.isMeasurementOutdated`.
- If touching startup, validate cold launch (no cache).
- If touching startup, validate warm launch (fresh cache).
- If touching startup, validate stale cache launch (background refresh).
- If touching startup, validate offline launch fallback behavior.
- If touching Home list behavior, verify sorting/filtering/search + pagination still work together.

## File Map (Most Touched)

- `fluesseundseen/Views/HomeView.swift`: startup orchestration, list, ranking, hero.
- `fluesseundseen/Services/WeatherService.swift`: weather hydration and cache lifecycle.
- `fluesseundseen/Services/DataService.swift`: AGES ingest and lake list lifecycle.
- `fluesseundseen/Models/SwimScore.swift`: ranking math.
- `fluesseundseen/Views/Components/AppTheme.swift`: design tokens and animation constants.

## Non-Negotiables for Future Work

- Keep the app beautiful, colorful, and emotionally clear.
- Preserve intuitive UX over feature complexity.
- Ducky remains the main personality anchor.
- Keep score/ranking correctness above perceived speed hacks.

## Current UX Baseline (2026-02-27)

- This section reflects the latest product decisions and should be treated as current behavior requirements unless explicitly changed by product direction.

### Home (`Views/HomeView.swift`)
- Main list header label is `Gewässer` (not `Alle Gewässer`).
- Home includes a `Top 5 in deiner Nähe` section (shown only when location permission is granted), ranked by score.
- The wave directly under the hero card and above the search bar was intentionally removed.
- Search bar uses stronger contrast/shadow for readability in light and dark mode.
- The three stat cards (`Gewässer`, `Guter Score`, `Top Qualität`) are centered and should remain visually balanced.
- Winter hero copy is:
  - Title: `Winterpause`
  - Message: `Es ist zu kalt. Ducky friert und ist böse.`
- Long-press hint copy is exactly:
  - `Lange drücken zum Teilen, als Favorit hinzufügen und Route berechnen.`

### Sorting + Filtering (`Views/HomeView.swift`)
- Sort options are:
  - `Bester Score`
  - `Entfernung`
  - `A–Z`
  - `Lufttemperatur`
  - `Wassertemperatur`
- Every sort option is bi-directional; tapping the active option toggles ascending/descending with an arrow indicator.
- Search overlay filters only by Bundesland.
- Removed search filters must stay removed:
  - Quality filters (`Ausgezeichnet`, etc.)
  - Score preset filters (`Perfekt`, `Gut+`, etc.)
- Air-temperature iconography uses a neutral `wind` symbol (not sun/cloud) in sorting and temperature chips.

### Map (`Views/MapView.swift`)
- Tapped-lake bottom card is intentionally minimal:
  - compact score badge
  - lake name + municipality/state
  - chips for air/water/distance
  - actions: `Details`, `Route`
- Do not reintroduce score verdict text (e.g. `Mittelmäßig`) in this compact card.
- If values are missing, use robust placeholders (`Luft –`, `Wasser –`) instead of collapsing layout.
- Air-temperature chip uses `wind` icon and `AppTheme.airTempGreen` (text/icon).

### Lake Detail (`Views/LakeDetailView.swift`)
- Hero area in dark mode uses dedicated darker text colors for readability over bright backgrounds.
- Hero and page background are score-level driven gradients (not duck-state seasonal gradients), and must extend to the very top safe area (status bar / Dynamic Island area included).
- Hero headline below score circle is level text:
  - `Perfekte Badebedingungen`
  - `Gute Badebedingungen`
  - `Mittelmäßige Badebedingungen`
  - `Schlechte Badebedingungen`
  - `Kritische Badebedingungen`
- Hero quote behavior:
  - Quote depends exclusively on score level.
  - Three quote variants exist per score level and are selected randomly.
  - Quote block is centered in the hero (not left-bound).
- `Auf einen Blick` card is present and should stay concise and readable.
- `Auf einen Blick` structure:
  - order is weather condition, air temperature, water temperature, distance
  - no duck icon in this card
  - chip text uses neutral text color; icon and pill tint carry the semantic color
  - weather chip icon/label come from WMO weather mapping and chip color changes by weather condition
  - air chip uses `wind` icon and `AppTheme.airTempGreen`
  - water chip uses blue (`AppTheme.oceanBlue`) for known and unknown states
  - chip copy format is `Luft: {temp}°C` and `Wasser: {temp}°C` / `Wasser: Unbek.`
- The `Außerhalb der Badesaison` card is intentionally removed and should not be reintroduced.
- Hero temperature labels are:
  - `Lufttemp.`
  - `Wassertemp.`
  - measurement note text is exactly `(Messungen: Juni bis August)` when current water temperature is unavailable.
- Apple Maps + Standort + Route are merged into one card:
  - Header/title is `Apple Maps`.
  - Apple Maps metadata block appears at the top when available (Ort/Telefon/Website), with loading and unavailable fallback states.
  - The `Standort` map appears directly below the Apple Maps info in the same card.
  - `Route in Apple Maps` is a single full-width button below the map inside the same card.
  - Removed elements that must stay removed: `Live-Ortskarte`, `Ortsinfos öffnen`, small header `Route` button.
- Wikipedia card behavior:
  - Keep only the top-right `Browser` button in the card header.
  - Keep removed elements removed: `Sicherer Treffer` badge and bottom `Wikipedia` row/button.
- **Gesundheit card** replaces the former separate `Wasserqualität`, `Bakteriologie`, and `Sichttiefe` cards:
  - Header: `heart.text.clipboard.fill` icon (freshGreen) + "Gesundheit" title + quality badge on the right
  - Wasserqualität row: quality icon + label, quality text value on right, subtle quality-color background
  - Bakteriologie section: allergens icon + "Bakteriologie" label, "Details"/"Ausblenden" pill button; E.coli + Enterokokken TrafficLightRows below
  - Sichttiefe row (optional, shown when `lake.visibilityDepth != nil`): eye icon, depth value, visual gradient bar
  - Footer: measurement date on left, "AGES" attribution on right (or full attribution if no date)
  - Card background: `freshGreen.opacity(0.07)` gradient
  - Removed elements that must stay removed: individual Wasserqualität, Bakteriologie, Sichttiefe cards
- **Wetter vor Ort card** reworked:
  - Left header icon is `sun.max.fill` (multicolor) — not `cloud.sun.fill`
  - No icon on the top right (the duplicate `weather.conditionSymbol` icon was removed)
  - Weather condition is shown as a `quickConditionChip` pill (same style as "Auf einen Blick") directly below the header, color driven by `weatherConditionChipStyle(for:)`
  - Bottom plain-text `conditionDescription` is removed (replaced by the pill above)
- Score details card behavior:
  - always expanded (no collapse chevron/toggle)
  - weather row label is `Wetter & Lufttemp. ({weight}%)` with `wind` icon in `AppTheme.airTempGreen`
  - water row label is `Wassertemp. (30%)` with `drop.fill` icon and blue styling when data exists
  - when water is unavailable, row stays grey and message is `Messungen: Juni bis August`
  - quality deduction icon is `checkmark.shield.fill` (match Wasserqualität card)
  - bacteria deduction icon is `allergens` (match Bakteriologie card)
  - all row text is neutral; color is carried by icons and bars
  - do not show explanatory `Basis = ...` helper text
  - formula uses subtractive form (`base − deductions = total`) and may show clamp note.
- Interactive reliability:
  - Decorative overlays (card strokes, glow, shimmer) must remain non-interactive (`.allowsHitTesting(false)`) so buttons keep working in previews and simulator.

### Favorites (`Views/FavouritesView.swift`)
- Favorites rows prioritize score and temperatures.
- Water quality should not be a dominant UI element; keep it secondary/minimal.
- Air-temperature chip uses `wind` icon + `AppTheme.airTempGreen`.

### Scoring (`Models/SwimScore.swift`)
- Current weights:
  - with current water temperature: weather `70%`, water temperature `30%`
  - without current water temperature: weather `100%`
- Quality is deduction-only:
  - `A`: `0.0`
  - `G`: `-0.4`
  - `AU`: `-1.8`
  - unknown: `0.0`
- Bacteria deduction is active (from latest `E.Coli` / `Enterokokken` values):
  - `E.Coli > 500`: `-0.5`, `> 1000`: `-1.4`
  - `Enterokokken > 200`: `-0.5`, `> 400`: `-1.4`
  - combined bacteria deduction capped at `-2.8`
  - missing bacteria values => no bacteria deduction
- Forced overrides remain:
  - `isClosed` => total `1.0` (`warnung`)
  - poor quality (`mangelhaft`) => total `1.5` (`warnung`)
- Final score is clamped to `0.0...10.0` (minimum is `0.0`, not `1.0`).

### Lake Naming (`Models/BathingWater.swift`)
- UI display names use `displayName` cleanup logic:
  - trailing `, <place>` is removed when `<place>` is effectively the same municipality
  - raw `name` remains unchanged for API extraction and service lookups (Apple Maps/AGES integrations must not break).

### Settings / Features
- Notification feature is currently removed/de-scoped and should not be reintroduced accidentally in UI flows.
