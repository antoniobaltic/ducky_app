# Ducky Project Outline

## App Identity

The official product name is **Ducky**.

Ducky is a playful iOS app for discovering bathing lakes and rivers in Austria. Its job is to help people answer one simple question quickly and confidently:

**Where should I swim today?**

The app combines official bathing-water data, live weather, seasonal truthfulness, and a mascot-led interface into one emotionally clear decision system called `SwimScore`.

Ducky is not meant to feel like a sterile directory or an engineering dashboard. It should feel like a cheerful local companion with strong taste, clear recommendations, and a memorable personality.

## Core Purpose

Ducky exists to make swim-day decisions:

- fast
- trustworthy
- fun
- visually intuitive

The app should reduce the amount of manual research a user has to do. Instead of comparing weather, water temperature, and quality data by hand, users should be able to open Ducky and immediately understand:

- which lakes look best right now
- which nearby option is worth choosing
- whether a score can actually be trusted
- what tradeoffs exist at a specific lake

## Core User Promise

The single most important product promise is this:

**Ducky must never pretend that score-based ranking is ready if weather coverage is incomplete.**

That rule matters because the app is built around `SwimScore`. If score ranking is incomplete or misleading, the whole product loses credibility.

This means:

- `SwimScore` is the primary decision engine
- global sorting by score must only be treated as trustworthy when the necessary weather data exists
- weather hydration and cache completeness are product requirements, not just technical details

## Product Personality

Ducky is the mascot, not a decorative extra.

Ducky should feel:

- friendly
- slightly cheeky
- emotionally readable
- supportive without sounding robotic
- playful without becoming childish nonsense

Ducky is the emotional anchor in onboarding, hero messaging, loading states, score storytelling, support prompts, and celebratory moments.

## Ducky's Language

Ducky speaks in **friendly Austrian German with light slang**, not formal textbook German and not generic internet slang.

The voice should sound:

- local
- warm
- short and punchy
- a little mischievous
- easy to understand even when playful

### Voice rules

- Prefer Austrian phrasing over stiff Standard German.
- Use small, natural slang touches instead of overdoing dialect.
- Keep lines short and memorable.
- Let Ducky react emotionally to weather, cold water, bad conditions, and perfect swim days.
- Avoid sounding rude, aggressive, or too ironic.
- Avoid northern-German phrasing and generic corporate copy.

### Useful language patterns

- `a bissl`
- `heut`
- `passt scho`
- `leiwand`
- `na geh`
- `g'scheit`
- `Semmel`
- `grantig`
- `ab ins Wasser`

### Concrete examples of Ducky's voice

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

### Examples to avoid

- `Heute herrschen optimale Badebedingungen.`
- `Bitte beachten Sie die aktuellen Messwerte.`
- `Mega nice, let's gooooo.`
- `Dies ist eine ausgezeichnete Gelegenheit für einen Schwimmausflug.`

The goal is not to write full dialect. The goal is to sound unmistakably Austrian, friendly, and alive.

## Design Philosophy

The design should feel joyful, buoyant, and unmistakable.

Core visual principles:

- bright, water-inspired colors
- strong gradients tied to score and mood
- rounded forms and soft geometry
- expressive cards and chips
- subtle motion that feels like water, air, and floating
- light-only presentation as the intentional product look

The UI should never become bland, gray, or app-template generic. Ducky should feel polished and inviting from the first screen.

## Experience Structure

Ducky is organized around three main product surfaces plus a detailed lake view.

### Home

Home is the discovery and ranking hub.

It is responsible for:

- first-impression mood and storytelling
- startup correctness and weather hydration
- nearby recommendations
- main ranking and browsing
- search, sorting, and pagination

Home should make the best option feel obvious quickly.

### Map

Map is for spatial exploration.

It is responsible for:

- score-colored lake pins
- quick geographic browsing
- fast comparison in context
- direct route handoff

The tapped-lake sheet should stay compact and useful.

### Favorites

Favorites is the return-to-known-places surface.

It is responsible for:

- quick reaccess to saved lakes
- score and temperature-first scanning
- low-friction revisit behavior
- quick actions like sharing and routing

### Lake Detail

Lake Detail is where trust is built.

It should answer:

- why the score is what it is
- what the local conditions are
- whether the health data is reassuring
- how far away the place is
- how to get there
- what background information exists

## SwimScore Philosophy

`SwimScore` is the app's core decision engine.

