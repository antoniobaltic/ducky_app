# Ducky

Ducky is an iOS app for discovering bathing lakes and rivers in Austria.

It combines official bathing-water data, live weather, seasonal truthfulness, and a playful mascot-led interface into a clear recommendation system called `SwimScore`.

## Features

- Browse Austrian bathing waters
- Compare lakes by current `SwimScore`
- Explore nearby recommendations
- View lakes on a map
- Save favorites
- Inspect weather, health, and quality details
- Open routes in Apple Maps
- Optional tip jar via StoreKit

## Tech Stack

- Swift
- SwiftUI
- SwiftData
- MapKit
- CoreLocation
- StoreKit 2

## Data Sources

- AGES bathing-water data
- Open-Meteo weather data
- Apple Maps
- Wikipedia

## Project Structure

```text
ducky/
  Models/
  Services/
  Views/
  Assets.xcassets/
ducky.xcodeproj/
AGENTS.md
README.md
```

## Running Locally

Open `ducky.xcodeproj` in Xcode and run the `ducky` scheme.

CLI build:

```bash
xcodebuild -project ducky.xcodeproj -scheme ducky -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build
```

## Notes

- The product name is `Ducky`.
- The app is currently iOS-only.
- The repository currently has no open-source license attached.
- Maintainer and architecture documentation lives in `AGENTS.md`.
