# UI Tests Structure

## File Organization

| File | Area | Status |
|------|------|--------|
| `BibleGardenUITests.swift` | App launch | ✅ Exists |
| `MenuTests.swift` | Menu navigation | ✅ Exists (6 tests) |
| `Helpers/XCUIApplication+Helpers.swift` | Shared helpers | ✅ Exists |
| `SimpleReadingTests.swift` | Classic reading, audio, settings | 📝 Planned |
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

## SimpleReadingTests.swift

Тесты требуют работающий API (bibleapi.space) и сеть. Ряд тестов требует поддержки launch arguments в приложении (см. "Инфраструктура" ниже).

### Приоритеты

- **P0** — релиз-блокер: если падает при доступном API, релиз не выпускаем. При недоступном API — `XCTSkip`.
- **P1** — важная функциональность: если падает, исправляем до следующего релиза
- **P2** — глубокое покрытие: если падает, разбираемся в следующем спринте

### P0 — Базовая загрузка и отображение

| # | Тест | Что проверяет |
|---|------|---------------|
| 1 | `testReadPageLoadsText` | Переход через меню → WebView с текстом загрузился |
| 2 | `testReadPageShowsChapterTitle` | Заголовок (книга + глава) отображается в хедере |
| 3 | `testAudioPanelShowsAllControls` | Панель видна, все кнопки на месте: play/pause, prev/next chapter, prev/next verse, restart, speed |
| 4 | `testPlayAndPause` | Тап play → `read-playback-state.label` == "playing" → тап pause → label == "pausing" |
| 5 | `testNextChapter` | Тап next chapter → заголовок главы меняется |
| 6 | `testPrevChapter` | Тап prev chapter → заголовок главы меняется |
| 7 | `testChapterSelectAndNavigate` | Тап на заголовок → sheet → выбор другой главы → sheet закрывается → заголовок обновился *(детали OT/NT фильтра → ChapterSelectTests)* |
| 8 | `testSettingsOpenAndClose` | Тап шестерёнку → sheet с секциями language, translation, voice → закрытие |

### P0 — Ошибки и деградация

| # | Тест | Что проверяет |
|---|------|---------------|
| 9 | `testErrorStateOnLoadFailure` | ⚙️ `--force-load-error` → `read-error-text` виден |
| 10 | `testRetryAfterLoadError` | ⚙️ `--force-load-error-once` (one-shot: первая загрузка → ошибка, последующие → нормально) → `read-error-text` виден → pull-to-refresh → текст загрузился |
| 11 | `testNoAudioWarningAndDisabledControls` | ⚙️ `--force-no-audio` → `read-audio-warning` виден, кнопки play/restart/speed/verse `isEnabled == false` |

### P1 — Управление воспроизведением

| # | Тест | Что проверяет |
|---|------|---------------|
| 12 | `testSpeedCycleAndWrapAround` | Тапы по скорости: 1.0→1.2→...→2.0→0.6 (wrap-around). Проверка `read-speed-label` после каждого тапа |
| 13 | `testSeekSlider` | Перемотка `read-timeline-slider` в середину → `read-time-current` обновилось |
| 14 | `testAudioPanelCollapseAndExpand` | Тап `read-chevron` → кнопки play/speed не видны → тап `read-chevron` → видны обратно |
| 15 | `testPlayAdvancesVerseCounter` | Play → подождать ~5с → `read-verse-counter` или `read-time-current` изменились |
| 16 | `testNextVerseButton` | Во время play тап `read-next-verse` → `read-verse-counter` увеличился |
| 17 | `testRestartButton` | Во время play тап `read-restart` → `read-time-current` сбросилось к началу |

### P1 — Навигация по главам (граничные случаи)

| # | Тест | Что проверяет |
|---|------|---------------|
| 18 | `testFirstChapterPrevDisabled` | Перейти на Gen 1 → `read-prev-chapter.isEnabled == false` |
| 19 | `testLastChapterNextDisabled` | Перейти на Rev 22 → `read-next-chapter.isEnabled == false` |

### P1 — Настройки чтения

Тесты #21-#22 проверяют **визуальное состояние sheet** (локальный UI reset), не персист в settingsManager. Persist происходит только после выбора voice.