It combines:

- live weather
- current water temperature when seasonally valid
- water-quality deductions
- bacteria deductions
- forced overrides for closures and poor quality

Current weighting:

- with current water temperature: weather `70%`, water temperature `30%`
- without current water temperature: weather `100%`

Important rules:

- quality is deduction-only
- bacteria deductions are active and capped
- forced overrides remain stronger than the normal weighted score
- final totals are clamped to `0.0...10.0`

`SwimScore` is not just a number. It drives:

- sorting
- badge color
- hero gradients
- detail-page mood
- Ducky's emotional storytelling

## Seasonal Truthfulness

Ducky must not treat stale summer measurements as current all year.

Seasonality rules:

- current water temperature is only trusted when seasonally valid
- outside the relevant bathing period, water temperature may become unknown
- off-season behavior must be honest in score logic and UI copy
- missing current water temperature should degrade gracefully to weather-only scoring

This is one of the main trust-preserving behaviors in the app.

## Data Sources

Ducky relies on:

- AGES bathing-water data for official lake information, quality, bacteria, and measurements
- Open-Meteo for live weather conditions
- Apple Maps for place metadata and routing
- Wikipedia for local background content

AGES gives the official bathing-water truth.
Open-Meteo gives the current weather layer.
Together they make the ranking useful.

## Architecture Overview

The architecture is a SwiftUI app with shared singleton-style services and a score-driven UI.

### Entry layer

- `ContentView` is the root shell
- it injects the main shared services into the environment
- it controls onboarding vs main app flow
- it handles app-level startup concerns like location bootstrap and support prompts

### Main surfaces

- `HomeView`
- `MapView`
- `FavouritesView`
- `LakeDetailView`
- `SettingsView`

### Core services

- `DataService`
  Loads, parses, caches, and refreshes AGES lake data.
- `WeatherService`
  Fetches, hydrates, caches, and refreshes weather data.
- `LocationService`
  Wraps Core Location authorization and updates.
- `LakeContentService`
  Resolves Wikipedia summaries and related content.
- `LakePlaceService`
  Resolves Apple Maps place metadata.
- `TipJarService`
  Handles optional support products and StoreKit purchase flow.

### Core models

- `BathingWater`
  Main lake model and helper logic.
- `SwimScore`
  Scoring formula, deductions, level mapping.
- `Season`
  Freshness and off-season logic.
- `DuckState`
  Emotional state model for the mascot.
- `FavouriteItem`
  Local persisted favorites via SwiftData.

### Design system

- `AppTheme`

`AppTheme` centralizes:

- color tokens
- score colors
- typography
- gradients
- shared spacing and corner styles
- motion timing and spring behavior

## Startup and Caching Strategy

Ducky balances fast startup with score correctness through layered caching.

Key rules:

- lake data is cached on disk
- weather data is cached on disk
- stale but complete weather can support instant launch and then refresh in background
- incomplete weather must trigger blocking hydration before score-first browsing is trusted

This creates three important launch modes:

1. Cold launch
   Ducky loads lake data, hydrates weather, and blocks score browsing until ready.
2. Warm launch with complete fresh cache
   Ducky can rank immediately.
3. Warm launch with complete stale cache
   Ducky can rank immediately, then refresh in the background.

## Emotional UX Rules

Ducky should stay visible in the moments that matter most:

- onboarding
- home hero
- loading and waiting states
- score storytelling
- success moments
- tip jar gratitude moments

The mascot should not disappear into the background as the app matures. More polish should make Ducky feel more alive, not less important.

## Non-Negotiables

The following product rules should remain intact unless they are replaced by something equally strong:

- never present score ranking as fully trustworthy when weather coverage is incomplete
- preserve the app's beautiful, colorful, light-only visual identity
- keep Ducky central to the emotional experience
- prefer clarity over feature bloat
- preserve seasonal truthfulness around water temperature
- keep motion meaningful rather than noisy
- keep the interface intuitive even when the data model gets richer

## Success Criteria

Ducky succeeds when it does all of the following at once:

1. makes Austrian lake discovery feel joyful
2. makes the best current option obvious quickly
3. earns trust through honest data behavior
4. feels distinctive because of Ducky's personality and voice
5. remains polished, fast, and readable

## One-Sentence Summary

**Ducky is a playful Austrian swim-day companion that turns official water data and live weather into a trustworthy, colorful, mascot-led recommendation experience.**
