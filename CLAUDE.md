# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BibleGarden (display name "Bible Garden") is an iOS SwiftUI app for listening to Bible audio with configurable pauses between verses/paragraphs. It supports multiple languages (Russian, English, Ukrainian), translations, and narrators. A key feature is "multilingual reading" — sequentially playing the same passage in different translations/languages.

## Build & Run

- **Xcode project**: `BibleGarden.xcodeproj` (no workspace, no CocoaPods)
- **Target**: `BibleGarden` → builds `BibleGarden.app`
- **Platform**: iOS (iPhone + iPad), Swift 5, SwiftUI
- **Dependencies**: Managed via Xcode SPM (not standalone Package.swift)
  - `swift-openapi-runtime`, `swift-openapi-urlsession`, `swift-openapi-generator`
- **UI tests**: `BibleGardenUITests` target (XCUITest). Tests require API availability and use `--uitesting` launch argument to reset UserDefaults. Pre-configured multilingual templates via `--multi-template` and `--multi-save-template` flags. No unit tests.

### Configuration (required before building)

API credentials are injected via xcconfig files that are **gitignored**:
- `Bible/Debug.xcconfig` — debug API URL + key
- `Bible/Release.xcconfig` — production API URL + key
- Example files: `Bible/Debug.xcconfig.example`, `Bible/Release.xcconfig.example`

These values surface through `Info.plist` → `Config.swift` (`Config.baseURL`, `Config.apiKey`).

### OpenAPI Client Generation

The API client is auto-generated from `Bible/openapi.yaml` using Apple's Swift OpenAPI Generator plugin (config: `Bible/openapi-generator-config.yml`). Generated types live under `Components.Schemas.*` and the client protocol is `APIProtocol`. Regeneration happens automatically via the Xcode build plugin.

## Architecture

### App Entry & Navigation

`BibleGardenApp` → `SkeletonView` (root view + navigation container). Navigation is **not** SwiftUI NavigationStack — it uses a `MenuItem` enum on `SettingsManager.selectedMenuItem` to switch between page views in a ZStack. A slide-out `MenuView` overlay controls navigation.

### Core Singleton: `SettingsManager`

`SettingsManager` (in `SkeletonView.swift`) is the central `ObservableObject` passed via `.environmentObject()`. It owns:
- The OpenAPI `client` (type `APIProtocol`) with API key auth via custom URLSession headers
- All user preferences (`@AppStorage` backed)
- Book/translation/language caching
- Reading progress (persisted to UserDefaults as JSON-encoded `ReadProgress`)
- Multilingual step configuration and templates
- Audio URL construction with API key injection

### Key Directories

```
Bible/
├── BibleGardenApp.swift      # @main entry point
├── SkeletonView.swift         # Root view, SettingsManager, navigation logic
├── MenuView.swift             # Slide-out menu, MenuItem enum
├── Config.swift               # API config from xcconfig/Info.plist
├── LocalizationManager.swift  # Runtime i18n (not system-based)
├── AppDelegate.swift
├── Pages/                     # All screen views (PageReadView, PageSelectView, etc.)
├── Models/
│   ├── Bible/                 # typeBible.swift (verse/note structs), advBible.swift (API calls)
│   └── MultilingualRead.swift # Multilingual step/template models
├── Adv/                       # Utilities and shared components
│   ├── advAudioManager.swift  # AVPlayer wrapper (PlayerModel) with verse-level tracking
│   ├── advSettings.swift      # PauseType, PauseBlock enums
│   ├── advElements.swift      # Reusable UI components
│   ├── advExcerpt.swift       # Excerpt parsing/display logic
│   ├── advGlobals.swift       # Global constants (padding, corner radius, Bible structure)
│   ├── advUtility.swift       # Utility helpers
│   ├── advExtensions.swift    # Swift extensions
│   ├── advCornerRadius.swift  # Custom corner radius modifier
│   └── advHTMLTextView.swift  # HTML rendering in SwiftUI
├── {ru,en,uk}.lproj/          # Localizable.strings per language
├── openapi.yaml               # API spec
└── openapi-generator-config.yml
```

### Audio Playback

`PlayerModel` (in `advAudioManager.swift`) wraps `AVPlayer` with:
- Verse-level boundary observers (start/end callbacks)
- Configurable auto-pause between verses (`breakForSeconds`)
- Smooth volume fade on manual pause
- Playback speed control (0.6x–2.0x)
- Lock screen / Control Center integration (MPNowPlayingInfoCenter)
- States: `waitingForSelection → buffering → waitingForPlay → playing → pausing/autopausing → finished/segmentFinished`

### Localization

Uses a custom `LocalizationManager` singleton (not Apple's standard localization). Strings use `"key".localized` extension. Three languages: ru, en, uk. The interface language can be changed at runtime without restarting the app.

### API Layer

All API calls go through the generated OpenAPI client on `SettingsManager.client`. The API key is sent as `X-API-Key` header. Audio URLs require an `api_key` query parameter (handled by `SettingsManager.audioURL(...)` helpers). 
