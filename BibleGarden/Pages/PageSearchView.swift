import SwiftUI

struct PageSearchView: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    @ObservedObject var model: ScriptureSearchModel
    @ObservedObject private var localization = LocalizationManager.shared
    @AppStorage("searchAIConsentVersion") private var consentVersion = ""
    @FocusState private var queryFocused: Bool
    @State private var showingPrivacy = false
    @State private var searchAfterConsent = false

    private var consentIdentity: String {
        #if DEBUG
        return "v2-test-cerebras-google-ai2-\(Config.baseURL)"
        #else
        return "v1-google-ai2-\(Config.baseURL)"
        #endif
    }

    private var hasConsent: Bool { consentVersion == consentIdentity }

    var body: some View {
        VStack(spacing: 0) {
            AppHeaderBar {
                MenuButtonView().environmentObject(settingsManager)
            } center: {
                Text("search.title".localized).font(.headline).foregroundColor(.white)
            } trailing: {
                Button {
                    searchAfterConsent = false
                    showingPrivacy = true
                } label: {
                    Image(systemName: "info.circle").font(.system(size: 23))
                        .frame(width: AppHeaderMetrics.controlSize, height: AppHeaderMetrics.controlSize)
                }
                .accessibilityLabel("search.privacy.title".localized)
                .accessibilityIdentifier("search-privacy")
            }
            .foregroundColor(.white)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    searchForm
                    searchContent
                }
                .padding(.horizontal, globalBasePadding)
                .padding(.top, 26)
                .padding(.bottom, 32)
            }
        }
        .background(Color("DarkGreen").accessibilityIdentifier("page-search").ignoresSafeArea())
        .task { await model.configure(settings: settingsManager) }
        .onDisappear { model.cancel() }
        .onChange(of: model.query) { _ in model.cancel() }
        .sheet(isPresented: $showingPrivacy) { privacySheet }
    }

    private var searchForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 9) {
                Text("search.heading".localized)
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text("search.subtitle".localized)
                    .font(.subheadline).foregroundColor(.white.opacity(0.65))
                    .lineSpacing(4)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass").foregroundColor(Color("Mustard"))
                    TextField("", text: $model.query, prompt: Text("search.placeholder".localized).foregroundColor(.white.opacity(0.45)))
                        .foregroundColor(.white)
                        .font(.body)
                        .submitLabel(.search)
                        .focused($queryFocused)
                        .onSubmit { requestSearch() }
                        .accessibilityIdentifier("search-query")
                    if !model.query.isEmpty {
                        Button { model.query = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.white.opacity(0.45))
                        }
                        .accessibilityLabel("search.clear".localized)
                        .accessibilityIdentifier("search-clear")
                    }
                }
                .padding(16)
                .background(Color("DarkGreen-light"))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(queryFocused ? 0.45 : 0.12)))

                translationPicker

                if model.trimmedQuery.count > 500 {
                    Text("search.too_long".localized).font(.caption).foregroundColor(Color("Mustard"))
                }

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let wait = max(0, Int(ceil((model.retryAfter ?? context.date).timeIntervalSince(context.date))))
                    let enabled = canSubmit && wait == 0
                    Button(action: requestSearch) {
                        HStack(spacing: 9) {
                            if model.isLoading { ProgressView().tint(.white.opacity(0.6)) }
                            Text(wait > 0 ? "search.wait".localized(wait) : "search.action".localized)
                                .font(.headline)
                            if !model.isLoading && wait == 0 { Image(systemName: "arrow.right") }
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .foregroundColor(enabled ? Color("DarkGreen") : .white.opacity(0.5))
                        .background(enabled ? Color("Mustard") : .white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(enabled ? .clear : .white.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                    .disabled(!enabled)
                    .accessibilityIdentifier("search-submit")
                }
            }
        }
    }

    private var canSubmit: Bool {
        !model.trimmedQuery.isEmpty && model.trimmedQuery.count <= 500 && !model.isLoading && !model.translations.isEmpty
    }

    private var translationPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Menu {
                ForEach(AppLanguage.allCases) { language in
                    Menu(language.displayName) {
                        ForEach(model.translations.filter { $0.language == language.rawValue }, id: \.code) { translation in
                            Button {
                                model.select(translation)
                            } label: {
                                if model.translation == translation.code {
                                    Label(translation.name, systemImage: "checkmark")
                                } else {
                                    Text(translation.name)
                                }
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "globe")
                    Text(model.translationName).lineLimit(1)
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                    Spacer(minLength: 0)
                    Text("search.translation".localized).foregroundColor(.white.opacity(0.4))
                }
                .font(.caption).foregroundColor(.white.opacity(0.75))
                .padding(.horizontal, 4).padding(.vertical, 3)
            }
            .disabled(model.translations.isEmpty)
            .accessibilityIdentifier("search-translation")

            if model.catalogError {
                Button("search.error.catalog".localized) {
                    Task { await model.configure(settings: settingsManager) }
                }
                .font(.caption).foregroundColor(Color("Mustard"))
            }
        }
    }

    @ViewBuilder private var searchContent: some View {
        switch model.phase {
        case .idle:
            VStack(alignment: .leading, spacing: 14) {
                Text("search.examples".localized.uppercased())
                    .font(.caption.weight(.semibold)).tracking(1.3).foregroundColor(.white.opacity(0.4))
                ForEach(["search.example.anxiety", "search.example.noah", "search.example.love"], id: \.self) { key in
                    Button {
                        model.query = key.localized
                        queryFocused = true
                    } label: {
                        HStack {
                            Text(key.localized).font(.subheadline)
                            Spacer()
                            Image(systemName: "arrow.up.left").font(.caption)
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .padding(16)
                        .background(.white.opacity(0.045))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                Text("search.hint".localized)
                    .font(.caption).foregroundColor(.white.opacity(0.4)).lineSpacing(4).padding(.top, 4)
            }
        case .loading:
            stateCard(icon: "sparkle.magnifyingglass", title: "search.loading", detail: "search.loading.detail")
                .accessibilityIdentifier("search-loading")
        case .failed(let key):
            stateCard(icon: "exclamationmark.bubble", title: "search.error.title", detail: key)
                .accessibilityIdentifier("search-error")
        case .loaded:
            if model.hits.isEmpty {
                stateCard(icon: "magnifyingglass", title: "search.empty", detail: "search.empty.detail")
                    .accessibilityIdentifier("search-empty")
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Text("search.results".localized(model.hits.count))
                        .font(.subheadline.weight(.semibold)).foregroundColor(.white.opacity(0.65))
                    Text(model.submittedQuery)
                        .font(.caption).foregroundColor(.white.opacity(0.45))
                    ForEach(model.hits) { hit in
                        SearchResultCard(hit: hit) {
                            queryFocused = false
                            model.open(hit, settings: settingsManager)
                        }
                    }
                }
            }
        }
    }

    private func stateCard(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 30, weight: .light)).foregroundColor(Color("Mustard"))
            Text(title.localized).font(.headline).foregroundColor(.white)
            Text(detail.localized).font(.subheadline).foregroundColor(.white.opacity(0.6)).lineSpacing(4)
        }
        .multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.horizontal, 20).padding(.vertical, 36)
        .background(.white.opacity(0.04)).clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func requestSearch() {
        guard canSubmit else { return }
        queryFocused = false
        if hasConsent {
            model.search()
        } else {
            searchAfterConsent = true
            showingPrivacy = true
        }
    }

    private var privacySheet: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Spacer()
                CloseHeaderButton { showingPrivacy = false }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Image(systemName: "sparkles").font(.system(size: 36)).foregroundColor(Color("Mustard"))
                    Text("search.privacy.title".localized).font(.title2.bold()).foregroundColor(.white)
                    Text("search.privacy.body".localized).font(.body).foregroundColor(.white.opacity(0.8)).lineSpacing(5)
                    #if DEBUG
                    Text("search.privacy.providers.test".localized).font(.subheadline).foregroundColor(.white.opacity(0.65))
                    #else
                    Text("search.privacy.providers".localized).font(.subheadline).foregroundColor(.white.opacity(0.65))
                    #endif
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if hasConsent {
                Button("search.privacy.revoke".localized) {
                    consentVersion = ""
                    model.cancel()
                    showingPrivacy = false
                }
                .foregroundColor(Color("Mustard"))
                .accessibilityIdentifier("search-consent-revoke")
            } else {
                Button {
                    consentVersion = consentIdentity
                    showingPrivacy = false
                    if searchAfterConsent { model.search() }
                } label: {
                    Text((searchAfterConsent ? "search.privacy.allow_search" : "search.privacy.allow").localized)
                        .font(.headline).frame(maxWidth: .infinity).padding(16)
                        .foregroundColor(Color("DarkGreen")).background(Color("Mustard"))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .accessibilityIdentifier("search-consent-allow")
                Button("search.privacy.decline".localized) { showingPrivacy = false }
                    .frame(maxWidth: .infinity).foregroundColor(.white.opacity(0.6))
                    .accessibilityIdentifier("search-consent-decline")
            }
        }
        .padding(28).padding(.bottom, 20)
        .background(Color("DarkGreen").ignoresSafeArea())
    }
}

