import SwiftUI
import WebKit
import CoreMotion

@main
struct CardRevealApp: App {
    var body: some Scene {
        WindowGroup {
            WebContainer()
                .background(Color.black.ignoresSafeArea())
                .ignoresSafeArea()
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
                .defersSystemGestures(on: .all)
                .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        }
    }
}

/// Serves the bundled index.html under app://local so localStorage and IndexedDB work.
final class LocalHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url,
              let file = Bundle.main.url(forResource: "index", withExtension: "html"),
              let data = try? Data(contentsOf: file) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        let response = URLResponse(url: url, mimeType: "text/html",
                                   expectedContentLength: data.count,
                                   textEncodingName: "utf-8")
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}

/// The page calls this when the card has been pulled out and "close the app" is on.
/// It sends the app back to the Home Screen, then quits the process so it is fully closed.
final class QuitHandler: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        UIControl().sendAction(#selector(URLSessionTask.suspend),
                               to: UIApplication.shared, for: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { exit(0) }
    }
}

/// Listens for a sharp knock or tap on the phone and tells the page about it.
/// The page sends {on: Bool, th: Double}: turn listening on/off and set the strength (in g).
final class BumpHandler: NSObject, WKScriptMessageHandler {
    weak var webView: WKWebView?
    private let motion = CMMotionManager()
    private var threshold = 1.0
    private var lastFire = Date.distantPast

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let d = message.body as? [String: Any] else { return }
        if let th = d["th"] as? Double { threshold = th }
        if (d["on"] as? Bool) == true { start() } else { stop() }
    }

    private func start() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        lastFire = Date()
        motion.deviceMotionUpdateInterval = 1.0 / 100.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] m, _ in
            guard let self, let a = m?.userAcceleration else { return }
            let mag = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
            guard mag >= self.threshold,
                  Date().timeIntervalSince(self.lastFire) > 0.6 else { return }
            self.lastFire = Date()
            self.webView?.evaluateJavaScript("window.onBump && window.onBump(\(mag))")
        }
    }

    private func stop() {
        if motion.isDeviceMotionActive { motion.stopDeviceMotionUpdates() }
    }
}

struct WebContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(LocalHandler(), forURLScheme: "app")
        config.userContentController.add(QuitHandler(), name: "quit")
        let bump = BumpHandler()
        config.userContentController.add(bump, name: "bump")
        let web = WKWebView(frame: .zero, configuration: config)
        bump.webView = web
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.scrollView.bounces = false
        web.isOpaque = false
        web.backgroundColor = .black
        web.scrollView.backgroundColor = .black
        web.load(URLRequest(url: URL(string: "app://local/index.html")!))
        return web
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
