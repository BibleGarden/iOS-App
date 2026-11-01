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
- `BibleGarden/Debug.xcconfig` — test API URL + key
- `BibleGarden/Release.xcconfig` — production API URL + key
- Example files: `BibleGarden/Debug.xcconfig.example`, `BibleGarden/Release.xcconfig.example`

These values surface through `Info.plist` → `Config.swift` (`Config.baseURL`, `Config.apiKey`).

### CI

`.github/workflows/ui-tests.yml` runs the UI tests on every pull request and on push to `main` (GitHub-hosted `macos-26`, Xcode 26.3, iPhone 17 simulator with iOS 26.2):
- `BibleGarden/Debug.xcconfig` is written from `API_BASE_URL` in the workflow (`https://test-api.bible.garden`, the **test** Bible-API) and repository secret `API_KEY` of that server; production is never used by CI. `scripts/write-ci-debug-xcconfig.sh` writes it in the build job and in every test job, because `TestConfig` in the UI tests reads the same file at run time.
- The job fails before building when `GET /api/health` does not answer 200: the tests skip themselves without the API, so a run without this check would be green and prove nothing.
- Every macOS job boots the simulator first (`scripts/boot-ci-simulator.sh`): a fresh runner may still be loading simulator runtimes, so the step waits up to 5 minutes and fails with the runtime list if the device never appears.
- `build-for-testing` uses only the committed `Package.resolved`; `test-without-building` runs test plan `BibleGarden` without `DemoRecordingTests` (an App Store preview script, not a test).
- On failure `UITests.xcresult` is uploaded as an artifact; pass/fail/skip counts go to the job summary. Investigate the result bundle instead of re-running a red job.
- Pull requests from forks get no secrets, so their UI tests are skipped with a notice.

### OpenAPI Client Generation

The API client is auto-generated from `BibleGarden/openapi.yaml` using Apple's Swift OpenAPI Generator plugin (config: `BibleGarden/openapi-generator-config.yml`). Generated types live under `Components.Schemas.*` and the client protocol is `APIProtocol`. Regeneration happens automatically via the Xcode build plugin.

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
BibleGarden/
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
│   ├── advHTMLTextView.swift  # HTML rendering in SwiftUI
│   └── advTapIndicator.swift  # Tap overlay for demo recordings
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

### Scripture Search

`PageSearchView` is available from the home screen and the side menu. Its
`ScriptureSearchModel` lives in `SkeletonView`, preserving the query and results
when a passage is opened and the user returns. Search uses the generated
`search_scripture` operation (`POST /api/ai/scripture/search`) with the selected
language/translation and a limit of five. Its separate transport has a 45-second
timeout. Requests are submitted explicitly, cancelled on departure or query
changes, and never retried automatically. A 429 response uses `Retry-After`;
empty results and service failures have separate states.

Reading links use `passage` coordinates and the book alias from the selected
translation's book catalogue, preserving Psalm numbering. The existing reader
handles the resulting verse range, playback and missing audio. Responses remain
in memory and are not logged or persisted. The last five submitted queries are
kept on the device only (`UserDefaults` key `searchRecentQueries`) and shown on
the empty search screen; tapping one searches again. Clearing the field returns
to that screen. Withdrawing consent deletes the history.

The first search asks for versioned AI-processing consent; the information
button allows withdrawal. Debug consent identifies the test processors
(Cerebras, Google Gemini and llm.ai2.ru), verified through the test container configuration on
2026-10-25. Release copy follows the recorded production decision (Google Gemini
and the company server); verify it against deployment configuration before
release and update the public Bible Garden privacy policy in `Site`.

Search results require the API's `highlight` object and verse breakdown. Cards
initially show the 1–3 key verses using translation-native verse numbers. The
card is not a link: its "…" menu (also the long-press menu) holds every action.
"Show context" expands the full passage with surrounding verses dimmed. "Listen"
opens the reader on the full passage range and starts playback once the audio is
ready (`SettingsManager.playOnOpen`, consumed by `PageReadView`). "Read the
chapter" opens the whole chapter. "In several translations" opens multilingual
reading of the passage, or its setup first when no reading step exists. Both
readers then show `ReaderLeadingButton`, which returns to the preserved results
instead of opening the side menu. Copy and
share take the key verses with their reference and translation alias. While a
request runs, placeholder cards and a cancel control replace the results.
Automatic chapter continuation applies only when the API returns a whole chapter; a selected verse range stops at its
end even when the user's automatic chapter continuation setting is enabled.
Automatic progress also requires a whole chapter; reading or listening to a
bounded result cannot mark the entire chapter read. Manual marking is retained.
Invalid highlight boundaries produce
an explicit response error. The test API added this contract on 2026-10-25
(Bible-API PR #40, commit 81a6c94); the model rerank now uses Google Gemini,
so the test consent version changed to require a fresh choice.

UI approval precedes new search UI tests. At the interface-preview stage, no
search tests or production release are claimed.
