# Ducky

Ducky is a colorful iOS app for discovering lakes and bathing waters in Austria.
It combines weather, water quality, and seasonal logic into one easy rating called **SwimScore**.

## What The App Does

- Shows bathing waters across Austria.
- Ranks nearby waters by **SwimScore**.
- Provides map, favorites, and fast search/filter flows.
- Shows detailed lake pages with weather, health/quality data, route links, and context info.
- Includes playful Ducky feedback and shareable cards.
- Supports optional in-app tip jar (StoreKit) to support development.

## SwimScore (High-Level)

- Score range: **0.0 to 10.0**.
- Base score uses weather and (when available) current water temperature.
- Water quality and bacteria data are **deduction-only** factors.
- Closed or critical-quality waters can trigger forced warning-level scores.
- If current water temperature is unavailable/outdated, scoring falls back to weather-only logic.

## Main Data Sources

- AGES bathing water data:
  - `https://www.ages.at/typo3temp/badegewaesser_db.json`
- Open-Meteo weather forecasts:
  - `https://api.open-meteo.com/v1/forecast`
- Additional integrations:
  - Apple Maps (routing/location context)
  - Wikipedia (background content)

## Tech Stack

- Swift + SwiftUI
- SwiftData (favorites persistence)
- CoreLocation
- StoreKit 2 (tip jar)

## Project Structure

- `fluesseundseen/Views`: screens and UI components
- `fluesseundseen/Services`: API, caching, location, and content services
- `fluesseundseen/Models`: domain models and SwimScore logic
- `fluesseundseen.xcodeproj`: Xcode project

## Run Locally

1. Open `fluesseundseen.xcodeproj` in Xcode.
2. Select the `fluesseundseen` scheme.
3. Run on an iPhone simulator or physical device.

CLI build:

```bash
xcodebuild -project fluesseundseen.xcodeproj -scheme fluesseundseen build
```

## Notes

- Current in-app copy is primarily German.
- Privacy policy and imprint pages are available in the app under Settings.
