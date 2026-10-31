import SwiftUI
import WebKit

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

struct WebContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(LocalHandler(), forURLScheme: "app")
        config.userContentController.add(QuitHandler(), name: "quit")
        let web = WKWebView(frame: .zero, configuration: config)
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