private struct SearchResultCard: View {
    let hit: ScriptureSearchHit
    let open: () -> Void
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(hit.keyReference)
                .font(.headline).foregroundColor(Color("Mustard"))
            if let title = hit.passage.title, !title.isEmpty {
                Text(title).font(.subheadline).foregroundColor(.white.opacity(0.55))
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(expanded ? hit.verses : hit.keyVerses, id: \.number) { verse in
                    (Text("\(verse.number) ").font(.system(size: 12, design: .serif))
                        .foregroundColor(Color("Mustard").opacity(hit.isHighlighted(verse.number) ? 1 : 0.5))
                     + Text(verse.text)
                        .font(.system(size: 18, weight: hit.isHighlighted(verse.number) ? .medium : .regular, design: .serif))
                        .foregroundColor(.white.opacity(hit.isHighlighted(verse.number) ? 0.95 : 0.5)))
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("search-verse-\(hit.id)-\(verse.number)")
                }
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(expanded ? "search.context.hide".localized : "search.context.show".localized)
                    Text(hit.reference).foregroundColor(.white.opacity(0.45))
                    Spacer(minLength: 0)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                }
                .font(.caption).foregroundColor(.white.opacity(0.7))
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .accessibilityIdentifier("search-context-\(hit.id)")

            Rectangle().fill(.white.opacity(0.1)).frame(height: 1)
            Button(action: open) {
                HStack {
                    Text("search.open".localized).font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "arrow.right").font(.caption)
                }
                .foregroundColor(Color("Mustard")).padding(.vertical, 3)
            }
            .accessibilityIdentifier("search-result-\(hit.id)")
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(20)
        .background(Color("DarkGreen-light"))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .buttonStyle(.plain)
    }
}
