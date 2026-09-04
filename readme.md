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

Automated UI test + screen recording + ffmpeg post-processing for App Store preview videos. Supports 3 languages (ru, en, uk). Uses `--demo-recording` flag for tap indicator overlay and `--app-language` to set the interface language.

```bash
# iPhone — all 3 languages (record + process)
./scripts/record-demo.sh

# iPhone — single language
./scripts/record-demo.sh --lang ru

# iPad — all 3 languages
./scripts/record-demo.sh --device ipad

# iPad — single language
./scripts/record-demo.sh --device ipad --lang en

# Re-process existing raw recordings
./scripts/record-demo.sh --process-only
./scripts/record-demo.sh --process-only --device ipad --lang en
```

Requires `ffmpeg` (`brew install ffmpeg`). Output: `demo_appstore_{device}_{lang}.mp4`. iPhone: 886×1920, iPad: 2048×2732. In `--process-only` mode, legacy iPhone recordings named `demo_raw_{lang}.mp4` and their original trim timings are also supported. Trim/speed constants are at the top of `scripts/record-demo.sh`. Test timings are in `BibleGardenUITests/DemoRecordingTests.swift`.

## OpenAPI Generation

The API client is auto-generated at build time from `Bible/openapi.yaml` using the Apple Swift OpenAPI Generator plugin (config: `Bible/openapi-generator-config.yml`).

References:
- [Swift OpenAPI Generator — Xcode tutorial](https://swiftpackageindex.com/apple/swift-openapi-generator/1.3.0/tutorials/swift-openapi-generator/clientxcode)
- [WWDC 2023 — Meet Swift OpenAPI Generator](https://developer.apple.com/videos/play/wwdc2023/10171/)
- [Export FastAPI OpenAPI spec](https://www.doctave.com/blog/python-export-fastapi-openapi-spec)
