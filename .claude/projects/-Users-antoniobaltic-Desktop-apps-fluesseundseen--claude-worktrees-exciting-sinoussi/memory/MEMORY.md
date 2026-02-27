# Flüsse & Seen — Memory

## Quick Reference
- **App**: Austrian bathing water discovery (German-only, iOS 17+)
- **Mascot**: Ducky (rubber duck) — central personality, driven by SwimScore level
- **Score**: SwimScore 1–10 (weather 40% + water temp 35% + quality 25%; no water temp: weather 65% + quality 35%)
- **APIs**: AGES (lakes, no key) + Open-Meteo (weather, no key)
- **Architecture**: SwiftUI + @Observable singletons + SwiftData (FavouriteItem)
- **No external deps**, no tests, no localization

## Key Files (by importance)
- `Views/HomeView.swift` — largest file (~44KB), startup orchestration, list, hero, sorting
- `Services/WeatherService.swift` — @MainActor, weather cache, bootstrap/hydration logic
- `Services/DataService.swift` — AGES API fetch, file-based cache (24h TTL)
- `Models/SwimScore.swift` — scoring algorithm and level mapping
- `Models/BathingWater.swift` — core model, JSON decode, computed helpers
- `Views/Components/AppTheme.swift` — design system, colors, typography, RecentLake, Haptics
- `AGENTS.md` — authoritative operational guide, UX baseline, invariants

## Critical Invariants
1. **Score correctness > speed** — never rank by bestScore without full weather coverage
2. **Weather bootstrap on HomeView appear** — blocking overlay if incomplete
3. **@MainActor on WeatherService** — all cache mutations serialized, no parallel dict writes
4. **Temperature freshness** — `currentWaterTemperature` returns nil outside Jun–Aug
5. **Closed/Mangelhaft → forced warnung** regardless of weather

## Caching (ALL file-based, NOT UserDefaults)
- Lake data: `cachesDirectory/badegewaesser_cache.json` (24h TTL)
- Weather: `cachesDirectory/weather_cache_v3.json` (30min TTL, debounced saves)
- Recent lakes: `UserDefaults("recentLakes")` (max 5, Codable)
- Favorites: SwiftData `FavouriteItem`

## Current UX Decisions (from AGENTS.md)
- Main list header: "Gewässer" (not "Alle Gewässer")
- Sort options: Bester Score, Entfernung, A–Z, Lufttemperatur, Wassertemperatur (all bidirectional)
- Quality/score search filters intentionally REMOVED — don't reintroduce
- Wave under hero intentionally REMOVED
- Notifications feature de-scoped — don't reintroduce in UI
- Map bottom card: minimal (no verdict text like "Mittelmäßig")
- Favorites: score+temps prominent, quality secondary

## Performance Patterns
- `HomeView.updateDisplayLakes(debounce:)` — derive once, cache in @State, debounce 200ms
- Weather: max 24 concurrent fetches, in-flight deduplication, 3 retry attempts
- Map: only renders lakes in visible region
- Lake list: progressive pagination (20 at a time)
- JSON parsing: `Task.detached` for off-main-thread work

## Design System (AppTheme)
- Rounded fonts throughout (heroTitle 34, sectionTitle 22, cardTitle 17, bodyText 15, caption 13)
- Score colors: scorePerfekt (green), scoreGut (teal), scoreMittel (amber), scoreSchlecht (orange), scoreWarnung (red)
- Animations: gentleSpring (0.6/0.8), quickSpring (0.35/0.7), springAnimation (0.5/0.75)
- Cards: 20pt radius, shadows, glow overlay in dark mode

## Outdated CLAUDE.md (thirsty-feynman worktree)
The CLAUDE.md in the other worktree has stale info. Key diffs from current state:
- Says "Cache in UserDefaults" — now file-based
- Lists notification toggle — now de-scoped
- Lists quality/score search filters — now removed
- Says "Alle Gewässer" — now "Gewässer"
- Missing: bidirectional sorting, context menus, recent lakes, weather bootstrap blocking
