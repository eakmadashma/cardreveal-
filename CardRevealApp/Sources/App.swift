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

struct WebContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(LocalHandler(), forURLScheme: "app")
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
