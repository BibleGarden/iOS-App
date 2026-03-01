import SwiftUI
import AVFoundation
import Combine
import Foundation

struct MultilingualConfigSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var settingsManager: SettingsManager
    
    @State var step: MultilingualStep
    var onSave: (MultilingualStep) -> Void
    
    // MARK: Languages and translations state
    @State private var isLanguagesLoading: Bool = true
    @State private var languageTexts: [String] = []
    @State private var languageDescriptions: [String] = []
    @State private var languageKeys: [String]  = []

    @State private var translationsResponse: [Components.Schemas.TranslationModel] = []
    @State private var isTranslationsLoading: Bool = true
    @State private var translationKeys: [String]  = []
    @State private var translationTexts: [String] = []
    @State private var translationDescriptions: [String] = []
    @State private var translationNames: [String] = []
    
    @State private var voiceTexts: [String] = []
    @State private var voiceKeys: [String]  = []
    @State private var voiceMusics: [Bool]  = []
    @State private var voiceDescriptions: [String] = []
    
    @State private var inlineErrorMessage: String = ""
    
    // Temporary selections
    @State private var selectedLanguage: String = ""
    @State private var selectedTranslation: String = ""
    @State private var selectedTranslationName: String = ""
    @State private var selectedVoice: String = ""
    @State private var selectedVoiceName: String = ""
    @State private var selectedVoiceMusic: Bool = false
    
    // Preview
    @State private var previewPlayer: AVPlayer?
    @State private var previewVoiceIndex: Int? = nil
    @State private var previewTimer: AnyCancellable? = nil
    @State private var previewTimeObserver: Any? = nil

    var body: some View {
        ZStack {
            Color("DarkGreen")
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("settings.cancel_choice".localized) {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("multilingual.config.title".localized) // Localized
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button {
                        saveStep()
                    } label: {
                        Text("settings.save_choice".localized)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(canSave ? Color("Mustard") : Color.gray)
                    .disabled(!canSave)
                }
                .padding()
                .background(Color("DarkGreen").brightness(0.05))
                
                ScrollView {
                    VStack(spacing: 20) {
                        if !inlineErrorMessage.isEmpty {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.footnote)
                                Text(inlineErrorMessage)
                                    .font(.footnote)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color.red.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        
                        // Language
                        viewGroupHeader(text: "settings.bible_language".localized)
                        if isLanguagesLoading {
                            ProgressView().tint(.white)
                        } else {
                            viewSelectList(texts: languageTexts,
                                           keys: languageKeys,
                                           selectedKey: $selectedLanguage,
                                           descriptions: languageDescriptions,
                                           onSelect: { index in
                                stopVoicePreview()
                                selectedLanguage = languageKeys[index]
                                selectedTranslation = ""
                                selectedVoice = ""
                                fetchTranslations()
                            })
                        }
                        
                        // Translation
                        if !selectedLanguage.isEmpty {
                            viewGroupHeader(text: "settings.translation".localized)
                            if isTranslationsLoading {
                                ProgressView().tint(.white)
                            } else {
                                viewSelectList(texts: translationTexts,
                                               keys: translationKeys,
                                               selectedKey: $selectedTranslation,
                                               descriptions: translationDescriptions,
                                               onSelect: { index in
                                    stopVoicePreview()
                                    selectedTranslation = translationKeys[index]
                                    selectedTranslationName = translationNames[index]
                                    selectedVoice = ""
                                    showAudios()
                                })
                            }
                        }
                        
                        // Voice
                        if !selectedTranslation.isEmpty {
                            viewGroupHeader(text: "settings.reader".localized)
                            viewSelectListWithPreview(texts: voiceTexts,
                                           keys: voiceKeys,
                                           selectedKey: $selectedVoice,
                                           descriptions: voiceDescriptions,
                                           onSelect: { index in
                                                selectedVoice = voiceKeys[index]
                                                selectedVoiceName = voiceTexts[index]
                                                selectedVoiceMusic = voiceMusics[index]
                                           },
                                           onPreview: { index in
                                                toggleVoicePreview(index: index)
                                           },
                                           isPlaying: { index in
                                                return previewVoiceIndex == index
                                           }
                            )
                        }
                        
                        // Speed Settings
                        Text("settings.speed".localized.uppercased())
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white.opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.top, 10)
                        
                         HStack {
                            Text(String(format: "%.1fx", step.playbackSpeed))
                                .foregroundColor(.white)
                                .frame(width: 50)
                            
                            Spacer()
                            
                            HStack(spacing: 0) {
                                Button(action: {
                                    if step.playbackSpeed > 0.5 {
                                        step.playbackSpeed -= 0.1
                                    }
                                }) {
                                    Image(systemName: "minus")
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .background(Color.clear)
                                        .foregroundColor(.white)
                                }
                                .frame(width: 50)
                                
                                Divider().background(Color.white)
                                
                                Button(action: {
                                    if step.playbackSpeed < 2.5 {
                                        step.playbackSpeed += 0.1
                                    }
                                }) {
                                    Image(systemName: "plus")
                                        .font(.title3)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .background(Color.clear)
                                        .foregroundColor(.white)
                                }
                                .frame(width: 50)
                            }
                            .frame(height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.white, lineWidth: 1)
                            )
                        }
                        .padding(.horizontal)

                        // Font Settings (as requested: "настройку шрифта")
                        viewGroupHeader(text: "settings.font".localized)
                         HStack {
                            Text("\(Int(step.fontIncreasePercent))%")
                                .foregroundColor(.white)
                                .frame(width: 50)
                            
                            Spacer()
                            
                            HStack(spacing: 0) {
                                Button(action: {
                                    if step.fontIncreasePercent > 10 {
                                        step.fontIncreasePercent -= 10
                                    }
                                }) {
                                    Image(systemName: "minus")
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .background(Color.clear)
                                        .foregroundColor(.white)
                                }
                                .frame(width: 50)
                                
                                Divider().background(Color.white)
                                
                                Button(action: {
                                    if step.fontIncreasePercent < 500 {
                                        step.fontIncreasePercent += 10
                                    }
                                }) {
                                    Image(systemName: "plus")
                                        .font(.title3)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .background(Color.clear)
                                        .foregroundColor(.white)
                                }
                                .frame(width: 50)
                            }
                            .frame(height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.white, lineWidth: 1)
                            )
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 50)
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            initializeState()
        }
        .onDisappear {
            stopVoicePreview()
        }
    }
    
    var canSave: Bool {
        return !selectedLanguage.isEmpty && !selectedTranslation.isEmpty && !selectedVoice.isEmpty
    }
    
    func initializeState() {
        // Prepare initial state from step
        if !step.languageCode.isEmpty {
            selectedLanguage = step.languageCode
            selectedTranslation = String(step.translationCode)
            selectedTranslationName = step.translationName
            selectedVoice = String(step.voiceCode)
            selectedVoiceName = step.voiceName
            selectedVoiceMusic = step.voiceMusic
        } else {
            // Default to current settings if new step
            selectedLanguage = settingsManager.language
            // Don't auto-set translation/voice for new step to force choice? 
            // Or better, set defaults.
            // Let's set defaults.
             selectedTranslation = String(settingsManager.translation)
             selectedTranslationName = settingsManager.translationName
             selectedVoice = String(settingsManager.voice)
             selectedVoiceName = settingsManager.voiceName
             selectedVoiceMusic = settingsManager.voiceMusic
        }
        
        fetchLanguages()
    }
    
    func saveStep() {
        step.languageCode = selectedLanguage
        step.translationCode = Int(selectedTranslation) ?? 0
        step.translationName = selectedTranslationName
        step.voiceCode = Int(selectedVoice) ?? 0
        step.voiceName = selectedVoiceName
        step.voiceMusic = selectedVoiceMusic
        // fontIncreasePercent is already bound to step
        
        // Find language name
        if let idx = languageKeys.firstIndex(of: selectedLanguage) {
             // Extract English name from "National (En)"
             // The format in fetchLanguages is "\(language.name_national) (\(language.name_en))"
             // I'll just store the text I have.
             // Ideally step should have languageName.
            step.languageName = languageTexts[idx]
        }
        
        onSave(step)
        presentationMode.wrappedValue.dismiss()
    }
    
    // MARK: API Reused Logic
    func fetchLanguages() {
        Task {
            do {
                inlineErrorMessage = ""
                self.languageKeys = []
                self.languageTexts = []
                self.languageDescriptions = []

                let response = try await settingsManager.client.get_languages()
                let languages = try response.ok.body.json

                for language in languages {
                    self.languageKeys.append(language.alias)
                    self.languageTexts.append(language.name_national)
                    self.languageDescriptions.append(language.name_en)
                }
                
                // If selected language not in list, fallback
                if !languageKeys.contains(selectedLanguage), let first = languageKeys.first {
                    selectedLanguage = first
                }
                
                fetchTranslations()
                self.isLanguagesLoading = false
            } catch {
                self.isLanguagesLoading = false
                showInlineError(for: error)
            }
        }
    }
    
    func fetchTranslations() {
        Task {
            do {
                inlineErrorMessage = ""
                self.isTranslationsLoading = true
                
                let response = try await settingsManager.client.get_translations(query: .init(language: self.selectedLanguage))
                self.translationsResponse = try response.ok.body.json
                
                self.translationKeys = []
                self.translationTexts = []
                self.translationDescriptions = []
                self.translationNames = []
                for translation in self.translationsResponse {
                    self.translationKeys.append("\(translation.code)")
                    let shortName = translation.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    let longName = (translation.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    self.translationTexts.append(shortName)
                    self.translationDescriptions.append(longName == shortName ? "" : longName)
                    self.translationNames.append(translation.name)
                }
                
                // If selected translation not in list, select first
                if !translationKeys.contains(selectedTranslation), let firstReference = translationKeys.first, let firstName = translationNames.first {
                    selectedTranslation = firstReference
                    selectedTranslationName = firstName
                    // Also reset voice
                    selectedVoice = ""
                }
                
                showAudios()
                self.isTranslationsLoading = false
            } catch {
                self.isTranslationsLoading = false
                showInlineError(for: error)
            }
        }
    }
    
    func showAudios() {
        self.voiceKeys = []
        self.voiceTexts = []
        self.voiceMusics = []
        self.voiceDescriptions = []
        
        if let translation = self.translationsResponse.first(where: { "\($0.code)" == self.selectedTranslation }) {
             for voice in translation.voices {
                self.voiceKeys.append("\(voice.code)")
                self.voiceTexts.append("\(voice.name)")
                self.voiceMusics.append(voice.is_music)
                self.voiceDescriptions.append(voice.description ?? "")
            }
        }
        
        // If selected voice not in list, select first
        if (!voiceKeys.contains(selectedVoice) || selectedVoice.isEmpty), let firstVoiceKey = voiceKeys.first {
            selectedVoice = firstVoiceKey
            if !voiceTexts.isEmpty {
                selectedVoiceName = voiceTexts[0]
                selectedVoiceMusic = voiceMusics[0]
            }
        }
    }
    
    // MARK: Voice preview
    func toggleVoicePreview(index: Int) {
        if previewVoiceIndex == index {
            stopVoicePreview()
            return
        }
        stopVoicePreview()
        
        let voiceCode = Int(voiceKeys[index]) ?? 0
        let translationCode = Int(selectedTranslation) ?? 0

        Task {
            do {
                let (_, audioVerses, firstUrl, _, _) = try await getExcerptTextualVersesOnline(
                    excerpts: "jhn 1",
                    client: settingsManager.client,
                    translation: translationCode,
                    voice: voiceCode
                )
                
                guard !firstUrl.isEmpty, let url = URL(string: firstUrl) else {
                    inlineErrorMessage = "error.audio.unavailable".localized
                    return
                }
                
                let playerItem = AVPlayerItem(url: url)
                previewPlayer = AVPlayer(playerItem: playerItem)
                previewVoiceIndex = index
                
                if let firstVerse = audioVerses.first {
                    let startTime = CMTime(seconds: firstVerse.begin, preferredTimescale: 600)
                    await previewPlayer?.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
                }
                
                if audioVerses.count >= 3 {
                    let thirdVerseEndTime = CMTime(seconds: audioVerses[2].end, preferredTimescale: 600)
                    previewTimeObserver = previewPlayer?.addBoundaryTimeObserver(
                        forTimes: [NSValue(time: thirdVerseEndTime)],
                        queue: .main
                    ) {
                        self.stopVoicePreview()
                    }
                }
                
                previewPlayer?.play()
                
            } catch {
                inlineErrorMessage = "error.loading.audio".localized
            }
        }
    }
    
    func stopVoicePreview() {
        if let observer = previewTimeObserver {
            previewPlayer?.removeTimeObserver(observer)
            previewTimeObserver = nil
        }
        previewPlayer?.pause()
        previewPlayer = nil
        previewVoiceIndex = nil
        previewTimer?.cancel()
        previewTimer = nil
    }

    private func showInlineError(for error: Error) {
        print("[MultilingualConfigSheet] Operation failed: \(error)")
        let rawErrorText = "\(error)"
        if let statusCode = extractHTTPStatusCode(from: rawErrorText) {
            inlineErrorMessage = "error.loading.setup.with_code".localized(statusCode)
            return
        }

        let nsError = error as NSError
        if nsError.domain == "getExcerptTextualVersesOnline", nsError.code == 422 {
            let detail = compactErrorText(nsError.localizedDescription)
            if !detail.isEmpty {
                inlineErrorMessage = detail
                return
            }
        }

        #if DEBUG
        inlineErrorMessage = "\("error.loading.setup".localized)\n\(compactErrorText(rawErrorText, maxLength: 300))"
        #else
        inlineErrorMessage = "error.loading.setup".localized
        #endif
    }

    private func extractHTTPStatusCode(from text: String) -> Int? {
        let patterns = [
            #"statusCode:\s*(\d{3})"#,
            #"status\s*code\s*[:=]\s*(\d{3})"#,
            #"status:\s*(\d{3})"#
        ]

        let searchRange = NSRange(text.startIndex..<text.endIndex, in: text)
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                  let match = regex.firstMatch(in: text, options: [], range: searchRange),
                  match.numberOfRanges > 1,
                  let codeRange = Range(match.range(at: 1), in: text),
                  let statusCode = Int(text[codeRange]) else {
                continue
            }
            return statusCode
        }
        return nil
    }

    private func compactErrorText(_ text: String, maxLength: Int = 120) -> String {
        let normalized = text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > maxLength else { return normalized }
        return String(normalized.prefix(maxLength - 3)) + "..."
    }
}
