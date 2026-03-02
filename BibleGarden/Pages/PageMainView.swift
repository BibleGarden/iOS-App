import SwiftUI

struct PageMainView: View {
    
    @EnvironmentObject var settingsManager: SettingsManager
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var booksLoaded = false
    
    var body: some View {
        
        ZStack {
            // Background layer
            Image("Forest")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .edgesIgnoringSafeArea(.all)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
            
            VStack(spacing: 20) {
                HStack {
                    MenuButtonView()
                        .environmentObject(settingsManager)
                    Spacer()
                }
                .headerPadding(extraTop: 30, extraTopSmall: 10)

                Spacer().frame(height: 28)
                // Localized title
                Text("page.main.header".localized)
                    .font(.system(size: 50, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                    .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
                
                // Dual Mode Selection
                VStack(spacing: 15) {
                    // Option 2: Immersion (Multilingual Study)
                    MainMenuCard(
                        title: "page.main.multilingual.title".localized,
                        subtitle: "page.main.multilingual.subtitle".localized,
                        icon: "translate", // Headphones for audio/study
                        color: Color("ForestGreen")
                    ) {
                        settingsManager.selectedMenuItem = .multilingual
                    }
                    .accessibilityIdentifier("card-multilingual")

                    // Option 1: Silence (Classic Reading)
                    MainMenuCard(
                        title: "page.main.classic.title".localized,
                        subtitle: "page.main.classic.subtitle".localized,
                        icon: "book.fill", // Classic book icon
                        color: Color("ForestGreen")
                    ) {
                        settingsManager.selectedMenuItem = .read
                    }
                    .accessibilityIdentifier("card-classic-reading")
                }
                
                // Push remaining content upward
                Spacer()
            }
            .padding(.horizontal, globalBasePadding)
            .padding(.vertical, 20)
            
            // Reading progress card near bottom
            progressCardView()
            
        }
        .onAppear {
            loadBooksIfNeeded()
        }
    }
    
    @ViewBuilder
    func progressCardView() -> some View {
        if !settingsManager.cachedBooks.isEmpty {
            let totalProgress = settingsManager.getTotalProgress(books: settingsManager.cachedBooks)
            if totalProgress.read > 0 {
                VStack {
                    Spacer()
                    
                    Button {
                        settingsManager.selectedMenuItem = .progress
                    } label: {
                        VStack(spacing: 10) {
                            Text("page.main.reading_progress".localized)
                                .font(.subheadline)
                                .foregroundColor(.white)
                            
                            // Progress bar with overlayed percentage
                            ZStack {
                                // Progress bar background
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: 24)
                                
                                GeometryReader { geometry in
                                    let progressWidth = geometry.size.width * CGFloat(totalProgress.read) / CGFloat(totalProgress.total)
                                    let progressPercent = CGFloat(totalProgress.read) / CGFloat(totalProgress.total)
                                    
                                    // Green progress fill
                                    HStack(spacing: 0) {
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.green.opacity(0.8), Color.green]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                        .frame(width: progressWidth, height: 24)
                                        
                                        Spacer(minLength: 0)
                                    }
                                    .mask(
                                        Group {
                                            if progressPercent > 0.98 {
                                                RoundedRectangle(cornerRadius: 6)
                                            } else {
                                                LeftRoundedRectangle(radius: 6)
                                            }
                                        }
                                    )
                                }
                                .frame(height: 24)
                                
                                // Percentage label above progress bar
                                Text(String(format: "%.1f%%", Double(totalProgress.read) / Double(totalProgress.total) * 100))
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("card-progress")
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color("DarkGreen").opacity(0.75))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color("DarkGreen"), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
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

struct MainMenuCard: View {
    let title: String
    let subtitle: String
    let icon: String // SF Symbol name
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
                    
                    Image(systemName: icon)
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
