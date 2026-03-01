# UI Tests Structure

## File Organization

| File | Area | Status |
|------|------|--------|
| `BibleGardenUITests.swift` | App launch | ✅ Exists |
| `MenuTests.swift` | Menu navigation | ✅ Exists (6 tests) |
| `Helpers/XCUIApplication+Helpers.swift` | Shared helpers | ✅ Exists |
| `ClassicReadingTests.swift` | Classic reading, audio, settings, pauses | ✅ 40 tests, 7 classes — all pass |
| `MultiReadingTests.swift` | Multilingual setup + reading | ✅ 49 tests, 10 classes |
| `MainTests.swift` | Main screen cards | 📝 Planned |
| `ChapterSelectTests.swift` | OT/NT filter, book/chapter pick | 📝 Planned |
| `ProgressTests.swift` | Progress screen, stats | 📝 Planned |
| `AboutTests.swift` | About page, links | 📝 Planned |

## Conventions

- Each file = one `XCTestCase` subclass (или несколько для изоляции launch args)
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

Тесты требуют работающий API и сеть. Ряд тестов требует поддержки launch arguments в приложении (см. "Инфраструктура" ниже). Все тесты должны проходить — если что-то падает, чиним.

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

---

## MultiReadingTests.swift — Тест-план мультичтения

Тесты мультичтения охватывают две страницы:
1. **PageMultilingualSetupView** — настройка степов (read/pause), шаблонов, режимов чтения
2. **PageMultilingualReadView** — само чтение с аудио, навигация по юнитам/секциям/главам

Тесты требуют работающий API и сеть. Используют ту же инфраструктуру launch arguments что и ClassicReadingTests.

### Prerequisite: реализация в приложении ✅

| Задача | Файл | Статус |
|--------|------|--------|
| Accessibility identifiers для setup view | `PageMultilingualSetupView.swift` | ✅ Добавлено |
| Accessibility identifiers для reading view | `PageMultilingualReadView.swift` | ✅ Добавлено |
| Debug playback state label | `PageMultilingualReadView.swift` | ✅ `multi-playback-state` |
| Debug unit/step labels | `PageMultilingualReadView.swift` | ✅ `multi-current-unit`, `multi-current-step` (DEBUG-only) |
| Launch args: `--multi-template` | `AppDelegate.swift`, `advGlobals.swift` | ✅ Реализовано |
| Launch args: `--multi-unit` | `AppDelegate.swift`, `advGlobals.swift` | ✅ Реализовано |
| Launch args: `--force-load-error` в мультичтении | `PageMultilingualReadView.swift` | ✅ Добавлена обработка |
| Launch args: `--force-no-audio` в мультичтении | `PageMultilingualReadView.swift` | ✅ Добавлена обработка |
| Launch args: `--reading-progress-seconds` в мультичтении | `PageMultilingualReadView.swift` | ✅ Добавлена обработка |
| Save-alert accessibility identifiers | `PageMultilingualSetupView.swift` | ✅ Добавлено |

### Accessibility identifiers ✅

#### PageMultilingualSetupView.swift
- `page-multi-setup` — фон страницы ✅ (уже есть)
- `multi-setup-title` — заголовок страницы
- `multi-templates-button` — кнопка открытия шаблонов (books.vertical.fill)
- `multi-read-unit-picker` — picker режима чтения (verse/paragraph/fragment/chapter)
- `multi-add-read-step` — кнопка добавления read step
- `multi-add-pause-step` — кнопка добавления pause step
- `multilingual-save-and-read` — кнопка «Сохранить и читать» ✅ (уже есть)
- `multi-step-row-{index}` — строка степа (для tap/swipe)
- `multi-step-delete-{index}` — кнопка удаления степа (xmark)
- `multi-pause-minus-{index}` — кнопка уменьшить паузу
- `multi-pause-plus-{index}` — кнопка увеличить паузу
- `multi-error-message` — inline error message (если степов нет)
- `multi-save-alert` — overlay диалога сохранения шаблона
- `multi-save-alert-name-field` — TextField имени шаблона
- `multi-save-alert-save` — кнопка «Сохранить» в диалоге
- `multi-save-alert-skip` — кнопка «Не сохранять» в диалоге

