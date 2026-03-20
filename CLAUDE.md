# CLAUDE.md

## Build & Run

```
xcodebuild -project ducky.xcodeproj -scheme ducky -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build
```

No third-party dependencies. No package manager.

## Project at a Glance

- **Ducky** — iOS swim-day companion for Austrian lakes
- **Bundle ID:** `antoniobaltic.ducky` | **Version:** 1.1.0 (build 3) | **Target:** iOS 26.0
- **Stack:** Swift 5, SwiftUI, SwiftData, MapKit, CoreLocation, StoreKit 2
- **Core mechanism:** SwimScore (0-10 composite from weather + water temp + quality)
- **Visual:** Colorful, buoyant, light-mode only (`.preferredColorScheme(.light)` enforced)
- **UI language:** German only (Austrian dialect — see Voice section)
- **App Store:** "Ducky — Badeseen Österreich" | Category: Weather (primary), Travel (secondary)

## Key Invariants (things you must not break)

1. **Score correctness over speed.** Global ranking is only valid when ALL lakes have weather loaded. Never silently show partial-weather rankings.
2. **Seasonal truthfulness.** `currentWaterTemperature` returns nil outside current-year Jun-Aug. Off-season scoring falls back to weather-only ("Wetter-Score"). Do not treat stale summer measurements as current.
3. **No preview data in production.** `isPreviewStubbed` guards must stay. Never fall back to `BathingWater.previews` in real builds.
4. **Light-mode only.** Do not add dark mode support unless explicitly asked.
5. **WeatherService is @MainActor.** All cache mutations must stay on MainActor. Network fetches are `nonisolated static` by design.
6. **Startup flow:** HomeView calls `bootstrapWeather(for:)`. If weather incomplete, app blocks with progress overlay. Do not bypass this.
7. **All @Observable services are @MainActor.** DataService, WeatherService, LocationService, LakeContentService, LakePlaceService, TipJarService — all annotated `@MainActor @Observable`.

## Removed UI That Must Stay Removed

- Wave between hero card and search bar
- Quality presets and score presets in filters
- "Ausserhalb der Badesaison" card in lake detail
- Separate Wasserqualitaet/Bakteriologie/Sichttiefe cards (replaced by single "Gesundheit" card)
- "Live-Ortskarte", "Ortsinfos oeffnen", bottom Wikipedia row/button in detail view
- Forced winter-only hero override

## Voice & Language

Ducky speaks **friendly Austrian German with light slang**. Short, warm, memorable.

Good: `Heut schaut's leiwand aus. Ab ins Wasser!` / `Na geh, des Wasser is a bissl frisch.` / `Passt scho, aber nimm da lieber a Handtuch mehr mit.`

Bad: `Heute herrschen optimale Badebedingungen.` (too formal) / `Mega nice, let's gooooo.` (wrong tone)

Patterns: `a bissl`, `heut`, `passt scho`, `leiwand`, `na geh`, `g'scheit`, `grantig`, `Semmel`, `Schnabel`, `ab ins Wasser`

## Scoring Quick Reference

```
Closed  -> total=1.0, warnung
Mangelhaft -> total=1.5, warnung

Otherwise:
  base = weather*0.70 + waterTemp*0.30  (weather*1.00 if no water temp)
  total = clamp(base + qualityPenalty + bacteriaPenalty, 0, 10)

Quality:  A=0  G=-0.4  AU=-1.8  M=-2.0  unknown=0
Bacteria: E.Coli >500=-0.5 >1000=-1.4 | Enterococci >200=-0.5 >400=-1.4 | cap=-2.8
Levels:   perfekt 8-10 | gut 6-8 | mittel 4-6 | schlecht 2-4 | warnung 0-2
```

## Data Sources & Caching

