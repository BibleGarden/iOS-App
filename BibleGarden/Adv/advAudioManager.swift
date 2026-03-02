import AVFoundation
import Combine
import MediaPlayer

// MARK: PlayerTimeObserver

class PlayerTimeObserver {
    let publisher = PassthroughSubject<TimeInterval, Never>()
    private weak var player: AVPlayer?
    private var timeObservation: Any?
    private var paused = false
    
    init(player: AVPlayer) {
        self.player = player
        
        // Periodically observe the player's current time, whilst playing
        timeObservation = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.2, preferredTimescale: 600), queue: nil) { [weak self] time in
            guard let self = self else { return }
            // If we've not been told to pause our updates
            guard !self.paused else { return }
            // Only publish time when player is actually playing (not stalled/buffering)
            guard self.player?.timeControlStatus == .playing else { return }
            self.publisher.send(time.seconds)
        }
    }
    
    deinit {
        if let player = player,
            let observer = timeObservation {
            player.removeTimeObserver(observer)
        }
    }
    
    func pause(_ pause: Bool) {
        paused = pause
    }
    
    
}

// MARK: PlayerDurationObserver

class PlayerDurationObserver {
   let publisher = PassthroughSubject<TimeInterval, Never>()
   private var cancellable: AnyCancellable?
   
   init(player: AVPlayer) {
       let durationKeyPath: KeyPath<AVPlayer, CMTime?> = \.currentItem?.duration
       cancellable = player.publisher(for: durationKeyPath).sink { duration in
           guard let duration = duration else { return }
           guard duration.isNumeric else { return }
           self.publisher.send(duration.seconds)
       }
   }
   
   deinit {
       cancellable?.cancel()
   }
}


// MARK: PlayerModel

class PlayerModel: ObservableObject {
    
    enum PlaybackState: Int {
        case waitingForSelection
        case waitingForPlay
        case waitingForPause
        case buffering
        case playing
        case pausing
        case autopausing
        case finished
        case segmentFinished
        case error
    }
    
    private let player: AVPlayer
    private let durationObserver: PlayerDurationObserver
    private var timeObserver: PlayerTimeObserver
    private var boundaryObserverBegin: Any?
    private var boundaryObserverEnd: Any?
    private var endPlayingObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    
    @Published var state = PlaybackState.waitingForSelection
    @Published var periodFrom: Double = 0
    @Published var periodTo: Double = 0
    @Published var currentDuration: TimeInterval = 0
    @Published var currentTime: TimeInterval = 0
    @Published private(set) var currentSpeed: Float = 1.0
    @Published var errorMessage: String? = nil
    @Published var isStalled: Bool = false
    @Published var isBufferingLong: Bool = false
    
    private var oldState = PlaybackState.waitingForSelection
    private var audioVerses: [BibleAcousticalVerseFull] = []
    private var currentVerseIndex: Int = -1
    private var stopAtEnd = true
    
    var onStartVerse: ((Int) -> Void)?
    var onEndVerse: (() -> Void)?
    var smoothPauseLength = 0.3
    
    private var pauseTimer: Timer?
    private var bufferingTimeoutWork: DispatchWorkItem?
    private var bufferingIndicatorWork: DispatchWorkItem?
    private var stalledSetWork: DispatchWorkItem?
    private var currentItemURL: URL?

    private var itemTitle: String = ""
    private var itemSubtitle: String = ""
    
    // MARK: init
    init() {
        
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
        
        self.player = AVPlayer()
        self.durationObserver = PlayerDurationObserver(player: self.player)
        self.timeObserver = PlayerTimeObserver(player: self.player)
        
        self.setupNowPlaying()
        self.setupRemoteTransportControls()
        
        // Observe when media duration becomes available
        durationObserver.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] duration in
                self?.currentDuration = duration
                
                if self?.state == .buffering {
                    self?.bufferingTimeoutWork?.cancel()
                    self?.bufferingIndicatorWork?.cancel()
                    self?.isStalled = false
                    self?.isBufferingLong = false
                    self?.state = .waitingForPlay
                    self?.player.seek(to: CMTimeMake(value: Int64(self!.periodFrom*100), timescale: 100))
                    self?.currentTime = self?.periodFrom ?? 0
                    self?.findAndSetCurrentVerseIndex()
                }
                
