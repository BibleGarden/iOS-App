import SwiftUI
import UIKit

// MARK: - Tap Indicator Overlay for Demo Recording
// Activated via --demo-recording launch argument.
// Shows animated circles at touch points for App Store video recording.

struct TapIndicatorOverlay: UIViewRepresentable {
    func makeUIView(context: Context) -> TapIndicatorView {
        let view = TapIndicatorView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: TapIndicatorView, context: Context) {}
}

class TapIndicatorView: UIView {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let window = self.window else { return }

        // Install gesture recognizer on the window to catch all touches
        let existingRecognizers = window.gestureRecognizers ?? []
        let alreadyInstalled = existingRecognizers.contains { $0 is TapIndicatorGestureRecognizer }
        if !alreadyInstalled {
            let recognizer = TapIndicatorGestureRecognizer(indicatorView: self)
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
            window.addGestureRecognizer(recognizer)
        }
    }

    func showTapAt(_ point: CGPoint) {
        let convertedPoint = self.convert(point, from: self.window)

        let circleSize: CGFloat = 50
        let circle = UIView(frame: CGRect(
            x: convertedPoint.x - circleSize / 2,
            y: convertedPoint.y - circleSize / 2,
            width: circleSize,
            height: circleSize
        ))
        circle.backgroundColor = UIColor.white.withAlphaComponent(0.4)
        circle.layer.cornerRadius = circleSize / 2
        circle.layer.borderWidth = 2
        circle.layer.borderColor = UIColor.white.withAlphaComponent(0.8).cgColor
        circle.isUserInteractionEnabled = false

        self.addSubview(circle)

        // Scale up and fade out animation
        circle.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseOut]) {
            circle.transform = .identity
        }

        UIView.animate(withDuration: 0.5, delay: 0.2, options: [.curveEaseIn]) {
            circle.alpha = 0
            circle.transform = CGAffineTransform(scaleX: 1.4, y: 1.4)
        } completion: { _ in
            circle.removeFromSuperview()
        }
    }
}

class TapIndicatorGestureRecognizer: UIGestureRecognizer {
    private weak var indicatorView: TapIndicatorView?

    init(indicatorView: TapIndicatorView) {
        self.indicatorView = indicatorView
        super.init(target: nil, action: nil)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        for touch in touches {
            let location = touch.location(in: self.view)
            indicatorView?.showTapAt(location)
        }
        // Don't claim the gesture — let it pass through
        self.state = .failed
    }
}
