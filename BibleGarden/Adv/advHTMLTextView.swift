import SwiftUI
import WebKit

struct HTMLTextView: UIViewRepresentable {
    let htmlContent: String
    @Binding var scrollToVerse: Int?
    var isScrollEnabled: Bool = true
    var onScrollMetricsChanged: ((Double, Bool) -> Void)? = nil
    var onHighlightedVerseChanged: ((String) -> Void)? = nil
    var accessibilityIdentifier: String? = nil
    var localizedPauseUnit: String? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = isScrollEnabled
        webView.scrollView.bounces = true
        webView.scrollView.alwaysBounceVertical = true
        webView.scrollView.decelerationRate = .normal

        // Set transparent background
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
        webView.scrollView.backgroundColor = UIColor.clear

        webView.loadHTMLString(htmlContent, baseURL: nil)
        if let accessibilityIdentifier {
            webView.accessibilityIdentifier = accessibilityIdentifier
        }
        webView.accessibilityValue = ""
        
        webView.scrollView.delaysContentTouches = false
        webView.scrollView.delegate = context.coordinator
        
        context.coordinator.webView = webView
        return webView
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.navigationDelegate = nil
        webView.scrollView.delegate = nil
        coordinator.detach()
    }

    private func highlightScript(for elementID: String) -> String {
        """
        (function() {
            var previous = document.querySelector('.highlighted-verse');
            if (previous) {
                previous.classList.remove('highlighted-verse');
            }

            var target = document.getElementById('\(elementID)');
            if (!target) {
                return '';
            }

            // Directly scroll the verse/element into view to ensure it is visible,
            // regardless of how large the parent unit is.
            // We position it at 1/5 of the screen height to account for the bottom panel.
            var headerOffset = window.innerHeight / 5;
            var elementPosition = target.getBoundingClientRect().top;
            var offsetPosition = elementPosition + window.pageYOffset - headerOffset;

            window.scrollTo({
                top: offsetPosition,
                behavior: 'smooth'
            });

            target.classList.add('highlighted-verse');
            return target.id || '';
        })();
        """
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updatePauseUnit(in: webView)
        // If scrollToVerse changes and webView is loaded, execute JavaScript
        if let verse = scrollToVerse, context.coordinator.webViewLoaded {
            let elementID = verse <= 0 ? "top" : "verse-\(verse)"
            context.coordinator.applyHighlight(elementID: elementID, in: webView)

            // Reset scrollToVerse to nil to prevent repeated scrolling
            DispatchQueue.main.async {
                scrollToVerse = nil
            }
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate, UIScrollViewDelegate {
        var parent: HTMLTextView?
        var webViewLoaded = false
        weak var webView: WKWebView?
        private var lastSentProgress: Double = -1
        private var lastSentAtBottom: Bool = false
        private var displayedPauseUnit: String?
        private let highlightedVerseQuery = """
            (function() {
                var current = document.querySelector('.highlighted-verse');
                return current ? current.id : '';
            })();
            """

        init(_ parent: HTMLTextView) {
            self.parent = parent
            self.displayedPauseUnit = parent.localizedPauseUnit
        }

        func updatePauseUnit(in webView: WKWebView) {
            guard webViewLoaded, let unit = parent?.localizedPauseUnit,
                  unit != displayedPauseUnit else { return }
            let encodedUnit = String(data: try! JSONEncoder().encode(unit), encoding: .utf8)!
            let script = """
                document.querySelectorAll('[data-pause-seconds]').forEach(function(span) {
                    span.textContent = span.dataset.pauseSeconds + ' ' + \(encodedUnit);
                });
                """
            webView.evaluateJavaScript(script) { _, error in
                if let error { assertionFailure("Failed to update pause label: \(error)") }
            }
            displayedPauseUnit = unit
        }

        func detach() {
            parent = nil
            webView = nil
            webViewLoaded = false
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let parent = parent else { return }
            webViewLoaded = true
            updatePauseUnit(in: webView)

            // If scrollToVerse is set, execute JavaScript to scroll
            if let verse = parent.scrollToVerse {
                let elementID = verse <= 0 ? "top" : "verse-\(verse)"
                applyHighlight(elementID: elementID, in: webView)

                DispatchQueue.main.async {
                    self.parent?.scrollToVerse = nil
                }
            }

            reportHighlightedVerse(from: webView)

            // Send initial scroll metrics even if user does not scroll.
            // This is important for short chapters that fully fit on screen.
            sendScrollMetrics(from: webView.scrollView, force: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self, weak webView] in
                guard let self = self, let webView = webView, self.parent != nil else { return }
                self.reportHighlightedVerse(from: webView)
                self.sendScrollMetrics(from: webView.scrollView, force: true)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self, weak webView] in
                guard let self = self, let webView = webView, self.parent != nil else { return }
                self.reportHighlightedVerse(from: webView)
                self.sendScrollMetrics(from: webView.scrollView, force: true)
            }
        }

        func reportHighlightedVerse(from webView: WKWebView) {
            guard let parent = parent else { return }
            webView.evaluateJavaScript(highlightedVerseQuery) { result, _ in
                let verseID = (result as? String) ?? ""
                DispatchQueue.main.async {
                    webView.accessibilityValue = verseID
                    parent.onHighlightedVerseChanged?(verseID)
                }
            }
        }

        func applyHighlight(elementID: String, in webView: WKWebView) {
            guard let parent = parent else { return }
            webView.evaluateJavaScript(parent.highlightScript(for: elementID)) { result, _ in
                let verseID = (result as? String) ?? ""
                DispatchQueue.main.async {
                    webView.accessibilityValue = verseID
                    parent.onHighlightedVerseChanged?(verseID)
                }
            }
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            sendScrollMetrics(from: scrollView, force: false)
        }

        private func sendScrollMetrics(from scrollView: UIScrollView, force: Bool) {
            guard let parent = parent else { return }
            guard parent.isScrollEnabled else { return }

            let contentHeight = scrollView.contentSize.height
            let visibleHeight = scrollView.bounds.height

            // WKWebView may report zero/tiny contentSize before content is rendered.
            // Ignore scroll metrics until content is meaningfully laid out.
            guard contentHeight > visibleHeight * 0.5 else { return }

            let maxOffset = max(contentHeight - visibleHeight, 0)

            let progress: Double
            if maxOffset <= 0 {
                progress = 1
            } else {
                progress = min(max(Double(scrollView.contentOffset.y / maxOffset), 0), 1)
            }

            let bottomThreshold: CGFloat = 24
            let isAtBottom = scrollView.contentOffset.y + visibleHeight >= contentHeight - bottomThreshold

            let shouldSend = force || abs(progress - lastSentProgress) >= 0.02 || isAtBottom != lastSentAtBottom
            guard shouldSend else { return }

            lastSentProgress = progress
            lastSentAtBottom = isAtBottom
            parent.onScrollMetricsChanged?(progress, isAtBottom)
        }
    }
}
