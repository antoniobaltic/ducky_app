# AGENTS.md

This is the single authoritative project guide for **Ducky**.

Use this document as the source of truth for product intent, architecture, design direction, technical invariants, Ducky's voice, current UX behavior, and known limitations.

## Product Summary

- Product name: `Ducky`
- Platform: `iOS` only
- Purpose: help people in Austria decide where to swim today
- Core mechanism: `SwimScore`
- Personality anchor: Ducky the mascot
- Visual direction: colorful, buoyant, playful, intentionally light-only

Ducky is not a generic places app. It is a score-driven swim-day companion that turns official water data and live weather into a clear recommendation experience.

## Product Intent

- Make lake discovery in Austria feel joyful and fast.
- Help users compare current conditions without manual research.
- Keep Ducky central in UX, copy, and emotional feedback.
- Preserve trust through data honesty, especially around weather completeness and water-temperature seasonality.

## Core User Promise

Users rely on ranking by `SwimScore`.

That means:

- score quality depends on weather + water + quality inputs
- global score-based ranking must not be treated as ready while weather coverage is incomplete
- startup correctness matters more than fake speed

## What The App Does

- Shows bathing lakes and rivers across Austria.
- Ranks loaded waters by current `SwimScore`.
- Offers a `Top 5 in deiner Nähe` section when location permission is granted.
- Supports search, sorting, map browsing, favorites, and detail drill-down.
- Explains conditions using weather, water, health, and quality cards.
- Offers an optional tip jar through StoreKit.

## How Ducky Should Feel

Ducky should feel:

- friendly
- a little cheeky
- emotionally readable
- supportive, not robotic
- polished, not sterile
- playful, not chaotic

The app should feel like a local companion with taste and personality, not a cold utility.

## Ducky's Language

Ducky speaks in **friendly Austrian German with light slang**.

Rules:

- Prefer Austrian phrasing over stiff Standard German.
- Use slang lightly and naturally.
- Keep copy short, warm, and memorable.
- Let Ducky react emotionally to great days, bad conditions, wind, cold water, and waiting states.
- Avoid corporate language, formal instruction tone, and overdone dialect spelling.

Useful patterns:

- `a bissl`
- `heut`
- `passt scho`
- `leiwand`
- `na geh`
- `g'scheit`
- `grantig`
- `Semmel`
- `Schnabel`
- `ab ins Wasser`

Concrete examples:

- `Heut schaut's leiwand aus. Ab ins Wasser!`
- `Na geh, des Wasser is a bissl frisch.`
- `Passt scho, aber nimm da lieber a Handtuch mehr mit.`
- `Ui, heut is g'scheit windig.`
- `Des is a richtig feiner Badetag.`
- `Oha, da braut sich was zam.`
- `Da Ducky is heut zufrieden.`
- `Heut kriegt der Schnabel fast Lust auf a Doppelsemmel.`
- `Brrr. Da Ducky wird grantig bei so kaltem Wasser.`
- `Schau, des Platzerl taugt was.`

Examples to avoid:

- `Heute herrschen optimale Badebedingungen.`
- `Bitte beachten Sie die aktuellen Messwerte.`
- `Mega nice, let's gooooo.`
- `Dies ist eine ausgezeichnete Gelegenheit für einen Schwimmausflug.`

## Architecture Overview

### Entry And Navigation

- App entry: `ducky/DuckyApp.swift`
- Root composition: `ducky/ContentView.swift`
- Main tabs:
  - `ducky/Views/HomeView.swift`
  - `ducky/Views/MapView.swift`
  - `ducky/Views/FavouritesView.swift`

### Services

- `DataService`
  Loads AGES bathing-water JSON, parses it, and caches it to disk.
- `WeatherService`
  Loads Open-Meteo weather per lake, caches it, and manages hydration / refresh lifecycle.
- `LocationService`
  Wraps CoreLocation permission and updates.
- `LakeContentService`
  Loads Wikipedia content and related summaries.
- `LakePlaceService`
  Loads Apple Maps place metadata.
- `TipJarService`
  Loads StoreKit products, handles tip purchases, and tracks local tip state.

### Models

- `BathingWater`
  Main decoded lake model plus score helpers, naming cleanup, and distance helpers.
- `SwimScore`
  Composite scoring logic and level mapping.
- `Season`
  Off-season logic and stale-temperature handling.
- `DuckState`
  Mascot expression and tone model.
