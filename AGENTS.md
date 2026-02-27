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

## Current UX Baseline (2026-02-26)

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

### Map (`Views/MapView.swift`)
- Tapped-lake bottom card is intentionally minimal:
  - compact score badge
  - lake name + municipality/state
  - chips for air/water/distance
  - actions: `Details`, `Route`
- Do not reintroduce score verdict text (e.g. `Mittelmäßig`) in this compact card.
- If values are missing, use robust placeholders (`Luft –`, `Wasser –`) instead of collapsing layout.

### Lake Detail (`Views/LakeDetailView.swift`)
- Hero area in dark mode uses dedicated darker text colors for readability over bright seasonal backgrounds.
- `Auf einen Blick` card is present and should stay concise and readable.

### Favorites (`Views/FavouritesView.swift`)
- Favorites rows prioritize score and temperatures.
- Water quality should not be a dominant UI element; keep it secondary/minimal.

### Settings / Features
- Notification feature is currently removed/de-scoped and should not be reintroduced accidentally in UI flows.
