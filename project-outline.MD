# Ducky Project Outline

## What This App Is

`fluesseundseen` is a playful Austrian lake discovery app centered around one simple question: "Where should I swim today?"

The app combines official bathing-water data, live weather, and a friendly mascot called Ducky to turn a messy research task into a fast, emotionally clear decision. Instead of making users compare raw measurements, the app translates them into a ranked `SwimScore` and a set of clear visual cues.

The product is designed for people who want to:

- discover bathing lakes and rivers in Austria
- compare spots by current conditions
- find the best nearby option quickly
- understand when the score is trustworthy and when it is not
- enjoy a cheerful, character-led interface instead of a sterile utility

## Product Purpose

The core promise of the app is not just "lake discovery." It is trustworthy swim-day decision support.

That promise depends on two things:

- `SwimScore` must stay central to ranking and storytelling
- rankings must not pretend to be complete when weather coverage is incomplete

This is why the startup flow deliberately blocks score-based browsing until weather has been hydrated for all loaded lakes. Correctness is treated as more important than a falsely fast first render.

## Design Philosophy

The visual and interaction system is intentionally joyful, not neutral.

Key principles:

- Ducky is the personality anchor and should stay visible in primary moments
- the interface should feel colorful, buoyant, and emotionally legible
- motion should feel alive through waves, bubbles, and spring transitions
- feedback should be friendly and optimistic, with German copy and Austrian tone
- polish should support clarity, not distract from it

The app uses `AppTheme` as its visual foundation:

- bright water-inspired colors
- score-level color mapping
- rounded typography and card geometry
- soft gradients, glow, and layered motion
- reusable card and chip patterns across screens

## User Experience Structure

The app is organized into three main tabs:

### Home

The Home tab is the ranking and discovery hub.

It contains:

- a Ducky-led hero that summarizes the current swim mood
- a `Top 5 in deiner Nähe` section when location is available
- the main `Gewässer` list with sorting, filtering, search, and pagination
- score-first browsing once weather coverage is complete

Home is also where the strict startup correctness rule is enforced. On cold launch or incomplete caches, a blocking hydration overlay is shown until weather exists for every loaded lake.

### Map

The Map tab focuses on spatial discovery.

It provides:

- lake pins colored by current score
- direct geographic exploration
- a compact lake sheet with score, location, air/water chips, and route/detail actions
- fast access to route planning

The map experience is intentionally compact and minimal once a lake is tapped.

### Favorites

The Favorites tab is a personal shortlist.

It emphasizes:

- score and temperature first
- low-friction reaccess to preferred lakes
- distance and weather context when available
- long-press quick actions for sharing, routing, and removing favorites

## Core Data Sources

The app depends on two external sources:

- AGES bathing-water JSON: official Austrian bathing-water data
- Open-Meteo forecast API: live weather per lake

These sources feed different layers of the product:

- AGES provides identity, coordinates, quality, bacteria, and seasonal water measurements
- Open-Meteo provides live weather conditions that make ranking current and useful

## SwimScore System

`SwimScore` is the app's main decision engine.

It combines:

- weather score
- current water temperature score when in season
- water quality deduction
- bacteria deduction
- forced overrides for closures and poor quality

Current weighting:

- with current water temperature: weather `70%`, water temperature `30%`
- without current water temperature: weather `100%`

Important rules:

- quality is deduction-only
- bacteria can further reduce the score
- closed lakes and poor-quality lakes force warning-level totals
- final totals are clamped to `0.0...10.0`

This model is implemented in [`SwimScore.swift`](/Users/antoniobaltic/Desktop/apps/fluesseundseen/fluesseundseen/Models/SwimScore.swift).

## Seasonal Truthfulness

The app does not treat historical summer water measurements as if they were current year-round.

`Season` controls this behavior:

- only current-season June to August measurements are treated as current water temperatures
- outside the active bathing season, water temperature becomes unknown for score and UI purposes
- off-season messaging and visual feedback should acknowledge that limitation clearly

This avoids misleading users with stale water-temperature data.

## Architecture Overview

### App Entry

- App entry: [`fluesseundseenApp.swift`](/Users/antoniobaltic/Desktop/apps/fluesseundseen/fluesseundseen/fluesseundseenApp.swift)
- Root composition: [`ContentView.swift`](/Users/antoniobaltic/Desktop/apps/fluesseundseen/fluesseundseen/ContentView.swift)

`ContentView` owns shared singleton services and injects them into the tab tree through SwiftUI environments.

### Main Services

- [`DataService.swift`](/Users/antoniobaltic/Desktop/apps/fluesseundseen/fluesseundseen/Services/DataService.swift)
  Loads, parses, caches, and refreshes AGES lake data.
