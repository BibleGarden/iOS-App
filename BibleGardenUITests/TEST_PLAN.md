# UI Tests Structure

## File Organization

| File | Area | What's tested |
|------|------|---------------|
| `BibleGardenUITests.swift` | Base | App launches successfully |
| `MainTests.swift` | Main screen | Cards, navigation from main |
| `MenuTests.swift` | Menu | Open/close menu, navigate to all sections |
| `SimpleReadingTests.swift` | Simple reading | Read page, audio panel, chapter navigation, reading settings |
| `ChapterSelectTests.swift` | Chapter selection | OT/NT filter, book expand/collapse, chapter pick |
| `MultiReadingTests.swift` | Multilingual reading | Setup, templates, multilingual read page |
| `ProgressTests.swift` | Progress | Progress screen, stats display |
| `AboutTests.swift` | About | About page, Telegram/website links |

## Helpers

| File | Purpose |
|------|---------|
| `Helpers/XCUIApplication+Helpers.swift` | Shared navigation helpers (open menu, go to page, wait for element) |

## Conventions

- Each file = one `XCTestCase` subclass
- Tests use `.accessibilityIdentifier()` for element lookup (not localized text)
- Helper methods avoid duplication of common navigation flows