#### PageMultilingualReadView.swift
- `page-multi-reading` — фон страницы ✅ (уже есть)
- `multi-chapter-title` — кнопка выбора главы (заголовок)
- `multi-config-button` — кнопка возврата к настройкам (gearshape.fill)
- `multi-text-content` — WebView с текстом
- `multi-prev-chapter` — кнопка предыдущей главы
- `multi-next-chapter` — кнопка следующей главы
- `multi-prev-unit` — кнопка предыдущего юнита (arrow.up.square)
- `multi-next-unit` — кнопка следующего юнита (arrow.down.square)
- `multi-prev-section` — кнопка предыдущей секции (arrow.turn.left.up)
- `multi-next-section` — кнопка следующей секции (arrow.turn.right.down)
- `multi-play-pause` — кнопка play/pause
- `multi-chevron` — кнопка сворачивания панели
- `multi-translation-chip` — чип текущего перевода
- `multi-voice-chip` — чип текущего диктора
- `multi-unit-counter` — счётчик "X of Y" юнитов
- `multi-chapter-progress` — кружок прогресса (mark as read toggle)
- `multi-error-text` — текст ошибки загрузки
- `multi-playback-state` — DEBUG-only: строковое имя state (playing/pausing/autopausing/...)
- `multi-current-unit` — DEBUG-only: `.accessibilityLabel` = "\(currentUnitIndex)" для детерминированной проверки навигации
- `multi-current-step` — DEBUG-only: `.accessibilityLabel` = "\(currentStepIndex)" для детерминированной проверки навигации
- `multi-stalled-indicator` — индикатор stalled/buffering

---

### Архитектура тестовых классов

8 классов для изоляции launch arguments и зависимостей:

```swift
// Основной — тесты Setup + Reading с живым API (секции A-F, I частично, N)
class MultiReadingTests: XCTestCase { ... }

// Forced-error/degradation тесты (секция K)
// --force-load-error: НЕ зависит от API
// --force-no-audio: зависит от API (текст грузится по сети, только аудио отключается)
class MultiReadingErrorTests: XCTestCase { ... }

// Граничные главы с --start-excerpt (секция G)
class MultiReadingBoundaryTests: XCTestCase { ... }

// Step-система с --multi-template two-langs (секция H)
class MultiReadingStepTests: XCTestCase { ... }

// Авто-прогресс по аудио с --auto-progress-audio-end (секция I, #41)
class MultiReadingAudioEndProgressTests: XCTestCase { ... }

// Авто-прогресс по чтению с --reading-progress-seconds (секция I, #42)
class MultiReadingAutoProgressTests: XCTestCase { ... }

// Режимы юнитов с --multi-unit (секция M)
class MultiReadingUnitModeTests: XCTestCase { ... }

// Фоновое воспроизведение (секция L)
class MultiReadingBackgroundTests: XCTestCase { ... }
```

---

### Launch arguments (новые, специфичные для мультичтения)

| Аргумент | Действие |
|----------|----------|
| `--multi-template <name>` | Загружает предустановленный шаблон мультичтения и сразу переходит на reading view (минует setup) |
| `--multi-unit <mode>` | Переопределяет multilingualReadUnit: `verse`, `paragraph`, `fragment`, `chapter` |

Шаблоны для тестов:
- `"default"` — один read step (русский, синодальный) → можно быстро тестировать reading view
- `"two-langs"` — read (ru) + pause (2s) + read (en) → тестирование multi-step flow

Существующие launch arguments (`--start-excerpt`, `--auto-progress-audio-end`) работают и для мультичтения.

**Не применимы** к мультичтению (до реализации соответствующей фичи):
- `--no-auto-next-chapter` — auto-next chapter в мультичтении не реализован