| Source | Cache File | TTL |
|--------|-----------|-----|
| AGES bathing water (`ages.at/typo3temp/badegewaesser_db.json`) | `badegewaesser_cache.json` + `_ts.txt` | 24h |
| Open-Meteo weather | `weather_cache_v4.json` | 30min |
| Wikipedia (de) | `wikipedia_content_cache_v1.json` | 30 days |
| Apple Maps (MKLocalSearch) | In-memory only | Session |

All disk caches in Caches directory. Weather save is debounced 3s (can lose on crash).

## Service Architecture

All services are singletons (`.shared`) with `.previewInstance()` for SwiftUI previews. Injected via `@Environment`.

- **DataService** — AGES ingest, file cache, parse `BUNDESLAENDER > BADEGEWAESSER` nested JSON. Fallback cascade: fresh cache -> network -> stale cache -> error.
- **WeatherService** — Open-Meteo per-lake weather. Hydration: complete+fresh=instant, complete+stale=background refresh, incomplete=blocking fetch. Max 10 concurrent. Retry 3x + 2 rescue passes.
- **LocationService** — CoreLocation, 500m filter, ~1km accuracy. Errors silently ignored.
- **LakeContentService** — Wikipedia with confidence matching (35km radius, name match, water keywords). Min 70 chars summary.
- **LakePlaceService** — MKLocalSearch, 45km region, scoring by name strength + metadata - distance. In-memory only.
- **TipJarService** — StoreKit 2 consumables. Prompt after 6 launches, 14-day cooldown, 45-day post-tip cooldown.

## SwiftData Models

- **LakeNote** — per-lake user notes. Fields: `lakeID`, `lakeName`, `noteText`, `createdAt`, `updatedAt`. Edited via `NoteEditorSheet`.
- **LakeVisit** — "Ich war hier" visit tracking. Fields: `lakeID`, `lakeName`, `visitedAt`, `airTemperature?`, `waterTemperature?`. Snapshots weather at time of visit.
- **FavouriteLake** — saved favourite lakes with cached score/temp/quality snapshots.

All models use `lakeID: String` as the lake identifier (matches `BathingWater.id`). Always call `try? modelContext.save()` after mutations.

## Tip Jar Product IDs

- `antoniobaltic.ducky.tip.toast` (small — €1.99)
- `antoniobaltic.ducky.tip.medium` (medium — €2.99)
- `antoniobaltic.ducky.tip.large` (large — €4.99)

Never expose raw IDs to users. Missing-product errors logged DEBUG only.

## Design System (AppTheme)

- Typography: all `.rounded` — heroTitle 34pt heavy, sectionTitle 22pt bold, cardTitle 17pt bold, bodyText 15pt, caption 13pt, smallCaption 11pt
- Radii: card=20, badge=12, button=16
- Animations: gentleSpring (0.5, 0.72), quickSpring (0.3, 0.6)
- Accent color: ocean blue (`rgb(0.10, 0.45, 0.91)`)
- Use existing motion components (WaterWaveView, DuckView, SeasonalEffects) before adding new ones
- DuckView scales via `size / 120`
- App icon: SwiftUI-rendered DuckView on ocean gradient (see `AppIconView.swift`)

## Change Safety

- **Scoring** -> read `SwimScore.swift` completely
- **Season** -> check `Season.isMeasurementOutdated` + `BathingWater.currentWaterTemperature`
- **Startup** -> validate cold, warm, stale-cache, offline flows
- **Home list** -> verify sort, filter, search, pagination together
- **Weather** -> verify hydration, retry, rescue, cache save
- **StoreKit** -> verify product IDs, missing-product fallback
- **AGES parsing** -> verify both nested format and fallback keys
- **SwiftData** -> always `try? modelContext.save()` after writes; test note/visit/favourite CRUD together
- **Build number** -> `CURRENT_PROJECT_VERSION` must increment for each App Store upload (currently 3)

## Identity

- Legal name: **Antonio Baltic**
- Contact namespace: `antoniobaltic`
