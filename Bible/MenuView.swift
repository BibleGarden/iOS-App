import SwiftUI

enum MenuItem: Hashable {
    case main
    case read
    case select
    case progress
    case setup
    case contacts
    case multilingual
    case multilingualRead
}

// MARK: - Menu Overlay
struct MenuView: View {

    @EnvironmentObject var settingsManager: SettingsManager
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var readSubtitleSnapshot: String = ""
    @State private var showInterfaceLanguageSheet: Bool = false

    var body: some View {
        ZStack {
            // Blur View
            BlurView(style: .systemUltraThinMaterialDark)
                .accessibilityIdentifier("side-menu")

            Color("DarkGreen")
                .opacity(0.2)
                .blur(radius: 15)

            // Content
            VStack(alignment: .leading, spacing: UIScreen.main.bounds.height < 750 ? 20 : 35) {

                // MARK: Close Button
                Button {
                    withAnimation(.spring()) {
                        settingsManager.showMenu = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.title.weight(.light))
                }
                .foregroundColor(Color.white.opacity(0.5))

                // MARK: Menu Items

                // 1. Главная
                Button {
                    selectItem(.main)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(colorFor(.main))
                        Text("menu.main".localized)
                            .font(.system(.headline))
                            .fontWeight(.bold)
                            .foregroundColor(colorFor(.main))
                    }
                }
                .accessibilityIdentifier("menu-main")
                .accessibilityAddTraits(settingsManager.selectedMenuItem == .main ? .isSelected : [])

                // 2. Мультичтение
                Button {
                    if settingsManager.isMultilingualReadingActive {
                        selectItem(.multilingualRead)
                    } else {
                        selectItem(.multilingual)
                    }
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "rectangle.stack.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(multilingualColor())
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("menu.multilingual".localized)
                                .font(.system(.headline))
                                .fontWeight(.bold)
                                .foregroundColor(multilingualColor())
                            Text(multilingualTemplateSubtitle())
                                .font(.system(size: 13))
                                .foregroundColor(multilingualColor().opacity(0.5))
                                .lineLimit(1)
                        }
                    }
                }
                .accessibilityIdentifier("menu-multilingual")
                .accessibilityAddTraits(settingsManager.selectedMenuItem == .multilingual || settingsManager.selectedMenuItem == .multilingualRead ? .isSelected : [])

                // 3. Обычное чтение
                Button {
                    selectItem(.read)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(colorFor(.read))
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("menu.classic_reading".localized)
                                .font(.system(.headline))
                                .fontWeight(.bold)
                                .foregroundColor(colorFor(.read))
                            Text(readSubtitleSnapshot)
                                .font(.system(size: 14))
                                .foregroundColor(colorFor(.read).opacity(0.5))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                }
                .accessibilityIdentifier("menu-read")
                .accessibilityAddTraits(settingsManager.selectedMenuItem == .read ? .isSelected : [])

                // 4. Прогресс
                Button {
                    selectItem(.progress)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(colorFor(.progress))
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("menu.progress".localized)
                                .font(.system(.headline))
                                .fontWeight(.bold)
                                .foregroundColor(colorFor(.progress))
                            Text(progressPercentText())
                                .font(.system(size: 13))
                                .foregroundColor(colorFor(.progress).opacity(0.5))
                        }
                    }
                }
                .accessibilityIdentifier("menu-progress")
                .accessibilityAddTraits(settingsManager.selectedMenuItem == .progress ? .isSelected : [])

                // 5. Язык интерфейса
                Button {
                    showInterfaceLanguageSheet = true
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "globe")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(interfaceLanguageColor())
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("settings.language".localized)
                                .font(.system(.headline))
                                .fontWeight(.bold)
                                .foregroundColor(interfaceLanguageColor())
                            Text(localizationManager.currentLanguage.displayName)
                                .font(.system(size: 13))
                                .foregroundColor(interfaceLanguageColor().opacity(0.5))
                        }
                    }
                }
                .accessibilityIdentifier("menu-language")

                // 6. Контакты
                Button {
                    selectItem(.contacts)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(colorFor(.contacts))
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("menu.contacts".localized)
                                .font(.system(.headline))
                                .fontWeight(.bold)
                                .foregroundColor(colorFor(.contacts))
                            Text("\("menu.version".localized) \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                                .font(.system(size: 13))
                                .foregroundColor(colorFor(.contacts).opacity(0.5))
                        }
                    }
                }
                .accessibilityIdentifier("menu-contacts")
                .accessibilityAddTraits(settingsManager.selectedMenuItem == .contacts ? .isSelected : [])

                Spacer(minLength: 10)
            }
            .padding(.trailing, 120)
            .padding()
            .padding(.top, getSafeArea().top)
            .padding(.bottom, getSafeArea().bottom)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: min(UIScreen.main.bounds.width, 500))
        .clipShape(MenuShape(value: 0))
        .contentShape(MenuShape(value: 0))
        .background(
            MenuShape(value: 0)
                .stroke(
                    .linearGradient(.init(colors: [
                        Color("ForestGreen"),
                        Color("Mustard").opacity(0.7),
                        Color("Mustard").opacity(0.7),
                    ]), startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
                .padding(.leading, -50)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            refreshReadSubtitleSnapshot()
        }
        .onChange(of: settingsManager.currentExcerptTitle) { _ in
            if !settingsManager.showMenu {
                refreshReadSubtitleSnapshot()
            }
        }
        .onChange(of: settingsManager.currentExcerptSubtitle) { _ in
            if !settingsManager.showMenu {
                refreshReadSubtitleSnapshot()
            }
        }
        .sheet(isPresented: $showInterfaceLanguageSheet) {
            InterfaceLanguageSheetView()
                .sheetFullScreen()
        }
        .ignoresSafeArea()
    }

    // MARK: - Helpers

    private func colorFor(_ item: MenuItem) -> Color {
        let selected = settingsManager.selectedMenuItem == item
        return selected ? Color("Mustard").opacity(0.9) : Color.white.opacity(0.9)
    }

    private func multilingualColor() -> Color {
        let selected = settingsManager.selectedMenuItem == .multilingual || settingsManager.selectedMenuItem == .multilingualRead
        return selected ? Color("Mustard").opacity(0.9) : Color.white.opacity(0.9)
    }

    private func interfaceLanguageColor() -> Color {
        showInterfaceLanguageSheet ? Color("Mustard").opacity(0.9) : Color.white.opacity(0.9)
    }

    private func multilingualTemplateSubtitle() -> String {
        if let id = settingsManager.currentTemplateId,
           let template = settingsManager.multilingualTemplates.first(where: { $0.id == id }) {
            let trimmedName = template.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let baseTitle = trimmedName.isEmpty ? template.steps.multilingualCompactDescription() : trimmedName
            let isDirty = settingsManager.multilingualSteps != template.steps ||
                          settingsManager.multilingualReadUnit != template.unit
            return isDirty ? "\(baseTitle)*" : baseTitle
        }

        if !settingsManager.multilingualSteps.isEmpty {
            return settingsManager.multilingualSteps.multilingualCompactDescription()
        }

        return "multilingual.subtitle".localized
    }

    private func progressPercentText() -> String {
        let totalChapters: Int
        if settingsManager.cachedBooks.isEmpty {
            totalChapters = 1189
        } else {
            totalChapters = settingsManager.cachedBooks.reduce(0) { partial, book in
                partial + book.chapters_count
            }
        }

        guard totalChapters > 0 else { return "0%" }
        let readChapters = settingsManager.readProgress.readChapters.count
        let percentage = max(0, min(100, Double(readChapters) / Double(totalChapters) * 100))
        return String(format: "%.1f%%", percentage)
    }

    private func refreshReadSubtitleSnapshot() {
        readSubtitleSnapshot = "\(settingsManager.currentExcerptTitle), \(settingsManager.currentExcerptSubtitle)"
    }

    private func selectItem(_ item: MenuItem) {
        settingsManager.selectedMenuItem = item
        withAnimation(.spring()) {
            settingsManager.showMenu = false
        }
    }
}

