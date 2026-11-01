import SwiftUI

struct PageMainView: View {
    
    @EnvironmentObject var settingsManager: SettingsManager
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var booksLoaded = false
    
    var body: some View {
        ZStack {
            GeometryReader { geo in
                Image("Forest")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .position(x: geo.size.width / 2, y: geo.size.height * (geo.size.width > geo.size.height ? 0.12 : 0.5))
            }
            .clipped()
            .ignoresSafeArea()

            VStack(spacing: 0) {
                AppHeaderBar {
                    MenuButtonView()
                        .environmentObject(settingsManager)
                } center: {
                    HeaderPlaceholder(width: 1)
                } trailing: {
                    HeaderPlaceholder()
                }

                VStack(spacing: 20) {
                    Spacer().frame(height: 28)
                    Text("page.main.header".localized)
                        .font(.system(size: 50, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                        .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)

                    searchEntry

                    VStack(spacing: 15) {
                        MainMenuCard(
                            title: "page.main.multilingual.title".localized,
                            subtitle: "page.main.multilingual.subtitle".localized,
                            icon: Image(systemName: "translate"),
                            color: Color("ForestGreen")
                        ) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                settingsManager.selectedMenuItem = .multilingual
                            }
                        }
                        .accessibilityIdentifier("card-multilingual")

                        MainMenuCard(
                            title: "page.main.classic.title".localized,
                            subtitle: "page.main.classic.subtitle".localized,
                            icon: Image(systemName: "book.fill"),
                            color: Color("ForestGreen")
                        ) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                settingsManager.selectedMenuItem = .read
                            }
                        }
                        .accessibilityIdentifier("card-classic-reading")
                    }

                    Spacer()
                }
                .padding(.horizontal, globalBasePadding)
                .padding(.bottom, 20)
                
                progressCardView()
            }
        }
        .onAppear {
            loadBooksIfNeeded()
        }
    }
    
    /// Looks like a search field: search is a way into the Bible, not a third reading mode.
    private var searchEntry: some View {
        Button {
            settingsManager.focusSearchOnOpen = true
            withAnimation(.easeInOut(duration: 0.25)) {
                settingsManager.selectedMenuItem = .search
            }
        } label: {
            HStack(spacing: 12) {
                SmartSearchIcon(size: 18)
                    .foregroundColor(Color("Mustard"))
                    .frame(width: 24)
                Text("search.main.prompt".localized)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .mainPillBackground()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("search.title".localized)
        .accessibilityHint("search.main.prompt".localized)
        .accessibilityIdentifier("card-search")
    }

    @ViewBuilder
    func progressCardView() -> some View {
        if !settingsManager.cachedBooks.isEmpty {
            let totalProgress = settingsManager.getTotalProgress(books: settingsManager.cachedBooks)
            if totalProgress.read > 0 {
                let share = Double(totalProgress.read) / Double(totalProgress.total)
                VStack {
                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            settingsManager.selectedMenuItem = .progress
                        }
                    } label: {
                        Text("page.main.progress_read".localized(String(format: "%.1f%%", share * 100)))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(alignment: .leading) {
                                GeometryReader { geometry in
                                    // A small share still shows as a sliver at the start.
                                    Rectangle().fill(Color("Mustard").opacity(0.45))
                                        .frame(width: max(geometry.size.width * share, 6))
                                }
                            }
                            .clipShape(Capsule())
                            .mainPillBackground()
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("card-progress")
                    .padding(.horizontal, globalBasePadding)
                    .padding(.bottom, 32)
                }
            }
        }
    }
    
    func loadBooksIfNeeded() {
        guard !booksLoaded else { return }
        
        Task {
            do {
                _ = try await settingsManager.getTranslationBooks()
                booksLoaded = true
            } catch {
                // Loading error is non-critical for the main page
            }
        }
    }
}

struct TestPageMainView: View {
    
    var body: some View {
        PageMainView()
            .environmentObject(SettingsManager())
    }
}

struct MainMenuCard<Icon: View>: View {
    let title: String
    let subtitle: String
    let icon: Icon
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                // Icon Box
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    icon
                        .font(.system(size: 20))
                        .foregroundColor(Color("Mustard"))
                }
                
                // Text Content
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body.bold())
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.82))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.72))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("DarkGreen").opacity(0.72))
                    .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle()) // Keeps standard button press effect minimal or custom
    }
}

#Preview {
    TestPageMainView()
}

private extension View {
    /// Pill of the main screen controls: darker than the cards, but dense enough
    /// to hide the forest behind the text.
    func mainPillBackground() -> some View {
        background(Capsule().fill(Color.black.opacity(0.4)))
            .background(Capsule().fill(Color("DarkGreen").opacity(0.7)))
            .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
    }
}