| # | Тест | Что проверяет |
|---|------|---------------|
| 20 | `testSettingsChangeTranslation` | Выбрать другой перевод → закрыть → текст/аудио обновились |
| 21 | `testSettingsLanguageResetsTranslationAndVoice` | В sheet: сменить язык → секции перевода/диктора показывают пустое/дефолтное значение |
| 22 | `testSettingsTranslationResetsVoice` | В sheet: сменить перевод → секция диктора показывает пустое значение |
| 23 | `testSettingsResetNotPersistedWithoutVoice` | Сменить язык в sheet → закрыть без выбора voice → переоткрыть → старые значения сохранились |
| 24 | `testSettingsPauseTypeControls` | Выбрать type=time → `settings-pause-duration` виден. type=full → скрыт. type=none → все контролы паузы скрыты |
| 25 | `testSettingsFontSizeControls` | Тап `settings-font-increase` → процент растёт, тап `settings-font-decrease` → уменьшается, тап `settings-font-reset` → 100% |

### P1 — Паузы (реальное поведение)

Тесты используют `read-playback-state` (debug-only скрытый label) для проверки состояния.

| # | Тест | Что проверяет |
|---|------|---------------|
| 26 | `testPauseTypeTimedBehavior` | pauseType=time, pauseBlock=verse → play → после стиха `read-playback-state` == "autopausing" → через N сек снова "playing" |
| 27 | `testPauseTypeFullBehavior` | pauseType=full, pauseBlock=verse → play → после стиха `read-playback-state` == "pausing" → остаётся "pausing" через 3с → ручной тап play → "playing" |

### P1 — Прогресс и авто-прогресс

| # | Тест | Что проверяет |
|---|------|---------------|
| 28 | `testMarkChapterReadAndUnread` | Тап `read-chapter-progress` → checkmark (прочитано) → тап снова → checkmark исчез (не прочитано) |
| 29 | `testAutoProgressOnAudioEnd` | Включить autoProgressAudioEnd → дослушать главу (скорость 2.0x) → глава автоматически отмечена прочитанной |
| 30 | `testAutoNextChapter` | Включить autoNextChapter → дослушать главу → `read-chapter-title` изменился (переход на следующую) |

### P1 — Аудио-информация

| # | Тест | Что проверяет |
|---|------|---------------|
| 31 | `testAudioInfoShowsTranslationAndVoice` | `read-translation-chip` и `read-voice-chip` содержат непустой текст |

### P2 — Глубокое покрытие

| # | Тест | Что проверяет |
|---|------|---------------|
| 32 | `testAutoProgressByReading` | ⚙️ `--reading-progress-seconds 3` → включить autoProgressByReading → доскроллить до конца → через ~3с глава отмечена |
| 33 | `testAutoProgressFrom90Percent` | Включить autoProgressFrom90Percent → прослушать ≥90% стихов (скорость 2.0x, короткая глава) → checkmark появился |
| 34 | `testPauseBlockParagraphVsVerse` | pauseBlock=paragraph → `read-playback-state` не переходит в "autopausing" после каждого стиха, только на границе абзаца |
| 35 | `testVoicePreviewPlayAndStop` | В настройках тап `settings-voice-preview-0` → превью играет → тап снова → остановка |
| 36 | `testSpeedPersistsAcrossChapters` | Скорость 1.5x → next chapter → `read-speed-label` всё ещё "x1.5" |
| 37 | `testFullReadingJourney` | E2E: открыть чтение → сменить translation/voice → play → дождаться autoNextChapter → в Progress глава отмечена |

---

### Prerequisite: реализация в приложении

Перед написанием тестов необходимо реализовать в коде приложения:

| Задача | Файл | Описание |
|--------|------|----------|
| Launch args обработка | `BibleGardenApp.swift` | `--uitesting` (reset UserDefaults), `--force-load-error`, `--force-load-error-once`, `--force-no-audio`, `--reading-progress-seconds N` |
| Debug playback state label | `PageReadView.swift` | Скрытый `Text(playbackStateName).accessibilityIdentifier("read-playback-state")` (только `#if DEBUG`). Значение через computed property: `switch audiopleer.state { case .playing: "playing", case .pausing: "pausing", ... }` — НЕ через `rawValue` (это Int) |
| `.disabled()` на prev/next chapter | `PageReadView.swift` | Добавить `.disabled(prevExcerpt.isEmpty)` и `.disabled(nextExcerpt.isEmpty)`. Кнопки play/restart/speed/verse уже имеют `.disabled(!hasAudio)` |
| Accessibility identifiers | `PageReadView.swift`, `PageReadSettingsView.swift` | Все новые identifiers из списка ниже |

