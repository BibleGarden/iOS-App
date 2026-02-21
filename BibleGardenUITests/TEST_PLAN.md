# UI Tests Structure

## File Organization

| File | Area | Status |
|------|------|--------|
| `BibleGardenUITests.swift` | App launch | ✅ Exists |
| `MenuTests.swift` | Menu navigation | ✅ Exists (6 tests) |
| `Helpers/XCUIApplication+Helpers.swift` | Shared helpers | ✅ Exists |
| `ClassicReadingTests.swift` | Classic reading, audio, settings, pauses | ✅ 40 tests, 7 classes — all pass |
| `MainTests.swift` | Main screen cards | 📝 Planned |
| `ChapterSelectTests.swift` | OT/NT filter, book/chapter pick | 📝 Planned |
| `MultiReadingTests.swift` | Multilingual setup + reading | 📝 Planned |
| `ProgressTests.swift` | Progress screen, stats | 📝 Planned |
| `AboutTests.swift` | About page, links | 📝 Planned |

## Conventions

- Each file = one `XCTestCase` subclass
- Tests use `.accessibilityIdentifier()` for element lookup (not localized text)
- Helper methods avoid duplication of common navigation flows

---

## MenuTests.swift ✅

Готово, 6 тестов.

| # | Тест | Что проверяет |
|---|------|---------------|
| 1 | `testMenuOpensShowsAllItemsAndCloses` | Меню открывается, все 6 пунктов на месте, меню закрывается по тапу |
| 2 | `testNavigateToMultiReadingAndBack` | Переход на мультичтение → проверка highlight → возврат на главную |
| 3 | `testNavigateToClassicReadingAndBack` | Переход на классическое чтение → highlight → возврат |
| 4 | `testNavigateToProgressAndBack` | Переход на прогресс → highlight → возврат |
| 5 | `testLanguageSheetOpensAndCloses` | Открытие/закрытие sheet выбора языка |
| 6 | `testNavigateToAboutAndBack` | Переход на «О программе» → highlight → возврат |

---

## ClassicReadingTests.swift

Тесты требуют работающий API (bibleapi.space) и сеть. Ряд тестов требует поддержки launch arguments в приложении (см. "Инфраструктура" ниже). Все тесты должны проходить — если что-то падает, чиним.

### Загрузка и отображение

| # | Тест | Что проверяет |
|---|------|---------------|
| 1 | `testReadPageLoadsText` | Переход через меню → WebView с текстом загрузился |
| 2 | `testReadPageShowsChapterTitle` | Заголовок (книга + глава) отображается в хедере |
| 3 | `testAudioPanelShowsAllControls` | Панель видна, все кнопки на месте: play/pause, prev/next chapter, prev/next verse, restart, speed |
| 4 | `testAudioInfoShowsTranslationAndVoice` | `read-translation-chip` и `read-voice-chip` содержат непустой текст |

### Воспроизведение

| # | Тест | Что проверяет |
|---|------|---------------|
| 5 | `testPlayAndPause` | Тап play → "playing" → тап pause → "pausing" |
| 6 | `testSpeedCycleAndWrapAround` | Тапы по скорости: 1.0→1.2→...→2.0→0.6 (wrap-around) |
| 7 | `testSeekSlider` | Перемотка `read-timeline-slider` в середину → `read-time-current` обновилось |
| 8 | `testAudioPanelCollapseAndExpand` | Тап `read-chevron` → кнопки play/speed не видны → тап снова → видны |
| 9 | `testPlayAdvancesVerseCounter` | Play → подождать → `read-time-current` изменилось |
| 10 | `testNextVerseButton` | Во время play тап `read-next-verse` → `read-verse-counter` увеличился |
| 11 | `testRestartButton` | Во время play тап `read-restart` → `read-time-current` сбросилось к началу |
| 12 | `testSpeedPersistsAcrossChapters` | Скорость 1.4x → next chapter → скорость не сбросилась |

### Навигация по главам

| # | Тест | Что проверяет |
|---|------|---------------|
| 13 | `testNextChapter` | Тап next chapter → заголовок главы меняется |
| 14 | `testPrevChapter` | Тап prev chapter → заголовок главы меняется |
| 15 | `testChapterSelectAndNavigate` | Тап на заголовок → sheet с testament-selector → закрытие |
| 16 | `testFirstChapterPrevDisabled` | ⚙️ `--start-excerpt "gen 1"` → `read-prev-chapter.isEnabled == false` |
| 17 | `testLastChapterNextDisabled` | ⚙️ `--start-excerpt "rev 22"` → `read-next-chapter.isEnabled == false` |
| 18 | `testAutoNextChapter` | ⚙️ `--start-excerpt "psa 117"` → дослушать главу → заголовок сменился на следующую |
| 19 | `testNoAutoNextChapter` | ⚙️ `--no-auto-next-chapter` + `--start-excerpt "psa 117"` → дослушать → заголовок НЕ меняется |