                // Disable internal auto-play to avoid race conditions with View logic
                // if self?.oldState == .playing {
                //     self?.playSimple()
                // }
                
            }
            .store(in: &cancellables)
        
        // Subscribe to interruption notifications
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())
            
        // Observe position changes
        timeObserver.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in
                self?.currentTime = time
            }
            .store(in: &cancellables)
        
        // Example subscription to track completion
        endPlayingObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            // Verify this notification is for the CURRENT item
            guard let item = notification.object as? AVPlayerItem, item == self.player.currentItem else {
                 return
            }

            // Update state and perform cleanup when track reaches the end
            self.state = .finished
        }

        // Observe AVPlayerItem status to detect loading failures (network errors, invalid URLs)
        player.publisher(for: \.currentItem?.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                if status == .failed {
                    self.bufferingTimeoutWork?.cancel()
                    self.state = .error
                    self.errorMessage = self.player.currentItem?.error?.localizedDescription
                        ?? "error.loading.audio".localized
                }
            }
            .store(in: &cancellables)

        // Observe timeControlStatus to detect real buffering after playback started
        player.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                if status == .waitingToPlayAtSpecifiedRate && self.state == .playing {
                    // Delay showing stalled indicator — brief waits during seeks are normal,
                    // only show indicator if stall persists for 0.5s
                    self.stalledSetWork?.cancel()
                    let setWork = DispatchWorkItem { [weak self] in
                        guard let self = self,
                              self.player.timeControlStatus == .waitingToPlayAtSpecifiedRate,
                              self.state == .playing else { return }
                        self.isStalled = true
                    }
                    self.stalledSetWork = setWork
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: setWork)
                } else if status == .playing {
                    // Immediately clear stalled indicator when audio resumes
                    self.stalledSetWork?.cancel()
                    self.isStalled = false
                }
            }
            .store(in: &cancellables)
    }
    
    deinit {
        // Important: remove observers to avoid leaks
        if let endPlayingObserver = endPlayingObserver {
            NotificationCenter.default.removeObserver(endPlayingObserver)
        }
        bufferingTimeoutWork?.cancel()
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        if type == .began {
            // Interruption began, pause playback
            pauseSimple()
        } else if type == .ended {
            // Interruption ended, resume playback if allowed
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    playSimple()
                }
            }
        }
    }
    
    private func setupNowPlaying() {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = itemTitle
        nowPlayingInfo[MPMediaItemPropertyArtist] = itemSubtitle
        // Add extra metadata if needed
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] event in
            self?.playSimple()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] event in
            self?.pauseSimple()
            return .success
        }
        
        // Add other commands if needed
    }

    // MARK: Set up new track parameters
    func setItem(playerItem: AVPlayerItem, periodFrom: Double, periodTo: Double, audioVerses: [BibleAcousticalVerseFull], itemTitle: String, itemSubtitle: String) {

        // If the same item is already loaded — just seek, no re-buffering
        if player.currentItem === playerItem {
            seekToSegment(periodFrom: periodFrom, periodTo: periodTo, audioVerses: audioVerses, itemTitle: itemTitle, itemSubtitle: itemSubtitle)
            return
        }

        self.oldState = self.state
        if self.state == .playing {
            self.pauseSimple()
        }

        // Store URL for retry capability
        self.currentItemURL = (playerItem.asset as? AVURLAsset)?.url

        self.periodFrom = periodFrom
        self.periodTo = periodTo

        self.audioVerses = audioVerses
        self.currentVerseIndex = -1

        // Clear previous error/buffering state
        self.errorMessage = nil
        self.isStalled = false
        self.isBufferingLong = false
        self.bufferingTimeoutWork?.cancel()
        self.bufferingIndicatorWork?.cancel()
        self.stalledSetWork?.cancel()

        // Force state change to ensure observers are notified (even if already buffering)
        self.state = .waitingForSelection
        self.state = .buffering
        self.currentTime = 0
        self.currentDuration = 0

        self.deleteObservation()
        self.setObservation()

        self.itemTitle = itemTitle
        self.itemSubtitle = itemSubtitle
        self.setupNowPlaying()

        self.player.replaceCurrentItem(with: playerItem)

        // Start buffering timeout — if duration doesn't arrive within 15s, report error
        let timeoutWork = DispatchWorkItem { [weak self] in
            guard let self = self, self.state == .buffering else { return }
            self.state = .error
            self.errorMessage = "error.audio.timeout".localized
        }
        self.bufferingTimeoutWork = timeoutWork
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: timeoutWork)

        // Show buffering indicator only after a brief delay (avoid flashes on quick transitions)
        let indicatorWork = DispatchWorkItem { [weak self] in
            guard let self = self, self.state == .buffering else { return }
            self.isBufferingLong = true
        }
        self.bufferingIndicatorWork = indicatorWork
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: indicatorWork)
    }

    /// Fast seek within an already-loaded player item. Skips buffering phase entirely —
    /// just updates verse boundaries, seeks, and signals readiness to play.
    func seekToSegment(periodFrom: Double, periodTo: Double, audioVerses: [BibleAcousticalVerseFull], itemTitle: String, itemSubtitle: String) {
        if self.state == .playing {
            self.player.pause()
        }

        self.periodFrom = periodFrom
        self.periodTo = periodTo
        self.audioVerses = audioVerses
        self.currentVerseIndex = -1
        self.stopAtEnd = true

        self.errorMessage = nil
        self.isStalled = false
        self.isBufferingLong = false
        self.bufferingTimeoutWork?.cancel()
        self.bufferingIndicatorWork?.cancel()
        self.stalledSetWork?.cancel()

        self.deleteObservation()
        self.setObservation()

        self.itemTitle = itemTitle
        self.itemSubtitle = itemSubtitle
        self.setupNowPlaying()

        // Show buffering indicator if seek takes longer than 0.1s (slow network / unbuffered region)
        let indicatorWork = DispatchWorkItem { [weak self] in
            self?.isBufferingLong = true
        }
        self.bufferingIndicatorWork = indicatorWork
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: indicatorWork)

        // Seek first, then signal readiness — avoids brief .waitingToPlayAtSpecifiedRate
        // that would trigger the stalled indicator
        self.player.seek(to: CMTimeMake(value: Int64(periodFrom * 100), timescale: 100)) { [weak self] finished in
            guard let self = self, finished else { return }
            self.bufferingIndicatorWork?.cancel()
            self.isBufferingLong = false
            self.currentTime = periodFrom
            self.findAndSetCurrentVerseIndex()
            self.state = .waitingForPlay
        }
    }

    /// Retry loading audio from the same URL (after a network error)
    func retry() {
        guard state == .error, let url = currentItemURL else { return }
        let newItem = AVPlayerItem(url: url)
        setItem(playerItem: newItem, periodFrom: periodFrom, periodTo: periodTo,
                audioVerses: audioVerses, itemTitle: itemTitle, itemSubtitle: itemSubtitle)
    }

    // Remove previous observers if needed
    private func deleteObservation() {
        if let observerBegin = boundaryObserverBegin {
            player.removeTimeObserver(observerBegin)
            self.boundaryObserverBegin = nil
        }
        if let observerEnd = boundaryObserverEnd {
            player.removeTimeObserver(observerEnd)
            self.boundaryObserverEnd = nil
        }
    }
    
    private func setObservation() {
        // Build time arrays
        var timesBegin: [NSValue] = []
        var timesEnd: [NSValue] = []
        
        for verse in audioVerses {
            let verseBeginTime = CMTime(seconds: verse.begin, preferredTimescale: 10)
            timesBegin.append(NSValue(time: verseBeginTime))
            let verseEndTime = CMTime(seconds: verse.end, preferredTimescale: 10)
            timesEnd.append(NSValue(time: verseEndTime))
        }
        
        // Observe verse start to position playback
        boundaryObserverBegin = player.addBoundaryTimeObserver(forTimes: timesBegin, queue: .main) {
            self.currentTime = CMTimeGetSeconds(self.player.currentTime())
            self.findAndSetCurrentVerseIndex()
        }
        
        // Observe verse end to trigger pauses
        boundaryObserverEnd = player.addBoundaryTimeObserver(forTimes: timesEnd, queue: .main) {
            // Stop when excerpt end is reached
            if self.stopAtEnd && self.currentVerseIndex == self.audioVerses.count - 1 {
                self.player.pause()
                self.state = .segmentFinished
            }
            // Skip end-of-verse event on last verse (prevents extra pauses and layout glitches)
            else if self.currentVerseIndex != self.audioVerses.count - 1 {
                self.onEndVerse?()
            }
        }
    }
    
    // Find verse that matches current position
    private func findAndSetCurrentVerseIndex() {
        for (index, verse) in audioVerses.enumerated() {
            // +0.1 because positioning is not exact and may trigger earlier
            if currentTime + 0.1 >= verse.begin && currentTime + 0.1 <= verse.end {
                if index != currentVerseIndex {
                }
                
                setCurrentVerseIndex(index)
                break
            }
        }
    }
    
    private func setCurrentVerseIndex(_ cur: Int) {
        if cur != self.currentVerseIndex {
            self.currentVerseIndex = cur
            self.onStartVerse?(cur)
        }
    }
    
    /// Immediately stop playback (used before chapter switch to prevent old audio leaking)
    func stop() {
        player.pause()
        if state == .playing || state == .buffering || state == .autopausing {
            state = .pausing
        }
        isStalled = false
        isBufferingLong = false
        bufferingTimeoutWork?.cancel()
        bufferingIndicatorWork?.cancel()
        stalledSetWork?.cancel()
    }

    // MARK: Play/Pause handling
    func doPlayOrPause() {
        if self.state == .playing {
            let safeDuration = calculateSafeSmoothPauseDuration()
            pauseSmoothly(duration: safeDuration)
        }
        else if state == .buffering {
            // Do nothing while buffering
        }
        else if state == .error {
            retry()
        }
        else if state == .finished {
            self.restart()
            self.playSimple()
        }
        else {
            // If playback starts after excerpt end, don't stop automatically anymore
            if self.currentTime >= self.periodTo {
                self.stopAtEnd = false
            }
            self.playSimple()
        }
    }
    
    private func playSimple() {
        self.player.play()
        self.state = .playing
        self.isBufferingLong = false
    }
    
    private func pauseSimple() {
        self.player.pause()
        self.state = .pausing
    }
    
    // Calculate safe duration for smooth pause to avoid overlapping with next verse
    private func calculateSafeSmoothPauseDuration() -> TimeInterval {
        // If no smooth pause is set, return 0
        guard smoothPauseLength > 0 else { return 0 }
        
        // Find current verse and check distance to next verse
        let currentTime = CMTimeGetSeconds(player.currentTime())
        var distanceToNextVerse: Double = smoothPauseLength // default to full smooth pause length
        
        // Find current verse index based on current time
        for (index, verse) in audioVerses.enumerated() {
            if currentTime >= verse.begin && currentTime <= verse.end {
                // Check if there's a next verse
                if index + 1 < audioVerses.count {
                    let nextVerseBegin = audioVerses[index + 1].begin
                    distanceToNextVerse = nextVerseBegin - currentTime
                }
                break
            }
        }
        
        // Return the minimum of smoothPauseLength and available distance
        // Leave a small buffer (0.05 seconds) to avoid exact timing issues
        let safeDistance = max(0, distanceToNextVerse - 0.05)
        return min(smoothPauseLength, safeDistance)
    }
    
    private func pauseSmoothly(duration: TimeInterval) {
        let initialVolume = player.volume
        let steps = 10
        let interval = duration / Double(steps)
        var currentStep = 0
        
        self.state = .waitingForPause
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            if currentStep < steps {
                let newVolume = initialVolume * (1.0 - Float(currentStep) / Float(steps))
                self.player.volume = newVolume
                currentStep += 1
            } else {
                self.player.volume = initialVolume // Reset volume to original after pausing
                timer.invalidate()
                self.pauseSimple()
                let to = CMTimeGetSeconds(self.player.currentTime()) - duration
                self.player.seek(to: CMTimeMake(value: Int64(to*100), timescale: 100))
            }
        }
    }
    
    func breakForSeconds(_ seconds: Double) {
        self.player.pause()
        self.state = .autopausing
        
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            // Ensure playback wasn't fully stopped meanwhile
            if self.state == .autopausing {
                self.playSimple()
            }
        }
    }
    
    // MARK: Seeking
    func sliderEditingChanged(editingStarted: Bool) { // private
        
        if editingStarted {
            // Tell PlayerTimeObserver to stop publishing while user drags the slider
            self.timeObserver.pause(true)
        }
        else {
            // Editing finished, start the seek
            let targetTime = CMTime(seconds: currentTime, preferredTimescale: 600)
            player.seek(to: targetTime) { _ in
                self.timeObserver.pause(false)
            }
            if currentTime >= Double(periodTo == 0 ? currentDuration : periodTo) {
                stopAtEnd = false
            }
            findAndSetCurrentVerseIndex()
        }
    }
    
    func restart() {
        if state == .playing || state == .pausing || state == .finished {
            stopAtEnd = true
            setCurrentVerseIndex(-1)
            player.seek(to: CMTimeMake(value: Int64(periodFrom*100), timescale: 100))
        }
    }
    
    func seekToVerseIndex(_ index: Int) {
        guard index >= 0 && index < audioVerses.count else { return }
        setCurrentVerseIndex(index)
        let begin = audioVerses[currentVerseIndex].begin
        timeObserver.pause(true)
        currentTime = begin
        let targetTime = CMTime(seconds: begin, preferredTimescale: 600)
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            self?.timeObserver.pause(false)
        }
    }

    func previousVerse() {
        let navigableStates: [PlaybackState] = [.playing, .pausing, .autopausing, .buffering, .error]
        if navigableStates.contains(state) && currentVerseIndex > 0 {
            setCurrentVerseIndex(currentVerseIndex - 1)
            
            let begin = audioVerses[currentVerseIndex].begin
            // Pause periodic updates during the seek to avoid UI "jumping back".
            timeObserver.pause(true)
            currentTime = begin
            let targetTime = CMTime(seconds: begin, preferredTimescale: 600)
            player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                self?.timeObserver.pause(false)
            }
        }
    }
    
    func nextVerse() {
        let navigableStates: [PlaybackState] = [.playing, .pausing, .autopausing, .buffering, .error]
        if navigableStates.contains(state) && currentVerseIndex+1 < audioVerses.count {
            setCurrentVerseIndex(currentVerseIndex + 1)
            let begin = audioVerses[currentVerseIndex].begin
            // Step slightly back to make the transition smoother
            let minus = currentVerseIndex >= 1 ? min(abs((audioVerses[currentVerseIndex-1].end - begin) / 2), 0.1) : 0
            let target = max(0, begin - minus)
            // Pause periodic updates during the seek to avoid UI "jumping back".
            timeObserver.pause(true)
            // Keep UI in sync with the actual seek target to avoid a visible "jump back".
            currentTime = target
            let targetTime = CMTime(seconds: target, preferredTimescale: 600)
            player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                self?.timeObserver.pause(false)
            }
        }
    }
    
    // MARK: Playback speed
    func changeSpeed() {
        if currentSpeed >= 2 || currentSpeed < 0.6 {
            currentSpeed = 0.6
        }
        else {
            currentSpeed += 0.2
        }
        
        if #available(iOS 16.0, *) {
            player.defaultRate = currentSpeed
        }
        if state == .playing {
            player.rate = currentSpeed
        }
    }

    func setSpeed(speed: Float) {
        currentSpeed = speed
        if #available(iOS 16.0, *) {
            player.defaultRate = speed
        }
    }
    
    
}
