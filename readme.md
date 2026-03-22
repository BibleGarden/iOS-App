# Bible Garden

An iOS app (SwiftUI) for listening to the Bible with configurable pauses between verses, paragraphs, or fragments. Supports multiple translations, languages (Russian, English, Ukrainian), and narrators. Key feature — multilingual reading: sequential playback of the same passage in different languages/translations.

## Project Setup

### Requirements

- Xcode (Swift 5, SwiftUI)
- iOS 15+ (iPhone + iPad)
- Dependencies are fetched automatically via Xcode SPM

### API Configuration (required before building)

API keys and URLs are set via xcconfig files, which are in `.gitignore`:

1. Copy the example files:
   ```bash
   cp Bible/Debug.xcconfig.example Bible/Debug.xcconfig
   cp Bible/Release.xcconfig.example Bible/Release.xcconfig
   ```

2. Replace `your-api-key-here` with your actual API key in each file.

3. `Debug.xcconfig` and `Release.xcconfig` are gitignored — never commit them.

### xcconfig Structure

- `Bible/Debug.xcconfig` — URL and key for the test API
- `Bible/Release.xcconfig` — URL and key for the production API

Values are injected via `Info.plist` → `Config.swift` (`Config.baseURL`, `Config.apiKey`).

## App Store Demo Video Recording

Automated UI test scenario for recording App Store preview videos. Uses `--demo-recording` flag which enables a tap indicator overlay — animated circles appear at touch points before each action.

```bash
# 1. Boot the simulator
xcrun simctl boot "iPhone 16 Pro"

# 2. Start screen recording
xcrun simctl io booted recordVideo ~/Desktop/demo.mp4

# 3. In another terminal, run the demo test
cd ~/Desktop/Dev/BiblePause
xcodebuild test \
  -scheme BibleGarden \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:BibleGardenUITests/DemoRecordingTests/testAppStoreDemo

# 4. Stop recording (Ctrl+C in the first terminal)
```

Timings are in `BibleGardenUITests/DemoRecordingTests.swift` — adjust `pause()` values to control pacing.

## OpenAPI Generation

The API client is auto-generated at build time from `Bible/openapi.yaml` using the Apple Swift OpenAPI Generator plugin (config: `Bible/openapi-generator-config.yml`).

References:
- [Swift OpenAPI Generator — Xcode tutorial](https://swiftpackageindex.com/apple/swift-openapi-generator/1.3.0/tutorials/swift-openapi-generator/clientxcode)
- [WWDC 2023 — Meet Swift OpenAPI Generator](https://developer.apple.com/videos/play/wwdc2023/10171/)
- [Export FastAPI OpenAPI spec](https://www.doctave.com/blog/python-export-fastapi-openapi-spec)