### Паузы

Настройки пауз задаются через `--pause-type` / `--pause-block`. Состояние проверяется через `read-playback-state`.

| # | Тест | Что проверяет |
|---|------|---------------|
| 20 | `testPauseTimedVerse` | ⚙️ `--pause-type time --pause-block verse` → play → после стиха "autopausing" → авто-возобновление |
| 21 | `testPauseFullVerse` | ⚙️ `--pause-type full --pause-block verse` → play → после стиха "pausing" → не возобновляется |
| 22 | `testPauseTimedParagraph` | ⚙️ `--pause-type time --pause-block paragraph` → play на 2x → пауза только на границе абзаца |

### Настройки

Тесты #25-#27 проверяют визуальное состояние sheet (локальный UI reset). Persist происходит только после выбора voice.

| # | Тест | Что проверяет |
|---|------|---------------|
| 23 | `testSettingsOpenAndClose` | Тап шестерёнку → sheet с секциями language, translation, voice → закрытие |
| 24 | `testSettingsChangeTranslation` | Выбрать другой перевод и диктора → закрыть → чип перевода обновился |
| 25 | `testSettingsLanguageResetsTranslationAndVoice` | Сменить язык → секции перевода/диктора сбрасываются |
| 26 | `testSettingsTranslationResetsVoice` | Сменить перевод → секция диктора сбрасывается |
| 27 | `testSettingsResetNotPersistedWithoutVoice` | Сменить язык → закрыть без выбора voice → старые значения сохранились |
| 28 | `testSettingsPauseTypeControls` | Меню типа паузы открывается по тапу |
| 29 | `testSettingsFontSizeControls` | Тап +/− → процент шрифта меняется, reset → 100% |
| 30 | `testVoicePreviewPlayAndStop` | Тап превью голоса → играет → тап снова → остановка |

### Прогресс

| # | Тест | Что проверяет |
|---|------|---------------|
| 31 | `testMarkChapterReadAndUnread` | Тап `read-chapter-progress` → прочитано → тап снова → не прочитано |
| 32 | `testAutoProgressOnAudioEnd` | ⚙️ `--auto-progress-audio-end` + `--start-excerpt "psa 117"` → дослушать → глава отмечена |
| 33 | `testAutoProgressByReading` | ⚙️ `--reading-progress-seconds 3` → доскроллить до конца → через ~3с глава отмечена |

### Фоновое воспроизведение

| # | Тест | Что проверяет |
|---|------|---------------|
| 34 | `testBackgroundPlaybackContinues` | Play → home → 5 сек в фоне → activate → время увеличилось |
| 35 | `testPauseTimedVerseInBackground` | ⚙️ `--pause-type time --pause-block verse` → play → home → 10 сек → activate → время увеличилось |
| 36 | `testAutoNextChapterInBackground` | ⚙️ `--start-excerpt "psa 117"` → play на 2x → home → activate → заголовок сменился |

### Ошибки и деградация

| # | Тест | Что проверяет |
|---|------|---------------|
| 37 | `testErrorStateOnLoadFailure` | ⚙️ `--force-load-error` → `read-error-text` виден |
| 38 | `testRetryAfterLoadError` | ⚙️ `--force-load-error-once` → ошибка → pull-to-refresh → текст загрузился |
| 39 | `testNoAudioWarningAndDisabledControls` | ⚙️ `--force-no-audio` → кнопки play/restart/speed/verse `isEnabled == false` |

### E2E

| # | Тест | Что проверяет |
|---|------|---------------|
| 40 | `testFullReadingJourney` | Загрузка → play → next chapter → mark read → настройки → закрытие |

---

### Prerequisite: реализация в приложении ✅

Все prerequisite реализованы:

| Задача | Файл | Статус |
|--------|------|--------|
| Launch args обработка | `AppDelegate.swift`, `advGlobals.swift` | ✅ `--uitesting`, `--force-load-error`, `--force-load-error-once`, `--force-no-audio`, `--reading-progress-seconds N`, `--start-excerpt` |
| Debug playback state label | `PageReadView.swift` | ✅ `playbackStateName` computed property, `#if DEBUG` |
| `.disabled()` на prev/next chapter | `PageReadView.swift` | ✅ `.disabled(prevExcerpt.isEmpty)` / `.disabled(nextExcerpt.isEmpty)` |
| Accessibility identifiers | `PageReadView.swift`, `PageReadSettingsView.swift` | ✅ Все identifiers добавлены |

### Инфраструктура тестов

#### Изоляция (launch arguments)