### Инфраструктура тестов

#### Изоляция (launch arguments)

| Аргумент | Действие |
|----------|----------|
| `--uitesting` | Сбрасывает UserDefaults/прогресс перед запуском (чистое состояние) |
| `--force-load-error` | Симулирует ошибку загрузки главы, все запросы (#9) |
| `--force-load-error-once` | One-shot: первый запрос → ошибка, последующие → нормально (#10) |
| `--force-no-audio` | Симулирует отсутствие аудио (#11) |
| `--reading-progress-seconds N` | Переопределяет порог авто-прогресса по чтению (#32, по умолчанию до 60с) |

#### Архитектура тестового класса

Два класса для разделения зависимости от API:

```swift
// Базовый — для тестов, требующих живой API (#1-8, #12-37)
class SimpleReadingTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() async throws {
        try await super.setUp()
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        // Skip при недоступном API
        let (_, response) = try await URLSession.shared.data(
            from: URL(string: "https://bibleapi.space/health")!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw XCTSkip("API unavailable")
        }
        app.launch()
    }
}

// Для forced-error тестов (#9, #10, #11) — НЕ зависят от API
class SimpleReadingErrorTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() async throws {
        try await super.setUp()
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        // Без health check — тесты используют launch args для симуляции ошибок
    }
}
```

#### Стабильность и ожидания

- Все ожидания через `waitForExistence(timeout:)`, **никогда** `sleep()`
- Таймауты: 5с загрузка контента, 3с UI-переходы, 10с аудио-буферизация
- Тесты с реальным аудио (#15-17, #26-27, #29-30, #33) — потенциально flaky при медленной сети
- Проверка `isEnabled` вместо визуальных свойств (opacity/color) — менее хрупкие ассерты
- `read-playback-state` — единственный debug-only индикатор; остальные тесты опираются на стандартные accessibility properties

#### Разграничение с другими файлами

- **ChapterSelectTests**: детали OT/NT фильтрации, развёртывание книг, поиск — всё что внутри sheet выбора главы
- **ProgressTests**: отображение статистики, синхронизация прогресса между страницами
- **SimpleReadingTests**: всё что происходит на странице чтения + настройки чтения

---

### Accessibility identifiers

#### Уже существуют (PageReadView.swift):
- `read-chapter-title` — кнопка выбора главы (заголовок)
- `read-settings-button` — шестерёнка настроек
- `audio-panel` — контейнер аудио-панели
- `read-prev-chapter` — кнопка предыдущей главы
- `read-play-pause` — кнопка play/pause
- `read-next-chapter` — кнопка следующей главы

#### Уже существуют (PageReadSettingsView.swift):
- `setup-language-section` — секция языка
- `setup-translation-section` — секция перевода
- `setup-voice-section` — секция диктора

#### Нужно добавить (PageReadView.swift):
- `page-reading` — фон страницы
- `read-restart` — кнопка restart
- `read-prev-verse` — кнопка prev verse
- `read-next-verse` — кнопка next verse
- `read-speed` — кнопка скорости
- `read-speed-label` — текст текущей скорости (напр. "x1.0")
- `read-translation-chip` — чип текущего перевода
- `read-voice-chip` — чип текущего диктора
- `read-chapter-progress` — кружок прогресса (mark as read toggle)
- `read-verse-counter` — счётчик/номер текущего стиха
- `read-timeline-slider` — ползунок перемотки
- `read-time-current` — текущее время воспроизведения
- `read-time-total` — общее время
- `read-chevron` — кнопка сворачивания панели
- `read-error-text` — текст ошибки загрузки
- `read-audio-warning` — warning "нет аудио"
- `read-text-content` — WebView с текстом главы
- `read-playback-state` — DEBUG-only: `.accessibilityLabel` = строковое имя state (playing/pausing/autopausing/...) через computed property, **не** `rawValue` (который Int)

#### Нужно добавить (PageReadSettingsView.swift):
- `settings-close` — кнопка закрытия
- `settings-font-decrease` — кнопка уменьшить шрифт
- `settings-font-increase` — кнопка увеличить шрифт
- `settings-font-size` — текст текущего размера
- `settings-font-reset` — кнопка сброса шрифта
- `settings-pause-type` — picker типа паузы
- `settings-pause-duration` — контрол длительности паузы
- `settings-pause-block` — picker блока паузы
- `settings-auto-next` — toggle авто-перехода
- `settings-voice-preview-{index}` — кнопка превью голоса