**⚠️ Требуют доработки** — следующие launch args обрабатываются только в PageReadView, нужно добавить обработку в PageMultilingualReadView:
- `--force-load-error` / `--force-load-error-once` — для тестов ошибок (секция K)
- `--force-no-audio` — для тестов деградации (секция K)
- `--reading-progress-seconds` — для тестов авто-прогресса (секция I, #42)

---

### A. Setup View — Настройка степов

| # | Тест | Что проверяет |
|---|------|---------------|
| 1 | `testSetupPageLoads` | Переход через меню → `page-multi-setup` виден, `multi-setup-title` exists |
| 2 | `testEmptyStateShowsHints` | При пустых степах → текст-подсказка с примером конфигурации (empty state view) |
| 3 | `testAddReadStepOpensConfig` | Тап `multi-add-read-step` → открывается sheet конфигурации (PageMultilingualConfigView) |
| 4 | `testAddPauseStep` | Тап `multi-add-pause-step` → в списке появляется строка с hourglass, дефолтная длительность 2с |
| 5 | `testPauseDurationControls` | Тап +/− на паузе → длительность меняется (1→2→3→2) |
| 6 | `testDeleteStep` | Тап xmark на степе → степ удаляется из списка |
| 7 | `testReadUnitPicker` | Тап на picker режима чтения → доступны все 4 варианта (verse/paragraph/fragment/chapter) |
| 8 | `testSaveAndReadWithoutSteps` | Тап «Сохранить и читать» без степов → inline error message виден |
| 9 | `testSaveAndReadTransitionsToReading` | Добавить read step + тап save → save-alert появляется (`multi-save-alert`) → тап «Не сохранять» (`multi-save-alert-skip`) → переход на `page-multi-reading` |
| 10 | `testConfigButtonReturnsToSetup` | Из reading view тап шестерёнку → возврат на `page-multi-setup` |

### B. Reading View — Загрузка и отображение

| # | Тест | Что проверяет |
|---|------|---------------|
| 11 | `testReadingPageLoadsText` | ⚙️ `--multi-template default` → `multi-text-content` WebView загрузился с текстом |
| 12 | `testReadingPageShowsChapterTitle` | Заголовок (книга + глава) отображается в хедере |
| 13 | `testAudioPanelShowsAllControls` | Панель видна, все 7 кнопок: prev/next chapter, prev/next unit, prev/next section, play/pause |
| 14 | `testTranslationAndVoiceChipsVisible` | `multi-translation-chip` и `multi-voice-chip` содержат непустой текст |
| 15 | `testUnitCounterVisible` | `multi-unit-counter` показывает "1 of N" (N > 0) |

### C. Reading View — Воспроизведение

| # | Тест | Что проверяет |
|---|------|---------------|
| 16 | `testPlayAndPause` | ⚙️ `--multi-template default` → тап play → `multi-playback-state` = "playing" → тап pause → "pausing" |
| 17 | `testPlayStartsFromHighlightedPosition` | Навигация `multi-next-unit` 2 раза → `multi-current-unit` = "2" → тап play → `multi-playback-state` = "playing", `multi-current-unit` всё ещё "2" (не сбросился в "0") |
| 18 | `testAudioPanelCollapseAndExpand` | Тап `multi-chevron` → кнопки play/unit не видны → тап снова → видны |

### D. Reading View — Навигация по главам

| # | Тест | Что проверяет |
|---|------|---------------|
| 19 | `testNextChapter` | ⚙️ `--multi-template default` → тап `multi-next-chapter` → заголовок меняется |
| 20 | `testPrevChapter` | Тап `multi-prev-chapter` → заголовок меняется |
| 21 | `testChapterSelectFromTitle` | Тап на `multi-chapter-title` → sheet выбора главы → закрытие |

### E. Reading View — Навигация по юнитам (arrow.up/down.square)

| # | Тест | Что проверяет |
|---|------|---------------|
| 22 | `testNextUnitHighlightsWithoutAudio` | ⚙️ `--multi-template default --multi-unit verse` → тап `multi-next-unit` → `multi-current-unit` label = "1", `multi-playback-state` != "playing" |
| 23 | `testPrevUnitHighlightsWithoutAudio` | После навигации вперёд → тап `multi-prev-unit` → `multi-current-unit` label вернулся к "0", аудио не стартует |
| 24 | `testUnitNavigationWhilePlaying` | Play → тап `multi-next-unit` → `multi-playback-state` остаётся "playing" (нет мерцания), `multi-current-unit` обновился |
| 25 | `testUnitCounterUpdates` | Навигация `multi-next-unit` несколько раз → `multi-unit-counter` обновляется (2 of N, 3 of N...) |
| 26 | `testFirstUnitPrevDisabled` | При `currentUnitIndex == 0` → `multi-prev-unit.isEnabled == false` |
| 27 | `testLastUnitNextDisabled` | При последнем юните → `multi-next-unit.isEnabled == false` |

### F. Reading View — Навигация по секциям (arrow.turn.left.up / arrow.turn.right.down)

| # | Тест | Что проверяет |
|---|------|---------------|
| 28 | `testNextSectionHighlightsWithoutAudio` | ⚙️ `--multi-template two-langs --multi-unit verse` → тап `multi-next-section` → `multi-current-step` label изменился, `multi-playback-state` != "playing" |
| 29 | `testPrevSectionHighlightsWithoutAudio` | После навигации вперёд → тап `multi-prev-section` → `multi-current-step` label вернулся |
| 30 | `testSectionNavigationCrossesUnitBoundary` | На последнем step текущего unit → тап `multi-next-section` → `multi-current-unit` увеличился |
| 31 | `testSectionNavigationWhilePlaying` | Play → тап `multi-next-section` → `multi-playback-state` остаётся "playing", `multi-current-step` обновился |
| 32 | `testSectionStartPrevDisabled` | На первом read step первого юнита → `multi-prev-section.isEnabled == false` |
| 33 | `testSectionEndNextDisabled` | На последнем read step последнего юнита → `multi-next-section.isEnabled == false` |

### G. Reading View — Граничные главы

| # | Тест | Что проверяет |
|---|------|---------------|
| 34 | `testFirstChapterPrevDisabled` | ⚙️ `--multi-template default --start-excerpt "gen 1"` → `multi-prev-chapter.isEnabled == false` |
| 35 | `testLastChapterNextDisabled` | ⚙️ `--multi-template default --start-excerpt "rev 22"` → `multi-next-chapter.isEnabled == false` |

### H. Reading View — Step-система (multi-translation flow)

| # | Тест | Что проверяет |
|---|------|---------------|
| 36 | `testMultiStepPlaythrough` | ⚙️ `--multi-template two-langs` → play → read(ru) → pause (hourglass icon) → read(en) → unit advance |
| 37 | `testPauseStepShowsHourglass` | Во время pause step → кнопка play/pause показывает hourglass icon |
| 38 | `testManualSkipPauseStep` | Во время pause step → тап play → пауза пропускается, переход к следующему read step |
| 39 | `testTranslationChipUpdatesPerStep` | ⚙️ `--multi-template two-langs` → play → `multi-translation-chip` отображает перевод первого step → после перехода на второй read step → чип обновляется |

### I. Reading View — Прогресс

| # | Тест | Что проверяет |
|---|------|---------------|
| 40 | `testMarkChapterReadAndUnread` | ⚙️ `--multi-template default` → тап `multi-chapter-progress` → прочитано → тап снова → не прочитано |
| 41 | `testAutoProgressOnAudioEnd` | ⚙️ `--multi-template default --auto-progress-audio-end --start-excerpt "psa 117"` → дослушать → глава отмечена |
| 42 | `testAutoProgressByReading` | ⚙️ `--multi-template default --reading-progress-seconds 3` → доскроллить до конца → через ~3с глава отмечена. **Prerequisite:** обработка `--reading-progress-seconds` в PageMultilingualReadView |

### J. Reading View — Авто-переход на следующую главу

> **⚠️ НЕ РЕАЛИЗОВАНО В КОДЕ.** В PageMultilingualReadView после окончания последнего юнита нет авто-перехода на следующую главу (в отличие от классического чтения). Тесты этой секции будут добавлены после реализации фичи — если она понадобится.

### K. Reading View — Ошибки и деградация

| # | Тест | Что проверяет |
|---|------|---------------|
| 43 | `testErrorStateOnLoadFailure` | ⚙️ `--multi-template default --force-load-error` → `multi-error-text` виден. **Prerequisite:** обработка `--force-load-error` в PageMultilingualReadView |
| 44 | `testNoAudioDisablesControls` | ⚙️ `--multi-template default --force-no-audio` → все navigation кнопки `isEnabled == false`, play disabled. **Prerequisite:** обработка `--force-no-audio` в PageMultilingualReadView |

### L. Reading View — Фоновое воспроизведение

| # | Тест | Что проверяет |
|---|------|---------------|
| 45 | `testBackgroundPlaybackContinues` | ⚙️ `--multi-template default` → play → home → 5 сек в фоне → activate → `multi-playback-state` != "finished" (стейт не сбросился) |

### M. Reading View — Режимы юнитов

| # | Тест | Что проверяет |
|---|------|---------------|
| 46 | `testVerseMode` | ⚙️ `--multi-template default --multi-unit verse` → `multi-unit-counter` показывает кол-во юнитов ≈ кол-ву стихов главы |
| 47 | `testParagraphMode` | ⚙️ `--multi-template default --multi-unit paragraph` → кол-во юнитов < кол-ва стихов (абзацы группируют) |
| 48 | `testChapterMode` | ⚙️ `--multi-template default --multi-unit chapter` → `multi-unit-counter` = "1 of 1" (вся глава = один юнит) |

### N. E2E

| # | Тест | Что проверяет |
|---|------|---------------|
| 49 | `testFullMultiReadingJourney` | Полный путь: setup → add steps → save-alert → reading → play → next unit → next chapter → mark read → config → return |

---

### Helpers (дополнения к XCUIApplication+Helpers.swift) ✅

```swift
extension XCUIApplication {
    /// Navigate to multilingual setup page via menu
    func navigateToMultiSetupPage() {
        navigateViaMenu(to: "menu-multilingual")
        let setupPage = otherElements["page-multi-setup"]
        XCTAssertTrue(waitForElement(setupPage, timeout: 5), "Setup page did not appear")
    }

    /// Wait for multilingual reading page to appear
    /// (requires --multi-template launch arg to skip setup)
    func waitForMultiReadingPage() {
        let readingPage = otherElements["page-multi-reading"]
        XCTAssertTrue(waitForElement(readingPage, timeout: 10), "Reading page did not appear")
    }

    /// Wait for multilingual playback state
    func waitForMultiPlaybackState(_ state: String, timeout: TimeInterval = 10) -> Bool {
        let stateLabel = staticTexts["multi-playback-state"]
        guard stateLabel.waitForExistence(timeout: 3) else { return false }
        return waitForLabel(element: stateLabel, toBe: state, timeout: timeout)
    }

    /// Get current unit index from debug label
    func multiCurrentUnit() -> String? {
        let label = staticTexts["multi-current-unit"]
        guard label.waitForExistence(timeout: 3) else { return nil }
        return label.label
    }

    /// Get current step index from debug label
    func multiCurrentStep() -> String? {
        let label = staticTexts["multi-current-step"]
        guard label.waitForExistence(timeout: 3) else { return nil }
        return label.label
    }
}
```

---

### Стабильность и ожидания

- Все ожидания через `waitForExistence(timeout:)` и `XCTNSPredicateExpectation`, **никогда** `sleep()`
- Таймауты: 10с загрузка контента (мультичтение грузит несколько переводов), 5с UI-переходы, 15с аудио-буферизация
- Тесты с реальным аудио (#16-17, #24, #31, #36-39, #41, #45) — потенциально flaky при медленной сети
- Проверка `isEnabled` вместо визуальных свойств (opacity/color) — менее хрупкие ассерты
- `multi-playback-state` — debug-only индикатор для проверки audio state
- Шаблоны `--multi-template` позволяют минуть setup view и сразу тестировать reading view

### Порядок реализации

1. **Фаза 1** — Prerequisite: accessibility identifiers, debug labels (`multi-playback-state`, `multi-current-unit`, `multi-current-step`), launch args (`--multi-template`, `--multi-unit`), save-alert id, обработка `--force-load-error` / `--force-no-audio` / `--reading-progress-seconds` в PageMultilingualReadView
2. **Фаза 2** — Setup tests (#1-#10): тесты конфигурации степов
3. **Фаза 3** — Core reading tests (#11-#21): загрузка, воспроизведение, навигация по главам
4. **Фаза 4** — Navigation tests (#22-#35): юниты, секции, граничные случаи
5. **Фаза 5** — Step/progress/error/background tests (#36-#48): step-система, прогресс, ошибки, фон, режимы юнитов
6. **Фаза 6** — E2E test (#49): полный путь пользователя
