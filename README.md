# Ducky

Ducky is a playful Austrian lake discovery app built around one question:

> Where should I swim today?

The app combines official bathing-water data, live weather, seasonal truthfulness, and a mascot-led UI into one clear ranking system called **SwimScore**. Instead of making users compare raw measurements manually, Ducky turns conditions into a fast, emotional, and trustworthy decision flow.

## Product Summary

- Focus: discover bathing waters in Austria and quickly identify the best current option.
- Core promise: score-based ranking should only feel "ready" when weather coverage is complete for the loaded lakes.
- Personality: Ducky is the mascot and the emotional anchor across onboarding, hero states, loading, and score storytelling.
- Visual direction: colorful, buoyant, and intentionally light-only.
- Language: the user-facing app copy is primarily German.

## Main Experience

### Home

- Ducky-led hero card with current swim mood and contextual copy.
- `Top 5 in deiner Nähe` nearby section when location permission is granted.
- Main `Gewässer` list with search, sorting, pagination, and score-first browsing.
- Blocking hydration flow on startup when weather coverage is incomplete.

### Map

- Score-colored pins for spatial discovery.
- Compact selected-lake card with score, location, air/water chips, and actions.
- Fast routing into Apple Maps.

### Favorites

- Personal shortlist of saved lakes.
- Rows prioritize score and temperatures over secondary metadata.
- Quick revisit flow for likely repeat spots.

### Lake Detail

- Score-led hero with condition messaging.
- `Auf einen Blick`, `Wetter vor Ort`, `Gesundheit`, Apple Maps, and Wikipedia cards.
- Health and quality context from AGES data, weather context from Open-Meteo, and route handoff via Apple Maps.

## SwimScore

`SwimScore` is Ducky's central decision engine. Scores run from **0.0 to 10.0**.

### Current weighting

- With current in-season water temperature: weather `70%`, water temperature `30%`
- Without current water temperature: weather `100%`

### Deductions and overrides

- Water quality is deduction-only:
  - `A`: `0.0`
  - `G`: `-0.4`
  - `AU`: `-1.8`
- Bacteria deduction is active from latest `E.Coli` and `Enterokokken` values.
- Combined bacteria deduction is capped at `-2.8`.
- Closed waters force a warning-level total of `1.0`.
- Poor quality (`mangelhaft`) forces a warning-level total of `1.5`.
- Final totals are clamped to `0.0...10.0`.

### Seasonal truthfulness

Ducky does **not** present stale summer water measurements as if they were current year-round.

- June to August measurements may count as current water temperature.
- Outside the active bathing season, water temperature becomes unknown for score and UI purposes.
- When water temperature is unavailable, the score falls back to weather-only logic.

## Data Sources

- [AGES bathing-water JSON](https://www.ages.at/typo3temp/badegewaesser_db.json)
- [Open-Meteo forecast API](https://api.open-meteo.com/v1/forecast)
- Apple Maps for place metadata and routing
- Wikipedia for place and lake background content

## Correctness and Startup Rules

These are core product rules, not implementation details:

- Global score ranking should not be trusted while weather coverage is partial.
- Weather is cached for warm launches, then refreshed in the background when stale.
- If coverage is incomplete, the app blocks score-first browsing until hydration completes or an explicit fallback is shown.
- `WeatherService` is the single weather gateway and owns hydration, cache lifecycle, and in-flight request deduplication.

## Architecture

### Entry and navigation

- `fluesseundseen/fluesseundseenApp.swift`
- `fluesseundseen/ContentView.swift`

### Main tabs

- `fluesseundseen/Views/HomeView.swift`
- `fluesseundseen/Views/MapView.swift`
- `fluesseundseen/Views/FavouritesView.swift`

### Core services

- `DataService`: loads and caches AGES lake data
- `WeatherService`: fetches, hydrates, caches, and refreshes weather
- `LocationService`: wraps Core Location permission and updates
- `LakeContentService`: loads Wikipedia content
- `LakePlaceService`: loads Apple Maps metadata

### Core models

- `BathingWater`
- `SwimScore`
- `Season`
- `DuckState`
- `FavouriteItem`

### Design system

- `fluesseundseen/Views/Components/AppTheme.swift`

`AppTheme` centralizes the visual system: score colors, gradients, typography, motion timing, and reusable card/chip styling.

## Tech Stack

- Swift
- SwiftUI
- SwiftData
- MapKit
- CoreLocation
- StoreKit 2
- URLSession-based network layer
- File-based caching for lake and weather data

## Project Structure

```text
fluesseundseen/
  Models/        Domain types, score logic, season handling
  Services/      APIs, caching, weather, location, content lookups
  Views/         Home, Map, Favorites, Detail, onboarding, components
  Assets.xcassets
fluesseundseen.xcodeproj/
project-outline.MD
AGENTS.md
README.md
```

## Development

### Open in Xcode

1. Open `fluesseundseen.xcodeproj`.
2. Select the `fluesseundseen` scheme.
3. Run on a simulator or device.

### CLI build

```bash
xcodebuild -project fluesseundseen.xcodeproj -scheme fluesseundseen -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build
```

## Additional Notes

- The repository currently has **no open-source license** attached.
- Privacy policy and imprint content are available in-app.
- For a fuller internal product and architecture summary, see `project-outline.MD`.