- [`WeatherService.swift`](/Users/antoniobaltic/Desktop/apps/fluesseundseen/fluesseundseen/Services/WeatherService.swift)
  Fetches, caches, hydrates, and deduplicates weather data across the app.
- [`LocationService.swift`](/Users/antoniobaltic/Desktop/apps/fluesseundseen/fluesseundseen/Services/LocationService.swift)
  Wraps Core Location authorization and user updates.
- [`LakeContentService.swift`](/Users/antoniobaltic/Desktop/apps/fluesseundseen/fluesseundseen/Services/LakeContentService.swift)
  Resolves Wikipedia summaries and related content.
- [`LakePlaceService.swift`](/Users/antoniobaltic/Desktop/apps/fluesseundseen/fluesseundseen/Services/LakePlaceService.swift)
  Resolves Apple Maps place metadata for detail pages.

### Key Models

- [`BathingWater.swift`](/Users/antoniobaltic/Desktop/apps/fluesseundseen/fluesseundseen/Models/BathingWater.swift)
  Core lake model, decoding, naming cleanup, seasonal temperature access, quality helpers, distance helpers.
- [`SwimScore.swift`](/Users/antoniobaltic/Desktop/apps/fluesseundseen/fluesseundseen/Models/SwimScore.swift)
  Composite score logic and level mapping.
- [`Season.swift`](/Users/antoniobaltic/Desktop/apps/fluesseundseen/fluesseundseen/Models/Season.swift)
  Seasonality, measurement freshness, and seasonal UI semantics.
- [`DuckState.swift`](/Users/antoniobaltic/Desktop/apps/fluesseundseen/fluesseundseen/Models/DuckState.swift)
  Mascot expression and tone model.
- [`FavouriteItem.swift`](/Users/antoniobaltic/Desktop/apps/fluesseundseen/fluesseundseen/Models/FavouriteItem.swift)
  Local persisted favorites via SwiftData.

### Main Views

- [`HomeView.swift`](/Users/antoniobaltic/Desktop/apps/fluesseundseen/fluesseundseen/Views/HomeView.swift)
  Startup orchestration, hero, nearby ranking, search, filtering, main list.
- [`MapView.swift`](/Users/antoniobaltic/Desktop/apps/fluesseundseen/fluesseundseen/Views/MapView.swift)
  Spatial exploration and compact selection sheet.
- [`FavouritesView.swift`](/Users/antoniobaltic/Desktop/apps/fluesseundseen/fluesseundseen/Views/FavouritesView.swift)
  Personal shortlist and score-first revisit flow.
- [`LakeDetailView.swift`](/Users/antoniobaltic/Desktop/apps/fluesseundseen/fluesseundseen/Views/LakeDetailView.swift)
  Deep dive into a single lake with score explanation, local weather, health data, Apple Maps, and Wikipedia.

### Design System

- [`AppTheme.swift`](/Users/antoniobaltic/Desktop/apps/fluesseundseen/fluesseundseen/Views/Components/AppTheme.swift)
  Tokens for colors, typography, gradients, corner radii, and animation timing.

Supporting component files provide reusable score badges, lake rows, wave effects, bubble effects, quality badges, and breakdown cards.

## Startup and Caching Strategy

Startup speed and score correctness are intentionally balanced through layered caching:

- AGES data is cached on disk by `DataService`
- weather data is cached on disk by `WeatherService`
- stale weather cache can be used for instant launch ranking
- stale-but-complete weather should refresh in the background
- incomplete weather must trigger full hydration before ranking is trusted

This produces three important launch modes:

1. Cold launch with no cache
   The app loads AGES data, hydrates weather, and blocks score browsing until complete.
2. Warm launch with fresh complete cache
   The app can rank immediately.
3. Warm launch with stale complete cache
   The app can rank immediately and refresh in the background.

## Non-Negotiable Product Rules

The following rules are foundational and should remain intact unless replaced by something equally trustworthy:

- do not present global score ranking as ready while weather coverage is partial
- keep weather cache mutations main-actor isolated
- use `WeatherService` as the single weather gateway
- preserve Ducky as the emotional center of the UX
- keep the interface beautiful, playful, and readable in both light and dark appearance
- prefer intuitive user understanding over feature complexity

## Current Implementation Character

The app is not a generic “travel list.” It is a score-driven swim companion with strong editorial tone.

Its current character comes from:

- localized Austrian copy
- mascot-led feedback loops
- score-colored gradients and badges
- motion that reinforces water, weather, and mood
- data truthfulness around seasonality and completeness

## In Short

Ducky succeeds when it does three things at once:

1. makes Austrian swim discovery feel fun
2. makes the best option obvious quickly
3. earns trust by being honest about data quality and coverage

That combination of delight and correctness is the real product.