private struct InterfaceLanguageSheetView: View {
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color("DarkGreen")
                .ignoresSafeArea()
                .accessibilityIdentifier("language-sheet")

            VStack(spacing: 0) {
                ZStack {
                    Text("settings.language".localized)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title3.weight(.light))
                                .frame(width: 32, height: 32)
                        }
                        .foregroundColor(.white.opacity(0.7))
                        .accessibilityIdentifier("language-close")

                        Spacer()

                        Color.clear
                            .frame(width: 32, height: 32)
                    }
                }
                .padding(.horizontal, globalBasePadding)
                .padding(.vertical, 12)
                .background(Color("DarkGreen").brightness(0.05))

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(AppLanguage.allCases) { language in
                        Button {
                            localizationManager.currentLanguage = language
                            dismiss()
                        } label: {
                            HStack {
                                Text(language.displayName)
                                    .foregroundColor(.white)
                                Spacer()
                                if localizationManager.currentLanguage == language {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color("Mustard"))
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color("DarkGreen-light").opacity(0.6))
                            .cornerRadius(8)
                        }
                        .accessibilityIdentifier("language-\(language.rawValue)")
                        .accessibilityAddTraits(localizationManager.currentLanguage == language ? .isSelected : [])
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, globalBasePadding)
                .padding(.top, 16)
                .padding(.bottom, 10)
            }
        }
    }
}

// MARK: - Curve Shape
struct MenuShape: Shape {

    var value: CGFloat

    var animatableData: CGFloat {
        get { return value }
        set { value = newValue }
    }

    func path(in rect: CGRect) -> Path {
        return Path { path in
            let width = rect.width - 100
            let height = rect.height

            path.move(to: CGPoint(x: width, y: height))
            path.addLine(to: CGPoint(x: 0, y: height))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: width, y: 0))

            path.move(to: CGPoint(x: width, y: 0))
            path.addCurve(to: CGPoint(x: width, y: height),
                          control1: CGPoint(x: width + value, y: height / 3),
                          control2: CGPoint(x: width - value, y: height / 2))
        }
    }
}

// MARK: - Menu Button (hamburger)
struct MenuButtonView: View {

    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        Button {
            withAnimation(.spring()) {
                settingsManager.showMenu.toggle()
            }
        } label: {
            Image("Menu")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
        }
        .accessibilityIdentifier("menu-button")
    }
}

// MARK: - Extensions

extension View {

    func getSafeArea() -> UIEdgeInsets {
        guard let screen = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return .zero
        }
        guard let safeArea = screen.windows.first?.safeAreaInsets else {
            return .zero
        }
        return safeArea
    }

    func getRect() -> CGRect {
        return UIScreen.main.bounds
    }
}

// MARK: - BlurView
struct BlurView: UIViewRepresentable {

    var style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: style))
        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
    }
}

// MARK: - Preview
struct TestView: View {

    @StateObject var settingsManager = SettingsManager()

    var body: some View {
        ZStack {
            if settingsManager.showMenu {
                MenuView()
                    .environmentObject(settingsManager)
                    .transition(.move(edge: .leading))
            }
        }
        .background(
            Image("Forest")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .edgesIgnoringSafeArea(.all)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        )
    }
}

#Preview {
    TestView()
}
