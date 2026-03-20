# Ducky — Badeseen Österreich

Your swim-day companion for Austrian lakes. Ducky combines live weather, water temperature, and official water quality into a single **SwimScore** (0–10) so you know instantly whether it's worth jumping in.

Available on the [App Store](https://apps.apple.com/at/app/ducky/id6760419989).

## Features

- **SwimScore** — one number that tells you if conditions are right
- **260+ lakes** — all official Austrian bathing waters (AGES data)
- **Live weather** — per-lake conditions from Open-Meteo
- **Map & list views** — explore nearby or browse by region
- **Favourites** — save your go-to lakes
- **Notes** — private notes on each lake (parking, tips, favourite spots)
- **Visit tracking** — mark lakes as visited, build your personal swim history
- **Health data** — water quality, bacteria levels, visibility depth
- **Wikipedia info** — background on each lake
- **Routes** — open directions in Apple Maps
- **Tip jar** — optional support via StoreKit 2

## Tech Stack

Swift · SwiftUI · SwiftData · MapKit · CoreLocation · StoreKit 2

No third-party dependencies.

## Data Sources

| Source | What it provides |
|--------|-----------------|
| [AGES](https://www.ages.at) | Official bathing water quality & bacteria data |
| [Open-Meteo](https://open-meteo.com) | Live weather per lake |
| Apple Maps | Location search & routing |
| Wikipedia | Lake descriptions & background info |

## Running Locally

Open `ducky.xcodeproj` in Xcode 26+ and run the `ducky` scheme on an iOS 26 simulator.

```bash
xcodebuild -project ducky.xcodeproj -scheme ducky -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' build
```

## Project Structure

```
ducky/
  Models/       # SwiftData models (LakeNote, LakeVisit, FavouriteLake) & BathingWater
  Services/     # Data, Weather, Location, Wikipedia, Places, TipJar
  Views/        # SwiftUI views & components
  Assets.xcassets/
```

## License

This project is not open-source. All rights reserved.

## Author

**Antonio Baltic** — [antoniobaltic](https://github.com/antoniobaltic)