- `FavouriteItem`
  SwiftData persistence for favorites.

### Design System

- `ducky/Views/Components/AppTheme.swift`

`AppTheme` contains:

- score colors
- gradients
- typography
- corner radii
- shared card styles
- spring timing and motion constants

## Data Sources

- AGES bathing water data:
  `https://www.ages.at/typo3temp/badegewaesser_db.json`
- Open-Meteo weather:
  `https://api.open-meteo.com/v1/forecast`
- Apple Maps:
  routing and place metadata
- Wikipedia:
  contextual place and lake content

## Scoring Rules

Current `SwimScore` weighting:

- with current water temperature: weather `70%`, water temperature `30%`
- without current water temperature: weather `100%`

Quality is deduction-only:

- `A`: `0.0`
- `G`: `-0.4`
- `AU`: `-1.8`
- unknown: `0.0`

Bacteria deduction:

- `E.Coli > 500`: `-0.5`
- `E.Coli > 1000`: `-1.4`
- `Enterokokken > 200`: `-0.5`
- `Enterokokken > 400`: `-1.4`
- combined bacteria deduction cap: `-2.8`

Forced overrides:

- `isClosed` => total `1.0`
- poor quality (`mangelhaft`) => total `1.5`

Final score clamp:

- `0.0...10.0`

## Seasonal Truthfulness

The app must not treat stale summer measurements as current all year.

Rules:

- only current-season June to August measurements count as current water temperature
- outside the active bathing season, current water temperature may be unknown
- when water temperature is unavailable, scoring falls back to weather-only logic
- off-season behavior must remain honest in UI and score explanations

## Caching And Startup Invariants

- `DataService` caches AGES payload in the caches directory.
- `WeatherService` caches the weather dictionary in `weather_cache_v4.json`.
- Weather cache may be used stale for instant launch ranking, then refreshed in the background.
- On startup, `HomeView` must call `WeatherService.bootstrapWeather(for:)`.
- If full weather coverage is missing, the app shows a blocking loading overlay with progress and retry.
- Preview fixtures are design-time only and must never leak into the real app runtime.
- If live data loading fails, do not fall back to fake preview lakes in production.
- Do not remove this without replacing it with an equivalent correctness guarantee.

## Score Correctness Rules

- `bestScore` sorting is only trustworthy when every displayed lake has weather loaded.
- Never silently accept partial weather for global ranking.
- If partial coverage exists, keep blocking and retrying or communicate degraded mode explicitly.

## WeatherService Notes

- `fetchWeather(for:forceRefresh:)` deduplicates in-flight requests.
- `hydrateAllWeather(for:forceRefresh:)` supports full hydration with concurrency control.
- `refreshAllWeatherInBackground(for:)` is used when cache is complete but stale.
- Keep all weather cache mutation main-actor isolated.
- Avoid parallel dictionary writes outside `@MainActor`.

## UI And Motion Guidelines

- Keep Ducky visible in onboarding, hero, loading, score storytelling, and celebration moments.
- Preserve the app's colorful, buoyant, light-only visual identity.
- Use existing motion utilities before adding new animation systems.
- Relevant components include:
  - `WaterWaveView`
  - `WaveDivider`
  - `FloatingBubblesView`
  - spring animations in `AppTheme`
- Motion should feel alive, not noisy.

## Performance Guidelines

- Avoid expensive recomputation inside `body`.
- Follow the `HomeView.updateDisplayLakes` pattern: derive once, cache in state, debounce frequent triggers.
- Keep weather/network fan-out bounded.
- Use `WeatherService` as the single weather gateway.

## Current UX Baseline

### Home

- Main list header label is `Gewässer`.
- Home includes `Top 5 in deiner Nähe` when location permission is granted.
- The wave directly under the hero card and above the search bar is intentionally removed.
- The search bar uses stronger contrast and shadow for readability.
- The three stat cards stay centered and visually balanced.
- There is **no forced winter-only hero override**. Hero messaging should follow live context, not a hard seasonal fallback.
- Long-press hint copy is exactly:
  `Lange drücken zum Teilen, als Favorit hinzufügen und Route berechnen.`

### Sorting And Filtering

- Sort options:
  - `Bester Score`
  - `Entfernung`
  - `A–Z`
  - `Lufttemperatur`
  - `Wassertemperatur`
- Every sort option is bi-directional.
- Search overlay filters only by Bundesland.
- Removed filters must stay removed:
  - quality presets
  - score presets
