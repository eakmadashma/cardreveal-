import SwiftUI
import WebKit
import CoreMotion

@main
struct CardRevealApp: App {
    var body: some Scene {
        WindowGroup {
            WebView()
                .background(Color.black.ignoresSafeArea())
                .ignoresSafeArea()
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
                .defersSystemGestures(on: .all)
                .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        }
    }
}

/// One helper for everything the page needs from the phone:
/// serves index.html at app://local, quits the app on "quit",
/// and listens for knocks on "bump", replying with window.onBump(g).
final class Bridge: NSObject, WKURLSchemeHandler, WKScriptMessageHandler {
    weak var web: WKWebView?
    private let motion = CMMotionManager()
    private var threshold = 1.0
    private var last = Date()

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url,
              let file = Bundle.main.url(forResource: "index", withExtension: "html"),
              let data = try? Data(contentsOf: file) else {
            return task.didFailWithError(URLError(.fileDoesNotExist))
        }
        task.didReceive(URLResponse(url: url, mimeType: "text/html",
                                    expectedContentLength: data.count, textEncodingName: "utf-8"))
        task.didReceive(data)
        task.didFinish()
    }
    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "quit" {
            UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { exit(0) }
            return
        }
        let body = message.body as? [String: Any]
        threshold = body?["th"] as? Double ?? threshold
        guard body?["on"] as? Bool == true else { return motion.stopDeviceMotionUpdates() }
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        last = Date()
        motion.deviceMotionUpdateInterval = 0.01
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let a = data?.userAcceleration else { return }
            let g = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
            guard g >= self.threshold, Date().timeIntervalSince(self.last) > 0.6 else { return }
            self.last = Date()
            self.web?.evaluateJavaScript("window.onBump&&window.onBump(\(g))")
        }
    }
}

struct WebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let bridge = Bridge()
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(bridge, forURLScheme: "app")
        for name in ["quit", "bump"] { config.userContentController.add(bridge, name: name) }
        let web = WKWebView(frame: .zero, configuration: config)
        bridge.web = web
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.scrollView.bounces = false
        web.isOpaque = false
        web.backgroundColor = .black
        web.scrollView.backgroundColor = .black
        web.load(URLRequest(url: URL(string: "app://local/index.html")!))
        return web
    }
    func updateUIView(_ web: WKWebView, context: Context) {}
}
