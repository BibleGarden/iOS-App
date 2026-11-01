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
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .background(Color("DarkGreen").accessibilityIdentifier("page-search").ignoresSafeArea())
        .task { await model.configure(settings: settingsManager) }
        .onAppear {
            guard settingsManager.focusSearchOnOpen else { return }
            settingsManager.focusSearchOnOpen = false
            // Waits for the page transition: focus set during it is dropped.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { queryFocused = true }
        }
        .onDisappear { model.cancel() }
        .sheet(isPresented: $showingPrivacy) { privacySheet }
    }

    private var searchForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("search.subtitle".localized)
                .font(.subheadline).foregroundColor(.white.opacity(0.65))
                .lineSpacing(4)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass").foregroundColor(.white.opacity(0.5))
                    TextField("", text: $model.query, prompt: Text("search.placeholder".localized).foregroundColor(.white.opacity(0.45)))
                        .foregroundColor(.white)
                        .font(.body)
                        .submitLabel(.search)
                        .focused($queryFocused)
                        .onSubmit { requestSearch() }
                        .accessibilityIdentifier("search-query")
                    trailingControl
                }
                .frame(minHeight: 32)
                .padding(.leading, 16).padding(.trailing, 10).padding(.vertical, 11)
                .background(Color.black.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(queryFocused ? 0.45 : 0.18)))

                translationPicker

                if model.trimmedQuery.count > 500 {
                    Text("search.too_long".localized).font(.caption).foregroundColor(Color("Mustard"))
                }
            }
        }
    }

    /// The single control at the end of the field: the search button while there is
    /// something new to search for, the clear button once the results answer the query.
    /// The search also runs from the keyboard.
    private var trailingControl: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let wait = max(0, Int(ceil((model.retryAfter ?? context.date).timeIntervalSince(context.date))))
            if model.isLoading {
                ProgressView().tint(.white.opacity(0.6)).frame(width: 32, height: 32)
            } else if wait > 0 {
                Text("\(wait)").font(.footnote.weight(.semibold).monospacedDigit())
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 32, height: 32).background(Circle().fill(.white.opacity(0.08)))
                    .accessibilityLabel("search.wait".localized(wait))
            } else if model.answersCurrentQuery {
                Button { model.reset() } label: {
                    Image(systemName: "xmark.circle.fill").font(.title3)
                        .foregroundColor(.white.opacity(0.45))
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("search.clear".localized)
                .accessibilityIdentifier("search-clear")
            } else if canSubmit {
                Button(action: requestSearch) {
                    Image(systemName: "arrow.right").font(.subheadline.weight(.bold))
                        .foregroundColor(Color("DarkGreen"))
                        .frame(width: 32, height: 32).background(Circle().fill(Color("Mustard")))
                }
                .accessibilityLabel("search.action".localized)
                .accessibilityIdentifier("search-submit")
            }
        }
    }

    private var canSubmit: Bool {
        !model.trimmedQuery.isEmpty && model.trimmedQuery.count <= 500 && !model.isLoading && !model.translations.isEmpty
    }

    private var translationPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
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
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                        Text("search.translation".localized(model.translationName)).lineLimit(1)
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                    }
                    .font(.caption.weight(.medium)).foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(.white.opacity(0.07)).clipShape(Capsule())
                }
                .disabled(model.translations.isEmpty)
                .accessibilityIdentifier("search-translation")
                Spacer(minLength: 12)
                if !model.hits.isEmpty {
                    Text("search.results".localized(model.hits.count))
                        .font(.caption).foregroundColor(.white.opacity(0.5))
                        .accessibilityIdentifier("search-results-count")
                }
            }

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
                if model.recentQueries.isEmpty {
                    sectionTitle("search.examples")
                    ForEach(["search.example.anxiety", "search.example.noah", "search.example.love"], id: \.self) { key in
                        suggestion(key.localized, icon: "arrow.up.left") {
                            model.query = key.localized
                            queryFocused = true
                        }
                        .accessibilityIdentifier("search-example")
                    }
                    Text("search.hint".localized)
                        .font(.caption).foregroundColor(.white.opacity(0.4)).lineSpacing(4).padding(.top, 4)
                } else {
                    HStack {
                        sectionTitle("search.recent")
                        Spacer()
                        Button("search.recent.clear".localized) { model.clearRecentQueries() }
                            .font(.caption).foregroundColor(.white.opacity(0.5))
                            .accessibilityIdentifier("search-recent-clear")
                    }
                    ForEach(model.recentQueries, id: \.self) { query in
                        suggestion(query, icon: "magnifyingglass") {
                            model.query = query
                            requestSearch()
                        }
                        .accessibilityIdentifier("search-recent")
                    }
                }
            }
        case .loading:
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("search.loading".localized).font(.subheadline.weight(.semibold))
                            .foregroundColor(.white.opacity(0.8))
                        Text("search.loading.detail".localized).font(.caption).foregroundColor(.white.opacity(0.45))
                    }
                    .accessibilityIdentifier("search-loading")
                    Spacer(minLength: 12)
                    Button("search.cancel".localized) { model.cancel() }
                        .font(.subheadline.weight(.semibold)).foregroundColor(Color("Mustard"))
                        .accessibilityIdentifier("search-cancel")
                }
                ForEach(0..<3, id: \.self) { _ in SearchSkeletonCard() }
            }
        case .failed(let key):
            stateCard(icon: "exclamationmark.bubble", title: "search.error.title", detail: key)
                .accessibilityIdentifier("search-error")
        case .loaded:
            if model.hits.isEmpty {
                stateCard(icon: "magnifyingglass", title: "search.empty", detail: "search.empty.detail")
                    .accessibilityIdentifier("search-empty")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(model.hits) { hit in
                        SearchResultCard(hit: hit) { destination in
                            queryFocused = false
                            model.open(hit, in: destination, settings: settingsManager)
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

    private func sectionTitle(_ key: String) -> some View {
        Text(key.localized.uppercased())
            .font(.caption.weight(.semibold)).tracking(1.3).foregroundColor(.white.opacity(0.4))
    }

    private func suggestion(_ text: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(text).font(.subheadline).lineLimit(2).multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: icon).font(.caption)
            }
            .foregroundColor(.white.opacity(0.8))
            .padding(16)
            .background(.white.opacity(0.045))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
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
                    model.clearRecentQueries()
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
    let open: (ScriptureSearchModel.Destination) -> Void
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(hit.keyReference).font(.headline).foregroundColor(Color("Mustard"))
                    if let title = hit.passage.title, !title.isEmpty {
                        Text(title).font(.caption).foregroundColor(.white.opacity(0.5))
                    }
                }
                Spacer(minLength: 8)
                Menu { actions } label: {
                    Image(systemName: "ellipsis").font(.body.weight(.semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .padding(.top, -10).padding(.trailing, -12)
                .accessibilityLabel("search.actions".localized)
                .accessibilityIdentifier("search-actions-\(hit.id)")
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(expanded ? hit.verses : hit.keyVerses, id: \.number) { verse in
                    (Text("\(verse.number) ").font(.system(size: 12, design: .serif))
                        .foregroundColor(.white.opacity(hit.isHighlighted(verse.number) ? 0.5 : 0.3))
                     + Text(verse.text)
                        .font(.system(size: 17, weight: hit.isHighlighted(verse.number) ? .medium : .regular, design: .serif))
                        .foregroundColor(.white.opacity(hit.isHighlighted(verse.number) ? 0.95 : 0.5)))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("search-verse-\(hit.id)-\(verse.number)")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color("DarkGreen-light"))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .contextMenu { actions }
    }

    @ViewBuilder private var actions: some View {
        Button { open(.listen) } label: {
            Label("search.listen".localized, systemImage: "headphones")
        }
        Button { open(.chapter) } label: {
            Label("search.read_chapter".localized, systemImage: "book")
        }
        Button { open(.translations) } label: {
            Label("menu.multilingual".localized, systemImage: "rectangle.stack")
        }
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
        } label: {
            Label((expanded ? "search.context.hide" : "search.context.show").localized,
                  systemImage: expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
        }
        .accessibilityIdentifier("search-context-\(hit.id)")
        Divider()
        Button { UIPasteboard.general.string = hit.shareText } label: {
            Label("search.copy".localized, systemImage: "doc.on.doc")
        }
        Button { presentShareSheet(hit.shareText) } label: {
            Label("search.share".localized, systemImage: "square.and.arrow.up")
        }
    }
}

private struct SearchSkeletonCard: View {
    @State private var dimmed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            bar(width: 130, height: 16)
            bar(width: nil, height: 12)
            bar(width: nil, height: 12)
            bar(width: 190, height: 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(18)
        .background(Color("DarkGreen-light"))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .opacity(dimmed ? 0.4 : 1)
        .animation(.easeInOut(duration: 0.9).repeatForever(), value: dimmed)
        .onAppear { dimmed = true }
        .accessibilityHidden(true)
    }

    private func bar(width: CGFloat?, height: CGFloat) -> some View {
        Capsule().fill(.white.opacity(0.1)).frame(width: width, height: height)
    }
}

/// SwiftUI `ShareLink` needs iOS 16; the app still supports iOS 15.
private func presentShareSheet(_ text: String) {
    let scene = UIApplication.shared.connectedScenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
    guard var top = scene?.keyWindow?.rootViewController else { return }
    while let presented = top.presentedViewController { top = presented }
    let controller = UIActivityViewController(activityItems: [text], applicationActivities: nil)
    if let popover = controller.popoverPresentationController {
        popover.sourceView = top.view
        popover.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
        popover.permittedArrowDirections = []
    }
    top.present(controller, animated: true)
}
