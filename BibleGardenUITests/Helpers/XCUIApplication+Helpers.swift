import XCTest

extension XCUIApplication {

    // MARK: - Menu

    /// Tap the hamburger button to open the side menu
    func openMenu() {
        let menuButton = buttons["menu-button"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5), "Menu button not found")
        menuButton.tap()

        let sideMenu = otherElements["side-menu"]
        XCTAssertTrue(sideMenu.waitForExistence(timeout: 3), "Side menu did not appear")
        XCTAssertTrue(waitForFrameToSettle(sideMenu, timeout: 5), "Side menu did not finish opening")
    }

    /// Tap a menu item by its accessibility identifier.
    /// The menu slides in with a spring animation; a tap that lands while it is
    /// still moving is cancelled by UIKit, so `openMenu` waits for the frame to settle.
    func tapMenuItem(_ identifier: String) {
        let item = buttons[identifier]
        XCTAssertTrue(waitForElementHittable(item, timeout: 3), "Menu item '\(identifier)' not hittable")
        item.tap()
    }

    /// Wait until the element's frame stops changing between two checks 0.2 s apart.
    func waitForFrameToSettle(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        var previous = element.frame
        while Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            let current = element.frame
            if current == previous { return true }
            previous = current
        }
        return false
    }

    /// Open menu and navigate to a page via menu item identifier
    func navigateViaMenu(to menuItemIdentifier: String) {
        openMenu()
        tapMenuItem(menuItemIdentifier)
    }

    // MARK: - Reading page

    /// Navigate to the classic reading page and wait for content to load
    func navigateToReadingPage() {
        navigateViaMenu(to: "menu-read")
        let title = buttons["read-chapter-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 8),
                      "Reading page chapter title should appear")
    }

    func waitForReadPlaybackState(_ state: String, timeout: TimeInterval = 10) -> Bool {
        let stateLabel = staticTexts["read-playback-state"]
        guard stateLabel.waitForExistence(timeout: 3) else { return false }
        return waitForLabel(element: stateLabel, toBe: state, timeout: timeout)
    }

    /// Wait until the classic reading audio is ready to play.
    ///
    /// Readiness is the `waitingForPlay` state. Terminal outcomes of the
    /// current load attempt end the wait early with "not ready": the audio
    /// failed (`error` state / the app's 15s buffering timeout) or the chapter
    /// request itself failed (`read-error-text`). The wait is event-based: it
    /// returns as soon as the state is published.
    ///
    /// Budget (30s) from measurements: excerpt request + duration probe took
    /// 1.5-2.2s on an idle API and ≤4.5s under parallel load; the slowest
    /// observed request of the sibling endpoint (book list) is >8s; the
    /// duration probe is bounded by the app's own 15s error timeout. 30s covers
    /// the worst successful composition (~10s request + 15s probe) without
    /// waiting through failures, which exit early.
    @discardableResult
    func waitForReadPlaybackReady(timeout: TimeInterval = 30) -> Bool {
        let stateLabel = staticTexts["read-playback-state"]
        guard stateLabel.waitForExistence(timeout: 5) else { return false }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let label = stateLabel.label
            if label == "waitingForPlay" { return true }
            if label == "error" || staticTexts["read-error-text"].exists { return false }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return false
    }

    func waitForReadHighlightedVerse(_ verseID: String, timeout: TimeInterval = 10) -> Bool {
        let webView = webViews.firstMatch
        if webView.waitForExistence(timeout: 3) {
            return waitForValue(element: webView, toBe: verseID, timeout: timeout)
        }

        let label = staticTexts["read-highlighted-verse-id"]
        guard label.waitForExistence(timeout: 3) else { return false }
        return waitForLabel(element: label, toBe: verseID, timeout: timeout)
    }

    func readHighlightedVerseID() -> String? {
        let webView = webViews.firstMatch
        if webView.waitForExistence(timeout: 3) {
            return webView.value as? String
        }

        let label = staticTexts["read-highlighted-verse-id"]
        guard label.waitForExistence(timeout: 3) else { return nil }
        return label.label
    }

    // MARK: - Settings sheet

    /// Wait until an accordion section of the reading settings sheet shows its
    /// option list. While the list is loading, the section contains only its
    /// header button, so the wait resolves the descendant button count until
    /// the options appear. Event-based: returns as soon as the count is reached.
    ///
    /// `minimumButtonCount` is 2 for "the list rendered at least one option";
    /// the caller keeps distinguishing data conditions (e.g. a single language)
    /// from the list not loading at all.
    ///
    /// Budget (20s) from measurements: the languages/translations lists render
    /// in 0.4-0.6s after the section is expanded on an idle API (the fetch
    /// starts when the sheet opens); the slowest observed request of the
    /// sibling endpoints under parallel load is >8s, so 20s covers it.
    @discardableResult
    func waitForSelectionSectionOptions(in section: XCUIElement,
                                        minimumButtonCount: Int,
                                        timeout: TimeInterval = 20) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if section.buttons.count >= minimumButtonCount { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return section.buttons.count >= minimumButtonCount
    }

    // MARK: - Text content

    /// Find the reading page text content (HTMLTextView wraps WKWebView,
    /// which shows up as `webViews` in XCUITest rather than `otherElements`)
    func waitForTextContent(timeout: TimeInterval = 10) -> XCUIElement? {
        let webView = webViews.firstMatch
        if webView.waitForExistence(timeout: timeout) {
            return webView
        }
        let other = otherElements["read-text-content"]
        if other.waitForExistence(timeout: 2) {
            return other
        }
        return nil
    }

    // MARK: - Waits

    /// Wait for an element to exist with a timeout, returns Bool
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        return element.waitForExistence(timeout: timeout)
    }

    /// Wait until the element both exists and is hittable.
    ///
    /// Existence alone does not mean the element can be tapped: an item of a
    /// lazy list may already exist but still sit below the fold until the
    /// initial scroll settles. The wait is event-based: it returns as soon as
    /// both conditions hold.
    @discardableResult
    func waitForElementHittable(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists && element.isHittable { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return element.exists && element.isHittable
    }

    /// Wait for an element's label to change from a known value
    func waitForLabelChange(element: XCUIElement, from oldLabel: String, timeout: TimeInterval = 10) -> Bool {
        pollElement(timeout: timeout) { element.exists && element.label != oldLabel }
    }

    /// Wait for an element's value to change from a known value
    func waitForValueChange(element: XCUIElement, from oldValue: String, timeout: TimeInterval = 10) -> Bool {
        pollElement(timeout: timeout) { element.exists && element.value as? String != oldValue }
    }

    /// Wait for an element's label to equal a specific value
    func waitForLabel(element: XCUIElement, toBe label: String, timeout: TimeInterval = 10) -> Bool {
        pollElement(timeout: timeout) { element.exists && element.label == label }
    }

    /// Wait for an element's value to equal a specific value
    func waitForValue(element: XCUIElement, toBe value: String, timeout: TimeInterval = 10) -> Bool {
        pollElement(timeout: timeout) { element.exists && element.value as? String == value }
    }

    /// Re-checks `condition` every 0.2 s until it holds or the timeout passes.
    /// `XCTNSPredicateExpectation` is not used here: after every failed
    /// evaluation it captures the element's debug description, which takes
    /// 5–30 s on a CI runner, so a state lasting a few seconds could be
    /// checked once and missed.
    private func pollElement(timeout: TimeInterval, until condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return condition()
    }

    // MARK: - Multilingual Reading Helpers

    func navigateToMultiSetupPage() {
        navigateViaMenu(to: "menu-multilingual")
        let setupPage = otherElements["page-multi-setup"]
        XCTAssertTrue(waitForElement(setupPage, timeout: 5), "Multi setup page did not appear")
    }

    func navigateToMultiReadingPage() {
        navigateViaMenu(to: "menu-multilingual")
        let readingPage = otherElements["page-multi-reading"]
        XCTAssertTrue(waitForElement(readingPage, timeout: 10), "Multi reading page did not appear")
    }

    func waitForMultiTextContent(timeout: TimeInterval = 15) -> XCUIElement? {
        let webView = webViews.firstMatch
        if webView.waitForExistence(timeout: timeout) { return webView }
        let other = otherElements["multi-text-content"]
        if other.waitForExistence(timeout: 2) { return other }
        return nil
    }

    func waitForMultiPlaybackState(_ state: String, timeout: TimeInterval = 10) -> Bool {
        let stateLabel = staticTexts["multi-playback-state"]
        guard stateLabel.waitForExistence(timeout: 3) else { return false }
        return waitForLabel(element: stateLabel, toBe: state, timeout: timeout)
    }

    func multiCurrentUnit() -> String? {
        let label = staticTexts["multi-current-unit"]
        guard label.waitForExistence(timeout: 3) else { return nil }
        return label.label
    }

    func multiCurrentStep() -> String? {
        let label = staticTexts["multi-current-step"]
        guard label.waitForExistence(timeout: 3) else { return nil }
        return label.label
    }

    func waitForDebugPlaybackCount(identifier: String, value: String, timeout: TimeInterval = 10) -> Bool {
        let label = staticTexts[identifier]
        guard label.waitForExistence(timeout: 3) else { return false }
        return waitForLabel(element: label, toBe: value, timeout: timeout)
    }

    func debugPlaybackCount(_ identifier: String) -> String? {
        let label = staticTexts[identifier]
        guard label.waitForExistence(timeout: 3) else { return nil }
        return label.label
    }

    // MARK: - Actual AVPlayer state (debug registry, только DEBUG-сборка)

    /// Разбирает опубликованный снимок телеметрии.
    /// nil — снимок не опубликован, нечитаем или содержит ошибку сериализации.
    private func debugTelemetrySnapshot() -> [String: Any]? {
        guard let raw = debugValue("debug-player-snapshot"),
              let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["error"] == nil else {
            return nil
        }
        return json
    }

    /// Фактическое состояние одного экземпляра AVPlayer из снимка телеметрии.
    struct DebugPlayerTelemetry {
        let id: String
        let owner: String
        let timeControlStatus: String
        /// nil — состояние экземпляра неизвестно.
        let isActuallyPlaying: Bool?
        let playingTransitionCount: Int
    }

    /// Агрегат по владельцу из снимка телеметрии.
    struct DebugOwnerTelemetry {
        /// Идентификаторы живых экземпляров. Пусто — экземпляров больше нет.
        let playerIds: [String]
        let timeControlStatus: String
        /// nil — есть экземпляр с неизвестным состоянием.
        let isActuallyPlaying: Bool?
        let playingTransitionCount: Int
    }

    /// Результат отладочной команды (детерминированная гонка #51).
    struct DebugPlaybackRaceResult {
        let executionId: String
        let status: String
        let phases: [String]
        let error: String?
        let actualTimeControlStatus: String
        let playingTransitionCountBefore: Int
        let playingTransitionCountAfter: Int
    }

    /// Фактическое состояние всех зарегистрированных экземпляров плееров.
    /// nil — телеметрия недоступна (это не значит «никто не играет»).
    func debugPlayersTelemetry() -> [DebugPlayerTelemetry]? {
        guard let json = debugTelemetrySnapshot(),
              let players = json["players"] as? [String: Any] else { return nil }
        var result: [DebugPlayerTelemetry] = []
        for (id, value) in players {
            guard let entry = value as? [String: Any],
                  let owner = entry["owner"] as? String,
                  let status = entry["timeControlStatus"] as? String,
                  let transitions = entry["playingTransitionCount"] as? Int else {
                return nil
            }
            // null или отсутствующее значение — состояние неизвестно:
            // это не то же самое, что «не играет».
            let isPlaying = entry["isActuallyPlaying"] as? Bool
            result.append(DebugPlayerTelemetry(id: id,
                                              owner: owner,
                                              timeControlStatus: status,
                                              isActuallyPlaying: isPlaying,
                                              playingTransitionCount: transitions))
        }
        return result
    }

    /// Агрегат по владельцу. nil — владельца нет в снимке (он не регистрировался)
    /// или данные нечитаемы.
    func debugOwnerTelemetry(forOwner owner: String) -> DebugOwnerTelemetry? {
        guard let json = debugTelemetrySnapshot(),
              let owners = json["owners"] as? [String: Any],
              let entry = owners[owner] as? [String: Any],
              let playerIds = entry["playerIds"] as? [String],
              let status = entry["timeControlStatus"] as? String,
              let transitions = entry["playingTransitionCount"] as? Int else {
            return nil
        }
        // null или отсутствующее значение — состояние неизвестно.
        let isPlaying = entry["isActuallyPlaying"] as? Bool
        return DebugOwnerTelemetry(playerIds: playerIds,
                                   timeControlStatus: status,
                                   isActuallyPlaying: isPlaying,
                                   playingTransitionCount: transitions)
    }

    /// У владельца не осталось живых экземпляров.
    /// Это отдельное состояние, его нельзя путать с паузой.
    func debugOwnerHasNoPlayers(forOwner owner: String) -> Bool {
        guard let telemetry = debugOwnerTelemetry(forOwner: owner) else { return false }
        return telemetry.playerIds.isEmpty
    }

    /// AVPlayer timeControlStatus владельца: "playing" / "paused" / "waitingToPlay"
    func debugPlayerTimeControlStatus(forOwner owner: String) -> String? {
        debugOwnerTelemetry(forOwner: owner)?.timeControlStatus
    }

    /// Играет ли AVPlayer владельца прямо сейчас (фактически, а не логически).
    /// nil — данных нет; это не равно «не играет».
    func debugPlayerIsActuallyPlaying(forOwner owner: String) -> Bool? {
        debugOwnerTelemetry(forOwner: owner)?.isActuallyPlaying
    }

    /// Сколько раз плеер владельца переходил в .playing.
    /// История переживает удаление экземпляра.
    func debugPlayingTransitionCount(forOwner owner: String) -> Int? {
        debugOwnerTelemetry(forOwner: owner)?.playingTransitionCount
    }

    /// Ждёт, пока AVPlayer владельца перейдёт в .playing не меньше `count` раз.
    /// Счётчик монотонный: короткое воспроизведение (стих ~5 с перед паузой)
    /// не проскакивает между опросами, как мгновенное состояние.
    func waitForPlayingTransitions(forOwner owner: String, atLeast count: Int, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        var lastKnown = "no telemetry"
        while Date() < deadline {
            if let current = debugPlayingTransitionCount(forOwner: owner) {
                lastKnown = "\(current)"
                if current >= count { return true }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTFail("The \(owner) AVPlayer should start playing at least \(count) times within \(Int(timeout))s, got '\(lastKnown)'")
        return false
    }

    /// Играет ли хотя бы один зарегистрированный экземпляр.
    /// nil — телеметрия недоступна или состояние экземпляра неизвестно:
    /// неизвестное не равно «не играет».
    func debugAnyPlayerIsActuallyPlaying() -> Bool? {
        guard let players = debugPlayersTelemetry() else { return nil }
        if players.contains(where: { $0.isActuallyPlaying == true }) { return true }
        if players.contains(where: { $0.isActuallyPlaying == nil }) { return nil }
        return false
    }

    /// Суммарное число переходов в .playing по всем владельцам.
    /// История публикуется независимо от наличия живых экземпляров.
    func debugTotalPlayingTransitionCount() -> Int? {
        guard let json = debugTelemetrySnapshot(),
              let owners = json["owners"] as? [String: Any] else { return nil }
        var total = 0
        for (_, value) in owners {
            guard let entry = value as? [String: Any],
                  let transitions = entry["playingTransitionCount"] as? Int else {
                return nil
            }
            total += transitions
        }
        return total
    }

    /// За интервал ни один экземпляр не перешёл в воспроизведение.
    ///
    /// `since` — счётчик переходов, зафиксированный ДО команды. Baseline,
    /// снятый внутри интервала, скрыл бы короткий запуск, который успел
    /// завершиться до его чтения, поэтому счётчик передаётся явно.
    @discardableResult
    func assertNoPlayerStartedPlaying(since baseline: Int, duration: TimeInterval, pollInterval: TimeInterval = 0.5) -> Bool {
        let deadline = Date().addingTimeInterval(duration)
        while Date() < deadline {
            guard let current = debugTotalPlayingTransitionCount() else {
                XCTFail("The playback telemetry is not available")
                return false
            }
            if current > baseline {
                XCTFail("Some AVPlayer started playing during the interval (transitions \(baseline) → \(current))")
                return false
            }
            RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
        }
        // Обязательное чтение после окончания интервала.
        guard let final = debugTotalPlayingTransitionCount() else {
            XCTFail("The playback telemetry is not available")
            return false
        }
        if final > baseline {
            XCTFail("Some AVPlayer started playing during the interval (transitions \(baseline) → \(final))")
            return false
        }
        return true
    }

    /// Фактическое состояние воспроизведения плеера владельца.
    /// Остановленный экземпляр и удалённый экземпляр — разные состояния:
    /// удаление проверяется отдельным условием, а не трактуется как пауза.
    enum DebugPlayerPlaybackState: String {
        /// AVPlayer играет.
        case playing
        /// Экземпляр жив, AVPlayer не играет.
        case stopped
        /// Экземпляр удалён — звука быть не может.
        case removed
        /// Телеметрия недоступна — неизвестные данные отвергаются.
        case unknown
    }

    func debugPlayerPlaybackState(forOwner owner: String) -> DebugPlayerPlaybackState {
        guard let telemetry = debugOwnerTelemetry(forOwner: owner) else {
            return .unknown
        }
        if telemetry.playerIds.isEmpty { return .removed }
        // Неизвестное состояние экземпляра — это не остановка.
        guard let isPlaying = telemetry.isActuallyPlaying else { return .unknown }
        return isPlaying ? .playing : .stopped
    }

    /// Дождаться конкретного состояния фактического воспроизведения.
    @discardableResult
    func waitForDebugPlayerPlaybackState(_ expected: DebugPlayerPlaybackState, forOwner owner: String, timeout: TimeInterval = 15) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        var lastKnown = DebugPlayerPlaybackState.unknown
        while Date() < deadline {
            let current = debugPlayerPlaybackState(forOwner: owner)
            lastKnown = current
            if current == expected { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTFail("The AVPlayer of '\(owner)' should be '\(expected.rawValue)' within \(Int(timeout))s, got '\(lastKnown.rawValue)'")
        return false
    }

    /// Дождаться, пока плеер владельца фактически не играет.
    /// Остановленный и удалённый экземпляр означают отсутствие звука;
    /// неизвестные данные отвергаются.
    @discardableResult
    func waitForDebugPlayerNotPlaying(forOwner owner: String, timeout: TimeInterval = 15) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        var lastKnown = DebugPlayerPlaybackState.unknown
        while Date() < deadline {
            let current = debugPlayerPlaybackState(forOwner: owner)
            lastKnown = current
            if current == .stopped || current == .removed { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTFail("The AVPlayer of '\(owner)' should not play within \(Int(timeout))s, got '\(lastKnown.rawValue)'")
        return false
    }

    /// За интервал фактически играет не более одного экземпляра
    /// (при owner != nil — только экземпляров этого владельца).
    @discardableResult
    func assertAtMostOnePlayerPlaying(owner: String? = nil, duration: TimeInterval, pollInterval: TimeInterval = 0.5) -> Bool {
        let deadline = Date().addingTimeInterval(duration)
        while Date() < deadline {
            guard let players = debugPlayersTelemetry() else {
                XCTFail("The playback telemetry is not available")
                return false
            }
            let scope = owner.map { target in players.filter { $0.owner == target } } ?? players
            let playing = scope.filter { $0.isActuallyPlaying == true }
            if playing.count > 1 {
                XCTFail("Several AVPlayers are playing at the same time: \(playing.map { $0.id }.joined(separator: ", "))")
                return false
            }
            RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
        }
        return true
    }

    /// Дождаться заданного timeControlStatus у AVPlayer владельца
    @discardableResult
    func waitForDebugPlayerTimeControlStatus(_ status: String, forOwner owner: String, timeout: TimeInterval = 20) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        var lastKnown = "no telemetry"
        while Date() < deadline {
            if let telemetry = debugOwnerTelemetry(forOwner: owner) {
                lastKnown = telemetry.timeControlStatus
                if telemetry.timeControlStatus == status { return true }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTFail("AVPlayer of '\(owner)' should be '\(status)' within \(Int(timeout))s, got '\(lastKnown)'")
        return false
    }

    /// Дождаться, пока AVPlayer владельца станет (не) играть фактически.
    /// Неизвестное состояние экземпляра не считается остановкой — ждём известного.
    @discardableResult
    func waitForDebugPlayerActuallyPlaying(_ isPlaying: Bool, forOwner owner: String, timeout: TimeInterval = 20) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        var lastKnown = "no telemetry"
        while Date() < deadline {
            if let telemetry = debugOwnerTelemetry(forOwner: owner) {
                switch telemetry.isActuallyPlaying {
                case .some(let value):
                    lastKnown = value ? "playing" : "not playing"
                    if value == isPlaying { return true }
                case .none:
                    lastKnown = "unknown"
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTFail("AVPlayer of '\(owner)' should be \(isPlaying ? "" : "not ")actually playing within \(Int(timeout))s, got '\(lastKnown)'")
        return false
    }

    /// Дождаться, пока экземпляры плеера владельца будут удалены.
    /// Отсутствие телеметрии владельца — это удаление, а не пауза.
    @discardableResult
    func waitForDebugPlayerRemoved(forOwner owner: String, timeout: TimeInterval = 20) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if debugOwnerHasNoPlayers(forOwner: owner) { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTFail("The player of '\(owner)' should be released within \(Int(timeout))s")
        return false
    }

    /// Ни один зарегистрированный экземпляр не играет фактически.
    /// Неизвестное состояние экземпляра проверку не удовлетворяет.
    @discardableResult
    func assertNoPlayerIsActuallyPlaying(_ message: String) -> Bool {
        guard let isPlaying = debugAnyPlayerIsActuallyPlaying() else {
            XCTFail("The playback telemetry is unavailable or its state is unknown — \(message)")
            return false
        }
        if isPlaying {
            XCTFail("Some AVPlayer is still playing — \(message)")
            return false
        }
        return true
    }

    /// Убедиться, что за интервал плеер владельца ни разу не начал играть.
    /// Проверяются фактическое состояние AVPlayer, счётчик переходов в .playing
    /// и идентичность экземпляров: пересоздание плеера обнуляет счётчик,
    /// поэтому такой случай — ошибка, а не «тишина».
    /// Неизвестное состояние экземпляра проверку не удовлетворяет.
    ///
    /// `upperBound` — счётчик переходов, зафиксированный ДО команды. Всё, что
    /// больше, означает запуск, случившийся в слепом окне между командой и
    /// чтением baseline внутри интервала.
    @discardableResult
    func assertDebugPlayerDidNotStartPlaying(forOwner owner: String,
                                             upperBound: Int? = nil,
                                             duration: TimeInterval,
                                             pollInterval: TimeInterval = 1.0) -> Bool {
        guard let baseline = debugOwnerTelemetry(forOwner: owner) else {
            XCTFail("No telemetry for '\(owner)' — the player instance is gone, that is not a pause")
            return false
        }
        guard !baseline.playerIds.isEmpty else {
            XCTFail("The player instance of '\(owner)' is gone — that is not a pause")
            return false
        }
        guard baseline.isActuallyPlaying == false else {
            XCTFail("The AVPlayer of '\(owner)' is \(baseline.isActuallyPlaying == true ? "already playing" : "of unknown state") before the pause interval")
            return false
        }
        let deadline = Date().addingTimeInterval(duration)
        while Date() < deadline {
            guard let current = debugOwnerTelemetry(forOwner: owner) else {
                XCTFail("The telemetry of '\(owner)' disappeared during the pause interval")
                return false
            }
            if let failure = debugPauseIntervalFailure(owner: owner, baseline: baseline, current: current, upperBound: upperBound) {
                XCTFail(failure)
                return false
            }
            RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
        }
        // Обязательное чтение после окончания интервала.
        guard let final = debugOwnerTelemetry(forOwner: owner) else {
            XCTFail("The telemetry of '\(owner)' disappeared at the end of the pause interval")
            return false
        }
        if let failure = debugPauseIntervalFailure(owner: owner, baseline: baseline, current: final, upperBound: upperBound) {
            XCTFail(failure)
            return false
        }
        return true
    }

    private func debugPauseIntervalFailure(owner: String,
                                           baseline: DebugOwnerTelemetry,
                                           current: DebugOwnerTelemetry,
                                           upperBound: Int?) -> String? {
        if current.isActuallyPlaying == true {
            return "The AVPlayer of '\(owner)' started playing during the pause interval"
        }
        if current.isActuallyPlaying == nil {
            return "The state of the AVPlayer of '\(owner)' is unknown — the pause interval cannot be verified"
        }
        if current.playingTransitionCount > baseline.playingTransitionCount {
            return "The AVPlayer of '\(owner)' started playing during the pause interval (transitions \(baseline.playingTransitionCount) → \(current.playingTransitionCount))"
        }
        if let upperBound, current.playingTransitionCount > upperBound {
            return "The AVPlayer of '\(owner)' started playing before the observation started (transitions \(upperBound) → \(current.playingTransitionCount))"
        }
        if current.playingTransitionCount < baseline.playingTransitionCount {
            return "The play-start history of '\(owner)' was reset during the pause interval (\(baseline.playingTransitionCount) → \(current.playingTransitionCount))"
        }
        if current.playerIds != baseline.playerIds {
            return "The player instance of '\(owner)' was replaced during the pause interval — the counter was reset"
        }
        return nil
    }

    /// Монотонный счётчик переходов пайплайна чтения.
    /// Индекс шага цикличен (шаг паузы встречается в каждом юните),
    /// поэтому «чтение продолжилось» проверяется по этому счётчику.
    func debugPipelineAdvanceCount() -> Int? {
        guard let json = debugTelemetrySnapshot() else { return nil }
        return json["pipelineAdvanceCount"] as? Int
    }

    /// Дождаться, пока пайплайн чтения перейдёт дальше указанного счётчика.
    @discardableResult
    func waitForDebugPipelineAdvanced(after count: Int, timeout: TimeInterval = 20) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        var lastKnown = "no telemetry"
        while Date() < deadline {
            if let current = debugPipelineAdvanceCount() {
                lastKnown = "\(current)"
                if current > count { return true }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTFail("The reading pipeline should advance beyond \(count), got '\(lastKnown)'")
        return false
    }

    // MARK: - Debug race command (#51)

    /// Разобранный результат отладочной команды. nil — результата нет или он нечитаем.
    func debugPlaybackRaceResult() -> DebugPlaybackRaceResult? {
        guard let raw = debugValue("debug-playback-race-result"),
              let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let executionId = json["executionId"] as? String,
              let status = json["status"] as? String,
              let phases = json["phases"] as? [String] else {
            return nil
        }
        return DebugPlaybackRaceResult(
            executionId: executionId,
            status: status,
            phases: phases,
            error: json["error"] as? String,
            actualTimeControlStatus: json["actualTimeControlStatus"] as? String ?? "unknown",
            playingTransitionCountBefore: json["playingTransitionCountBefore"] as? Int ?? 0,
            playingTransitionCountAfter: json["playingTransitionCountAfter"] as? Int ?? 0
        )
    }

    /// Дождаться завершения отладочной команды (гонка #51).
    @discardableResult
    func waitForDebugPlaybackRaceResult(timeout: TimeInterval = 30) -> DebugPlaybackRaceResult? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let result = debugPlaybackRaceResult(), result.status != "running" {
                return result
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTFail("The race command should publish its result within \(Int(timeout))s")
        return nil
    }

    // MARK: - Now Playing debug helpers

    /// Read a debug value published by the app
    func debugValue(_ identifier: String) -> String? {
        let label = staticTexts[identifier]
        guard label.waitForExistence(timeout: 3) else { return nil }
        return label.label
    }

    /// Wait for the owner of the Now Playing session ("none", "classicRead", "multilingualRead", "other")
    func waitForDebugNowPlayingOwner(_ owner: String, timeout: TimeInterval = 10) -> Bool {
        let label = staticTexts["debug-now-playing-owner"]
        guard label.waitForExistence(timeout: 3) else { return false }
        return waitForLabel(element: label, toBe: owner, timeout: timeout)
    }

    /// Wait for the presence of the Now Playing info
    func waitForDebugNowPlayingInfoPresent(_ isPresent: Bool, timeout: TimeInterval = 10) -> Bool {
        let label = staticTexts["debug-now-playing-info-present"]
        guard label.waitForExistence(timeout: 3) else { return false }
        return waitForLabel(element: label, toBe: isPresent ? "1" : "0", timeout: timeout)
    }

    /// Wait for the state of the play/pause commands of the lock screen / Control Center
    func waitForDebugRemoteCommandEnabled(_ isEnabled: Bool, timeout: TimeInterval = 10) -> Bool {
        let playLabel = staticTexts["debug-remote-play-enabled"]
        let pauseLabel = staticTexts["debug-remote-pause-enabled"]
        guard playLabel.waitForExistence(timeout: 3),
              pauseLabel.waitForExistence(timeout: 3) else { return false }
        let expected = isEnabled ? "1" : "0"
        return waitForLabel(element: playLabel, toBe: expected, timeout: timeout)
            && waitForLabel(element: pauseLabel, toBe: expected, timeout: timeout)
    }

    /// Wait for the status of the last remote transport command
    func waitForDebugRemoteCommandStatus(_ status: String, timeout: TimeInterval = 10) -> Bool {
        let label = staticTexts["debug-remote-command-status"]
        guard label.waitForExistence(timeout: 3) else { return false }
        return waitForLabel(element: label, toBe: status, timeout: timeout)
    }

    /// Wait until more remote transport commands were emulated than before
    @discardableResult
    func waitForDebugRemoteCommandCount(greaterThan count: Int, timeout: TimeInterval = 15) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let rawValue = debugValue("debug-remote-command-count"),
               let value = Int(rawValue),
               value > count {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTFail("The remote transport command should be handled within \(Int(timeout))s")
        return false
    }

    /// Emulate a remote transport command and wait until it was handled.
    /// Returns the status that the command handler reported.
    @discardableResult
    func sendDebugRemoteCommand(buttonIdentifier: String, timeout: TimeInterval = 15) -> String? {
        let button = buttons[buttonIdentifier]
        guard button.waitForExistence(timeout: 5) else {
            XCTFail("Debug remote command button '\(buttonIdentifier)' should exist")
            return nil
        }
        guard let rawCount = debugValue("debug-remote-command-count"),
              let handledBefore = Int(rawCount) else {
            XCTFail("The debug remote command counter should be published by the app")
            return nil
        }
        button.tap()
        guard waitForDebugRemoteCommandCount(greaterThan: handledBefore, timeout: timeout) else {
            return nil
        }
        return debugValue("debug-remote-command-status")
    }

    /// Wait until the state of the player that owns the Now Playing session
    /// reaches the given state.
    @discardableResult
    func waitForDebugNowPlayingState(_ state: String, timeout: TimeInterval = 15) -> Bool {
        let label = staticTexts["debug-now-playing-state"]
        guard label.waitForExistence(timeout: 3) else {
            XCTFail("The debug Now Playing state should be published by the app")
            return false
        }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if label.label == state { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTFail("The Now Playing state should become '\(state)' within \(Int(timeout))s, got '\(label.label)'")
        return false
    }

    /// Wait until the state of the player that owns the Now Playing session is
    /// not one of the given states (for example while a smooth pause is over).
    @discardableResult
    func waitForDebugNowPlayingState(excluding states: [String], timeout: TimeInterval = 15) -> Bool {
        let label = staticTexts["debug-now-playing-state"]
        guard label.waitForExistence(timeout: 3) else {
            XCTFail("The debug Now Playing state should be published by the app")
            return false
        }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !states.contains(label.label) { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTFail("The Now Playing state should leave \(states.joined(separator: ", ")) within \(Int(timeout))s, got '\(label.label)'")
        return false
    }

}

// MARK: - Multilingual navigation without a restart

extension XCUIApplication {

    /// Возврат к мультичтению без перезапуска приложения.
    /// Перезапуск убивает старые плееры и отложенные callback'и, а тест проверяет
    /// именно возврат в том же процессе.
    ///
    /// Проверяется первый открывшийся экран: если меню открыло сразу чтение,
    /// лишний уход в настройку не делается — он вызвал бы shutdownPlaybackPipeline()
    /// и стёр бы ошибочный автозапуск до проверок. Настройка используется только
    /// тогда, когда меню действительно открыло её.
    func returnToMultiReadingPageWithoutRestart() {
        navigateViaMenu(to: "menu-multilingual")

        let readingPage = otherElements["page-multi-reading"]
        let setupPage = otherElements["page-multi-setup"]

        if setupPage.waitForExistence(timeout: 5) {
            // Меню открыло настройку — идём оттуда к чтению.
            let saveAndRead = buttons["multilingual-save-and-read"]
            XCTAssertTrue(saveAndRead.waitForExistence(timeout: 5),
                          "Save and read button should exist")
            saveAndRead.tap()
            dismissSaveTemplateAlert()
        }

        XCTAssertTrue(readingPage.waitForExistence(timeout: 10),
                      "Multi reading page did not appear")
    }

    /// Диалог сохранения шаблона: читаем без сохранения.
    /// Кнопка выбирается строго по идентификатору: обе кнопки ведут к чтению,
    /// поэтому выбор по позиции или по переводу может остаться зелёным.
    private func dismissSaveTemplateAlert() {
        let alert = otherElements["multi-save-alert"]
        guard alert.waitForExistence(timeout: 5) else {
            XCTFail("The save template alert should appear")
            return
        }
        let skip = buttons["multi-save-alert-skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5),
                      "The 'read without saving' button should exist")
        skip.tap()
    }
}

// MARK: - Shared API Health Check

/// Проверяет доступность API с повторными попытками (до 3 раз).
/// URL берётся из TestConfig.baseURL (xcconfig → Info.plist).
/// Возвращает true, если сервер ответил HTTP-статусом.
func checkAPIAvailability(maxAttempts: Int = 3) -> Bool {
    let urlString = "\(TestConfig.baseURL)/api/languages"
    guard let url = URL(string: urlString) else { return false }
    for attempt in 1...maxAttempts {
        let semaphore = DispatchSemaphore(value: 0)
        var success = false
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "GET"
        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let http = response as? HTTPURLResponse {
                success = (200...499).contains(http.statusCode)
            }
            semaphore.signal()
        }.resume()
        _ = semaphore.wait(timeout: .now() + 15)
        if success { return true }
        if attempt < maxAttempts {
            Thread.sleep(forTimeInterval: 2)
        }
    }
    return false
}