- Air-temperature iconography uses `wind`.

### Map

- Tapped-lake bottom card stays minimal:
  - compact score badge
  - lake name + municipality/state
  - chips for air/water/distance
  - actions: `Details`, `Route`
- Do not reintroduce score verdict text in this compact card.
- Missing values use placeholders like `Luft –` and `Wasser –`.

### Lake Detail

- Hero and page background are score-level gradients.
- Hero extends to the top safe area.
- Hero quote behavior depends on score level only.
- `Auf einen Blick` stays concise and readable.
- Removed cards/elements that must stay removed:
  - `Außerhalb der Badesaison`
  - separate Wasserqualität/Bakteriologie/Sichttiefe cards
  - `Live-Ortskarte`
  - `Ortsinfos öffnen`
  - bottom Wikipedia row/button
- `Gesundheit` card replaces the former separate health cards.
- `Wetter vor Ort` uses the pill-style weather condition treatment.
- Score details card stays expanded.

### Favorites

- Favorites rows prioritize score and temperatures.
- Water quality stays secondary.
- Air-temperature chip uses `wind` and `AppTheme.airTempGreen`.

### Settings

- Legal and footer references should use `Antonio Baltic`.
- Contact email namespace is `antoniobaltic`.

## Tip Jar

The app-side tip jar implementation exists.

Configured product namespace:

- `antoniobaltic.ducky.tip.small`
- `antoniobaltic.ducky.tip.medium`
- `antoniobaltic.ducky.tip.large`

Important notes:

- These are consumable in-app purchases.
- The app should not expose raw product IDs or developer-facing reference names to users when StoreKit cannot load products.
- Missing product diagnostics may be logged in debug output, but user-facing fallback copy should stay clean and human-readable.
- The Xcode project includes the `In-App Purchase` capability.
- App Store Connect setup is still required before the tip jar works in production or TestFlight.

## Known Limitations

- The app depends on external data from AGES, Open-Meteo, Apple Maps, and Wikipedia.
- If remote data is unavailable, behavior falls back to cached/local state where possible.
- Current water temperature is intentionally unavailable outside the valid season.
- The app is currently German-only in its UI copy.
- The tip jar still requires matching App Store Connect product creation and submission.
- There is no notifications feature in the current product scope.

## Development Workflow

- Open project: `ducky.xcodeproj`
- Preferred scheme: `ducky`
- Build command:
  `xcodebuild -project ducky.xcodeproj -scheme ducky -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build`

### Before Shipping

- Build succeeds with no errors.
- Cold launch validates score-ready behavior.
- Warm launch validates cached startup.
- Stale cache launch validates background refresh.
- Offline fallback remains sane.
- Pull-to-refresh and tab switching stay responsive.
- Tip jar is either fully configured in App Store Connect or intentionally hidden / not relied on.

## Change Safety Checklist

- If touching scoring, inspect `SwimScore` and `BathingWater.swimScore(weather:)`.
- If touching season logic, inspect `Season.isMeasurementOutdated`.
- If touching startup, validate cold, warm, stale-cache, and offline flows.
- If touching Home list behavior, verify sorting, filtering, search, and pagination together.
- If touching StoreKit, verify product IDs, missing-product behavior, and purchase handling.
- If touching naming or bundle identity, verify App Store Connect and signing implications.

## File Map

- `ducky/Views/HomeView.swift`
  Startup orchestration, hero, nearby ranking, list behavior.
- `ducky/Services/WeatherService.swift`
  Weather hydration and cache lifecycle.
- `ducky/Services/DataService.swift`
  AGES ingest and cached lake lifecycle.
- `ducky/Models/SwimScore.swift`
  Ranking math.
- `ducky/Views/Components/AppTheme.swift`
  Design tokens and motion constants.
- `ducky/Services/TipJarService.swift`
  StoreKit product loading and purchase flow.

## Non-Negotiables

- Keep the app beautiful, colorful, and emotionally clear.
- Preserve intuitive UX over feature complexity.
- Ducky remains the main personality anchor.
- Keep score correctness above perceived speed hacks.
- Preserve light-only presentation unless product direction changes explicitly.
- Do not weaken seasonal truthfulness.

## One-Sentence Summary

**Ducky is a colorful Austrian swim-day companion that combines official bathing-water data, live weather, and a mascot-led voice into a trustworthy recommendation experience.**