| Аргумент | Действие |
|----------|----------|
| `--uitesting` | Сбрасывает UserDefaults/прогресс перед запуском (чистое состояние) |
| `--force-load-error` | Симулирует ошибку загрузки главы, все запросы (#37) |
| `--force-load-error-once` | One-shot: первый запрос → ошибка, последующие → нормально (#38) |
| `--force-no-audio` | Симулирует отсутствие аудио (#39) |
| `--start-excerpt <excerpt>` | Переопределяет начальный excerpt (напр. "gen 1", "rev 22") (#16, #17, #18, #19, #32, #36) |
| `--reading-progress-seconds N` | Переопределяет порог авто-прогресса по чтению (#33, по умолчанию до 60с) |
| `--auto-progress-audio-end` | Включает autoProgressAudioEnd + отключает autoNextChapter (#32) |
| `--no-auto-next-chapter` | Отключает autoNextChapter (#19) |
| `--pause-type <type>` | Переопределяет тип паузы: none/time/full (#20, #21, #22, #35) |
| `--pause-block <block>` | Переопределяет блок паузы: verse/paragraph/fragment (#20, #21, #22, #35) |

#### Архитектура тестового класса ✅

7 классов для разделения зависимостей:

```swift
// Основной — тесты с живым API (#1-15, #23-31, #34, #40)
class ClassicReadingTests: XCTestCase { ... }

// Forced-error тесты (#37, #38, #39) — НЕ зависят от API
class ClassicReadingErrorTests: XCTestCase { ... }

// Авто-прогресс по чтению с --reading-progress-seconds (#33)
class ClassicReadingAutoProgressTests: XCTestCase { ... }

// Граничные главы с --start-excerpt (#16, #17)
class ClassicReadingBoundaryTests: XCTestCase { ... }

// Авто-прогресс по аудио с --auto-progress-audio-end (#32)
class ClassicReadingAudioEndProgressTests: XCTestCase { ... }

// Автопереход с --start-excerpt (#18, #19, #36)
class ClassicReadingAutoNextTests: XCTestCase { ... }

// Паузы с --pause-type / --pause-block (#20, #21, #22, #35)
class ClassicReadingPauseTests: XCTestCase { ... }
```

#### Стабильность и ожидания

- Все ожидания через `waitForExistence(timeout:)`, **никогда** `sleep()`
- Таймауты: 5с загрузка контента, 3с UI-переходы, 10с аудио-буферизация
- Тесты с реальным аудио (#9-11, #18-22, #32, #35-36) — потенциально flaky при медленной сети
- Проверка `isEnabled` вместо визуальных свойств (opacity/color) — менее хрупкие ассерты
- `read-playback-state` — единственный debug-only индикатор; остальные тесты опираются на стандартные accessibility properties

#### Разграничение с другими файлами

- **ChapterSelectTests**: детали OT/NT фильтрации, развёртывание книг, поиск — всё что внутри sheet выбора главы
- **ProgressTests**: отображение статистики, синхронизация прогресса между страницами
- **ClassicReadingTests**: всё что происходит на странице чтения + настройки чтения

---

### Accessibility identifiers

#### PageReadView.swift ✅
- `read-chapter-title` — кнопка выбора главы (заголовок)
- `read-settings-button` — шестерёнка настроек
- `audio-panel` — контейнер аудио-панели
- `read-prev-chapter` — кнопка предыдущей главы
- `read-play-pause` — кнопка play/pause
- `read-next-chapter` — кнопка следующей главы
- `page-reading` — фон страницы
- `read-restart` — кнопка restart
- `read-prev-verse` — кнопка prev verse
- `read-next-verse` — кнопка next verse
- `read-speed` — кнопка скорости
- `read-translation-chip` — чип текущего перевода
- `read-voice-chip` — чип текущего диктора
- `read-chapter-progress` — кружок прогресса (mark as read toggle)
- `read-verse-counter` — счётчик/номер текущего стиха
- `read-timeline-slider` — ползунок перемотки
- `read-time-current` — текущее время воспроизведения
- `read-time-total` — общее время
- `read-chevron` — кнопка сворачивания панели
- `read-error-text` — текст ошибки загрузки
- `read-text-content` — WebView с текстом главы
- `read-playback-state` — DEBUG-only: `.accessibilityLabel` = строковое имя state (playing/pausing/autopausing/...) через computed property, **не** `rawValue` (который Int)

#### PageReadSettingsView.swift ✅
- `setup-language-section` — секция языка
- `setup-translation-section` — секция перевода
- `setup-voice-section` — секция диктора
- `settings-close` — кнопка закрытия
- `settings-font-decrease` — кнопка уменьшить шрифт
- `settings-font-increase` — кнопка увеличить шрифт
- `settings-font-size` — текст текущего размера
- `settings-font-reset` — кнопка сброса шрифта
- `settings-pause-type` — picker типа паузы
- `settings-voice-preview-{index}` — кнопка превью голоса
