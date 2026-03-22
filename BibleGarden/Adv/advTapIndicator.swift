import UIKit

// MARK: - Tap Indicator Overlay for Demo Recording
// Activated via --demo-recording launch argument.
//
// Использует отдельный UIWindow поверх ВСЕГО (включая sheets, alerts).
// 1-й тап — показывает индикатор и ПОГЛОЩАЕТ касание
// 2-й тап (в течение 2с в том же месте) — пропускается насквозь к кнопке
// Зритель видит: кружок появился → пауза → действие.

class TapInterceptView: UIView {

    private var previewPoint: CGPoint?
    private var previewTime: Date?
    private let hitRadius: CGFloat = 80
    private let previewTimeout: TimeInterval = 2.0
    private weak var passThroughEvent: UIEvent?

    private static var overlayWindow: UIWindow?

    /// Создаёт отдельный UIWindow поверх всего и устанавливает TapInterceptView.
    static func installOnKeyWindow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }

            let window = TapPassthroughWindow(windowScene: scene)
            window.windowLevel = .alert + 100  // Выше всех sheets и alerts
            window.backgroundColor = .clear
            window.isHidden = false

            let overlay = TapInterceptView()
            overlay.backgroundColor = .clear
            overlay.translatesAutoresizingMaskIntoConstraints = false
            window.addSubview(overlay)

            NSLayoutConstraint.activate([
                overlay.topAnchor.constraint(equalTo: window.topAnchor),
                overlay.bottomAnchor.constraint(equalTo: window.bottomAnchor),
                overlay.leadingAnchor.constraint(equalTo: window.leadingAnchor),
                overlay.trailingAnchor.constraint(equalTo: window.trailingAnchor)
            ])

            // Сохраняем ссылку чтобы окно не деаллоцировалось
            self.overlayWindow = window
        }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Тот же event — продолжаем пропускать
        if event != nil && event === passThroughEvent {
            return nil
        }

        // Второй тап рядом с preview?
        if let pp = previewPoint,
           let pt = previewTime,
           Date().timeIntervalSince(pt) < previewTimeout,
           hypot(point.x - pp.x, point.y - pp.y) < hitRadius {
            passThroughEvent = event
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.previewPoint = nil
                self?.previewTime = nil
                self?.passThroughEvent = nil
            }
            return nil
        }

        // Первый тап — перехватываем
        return self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first else { return }

        let location = touch.location(in: self)
        previewPoint = location
        previewTime = Date()
        showIndicator(at: location)
    }

    // MARK: - Indicator Animation

    private func showIndicator(at point: CGPoint) {
        let circleSize: CGFloat = 54
        let circle = UIView(frame: CGRect(
            x: point.x - circleSize / 2,
            y: point.y - circleSize / 2,
            width: circleSize,
            height: circleSize
        ))
        circle.backgroundColor = UIColor.white.withAlphaComponent(0.35)
        circle.layer.cornerRadius = circleSize / 2
        circle.layer.borderWidth = 2.5
        circle.layer.borderColor = UIColor.white.withAlphaComponent(0.9).cgColor
        circle.isUserInteractionEnabled = false

        self.addSubview(circle)

        // Появление
        circle.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        circle.alpha = 0
        UIView.animate(withDuration: 0.12, delay: 0, options: [.curveEaseOut]) {
            circle.transform = .identity
            circle.alpha = 1
        }

        // Пульсация
        UIView.animate(withDuration: 0.3, delay: 0.12, options: [.curveEaseInOut, .autoreverse]) {
            circle.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
        }

        // Затухание
        UIView.animate(withDuration: 0.35, delay: 0.5, options: [.curveEaseIn]) {
            circle.alpha = 0
            circle.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        } completion: { _ in
            circle.removeFromSuperview()
        }
    }
}

// MARK: - Passthrough Window
/// UIWindow который пропускает тапы, когда TapInterceptView решает их не перехватывать.
/// Без этого окно с высоким windowLevel блокировало бы ВСЕ тапы.
class TapPassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        // Если hitTest вернул саму window или nil — пропускаем (тап уходит к окну ниже)
        if result == nil || result === self {
            return nil
        }
        // Если TapInterceptView решил пропустить (вернул nil в своём hitTest) — тоже пропускаем
        return result
    }
}
