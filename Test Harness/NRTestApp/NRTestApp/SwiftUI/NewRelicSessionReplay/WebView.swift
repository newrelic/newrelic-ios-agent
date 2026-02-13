import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        // Create a configuration for the WKWebView
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptEnabled = true // Enable JavaScript

        // Initialize the WKWebView with the configuration
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.uiDelegate = context.coordinator
        webView.navigationDelegate = context.coordinator

        // Load the initial URL
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.load(URLRequest(url: url))
    }

    class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("Navigation started")
        }

        // Handle pop-up windows by loading the URL in the same web view
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            print("***PopUp***")
            if let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }

        // Handle JavaScript alerts
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            let alert = UIAlertController(title: "Alert", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in completionHandler() }))
            DispatchQueue.main.async {
                if let rootVC = UIApplication.shared.windows.first?.rootViewController {
                    rootVC.present(alert, animated: true, completion: nil)
                }
            }
        }
    }
}

struct WebContentView: View {
    @State private var urlString: String = "https://uat.groupbenefits.manulife.ca/gb/member-portal/secured/member/yourBenefits/benefitsCard"
    @State private var currentURL: URL = URL(string: "https://uat.groupbenefits.manulife.ca/gb/member-portal/secured/member/yourBenefits/benefitsCard")!

    var body: some View {
        VStack {
            TextField("Enter URL", text: $urlString, onCommit: loadURL)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            WebView(url: currentURL)
                .edgesIgnoringSafeArea(.all)
        }
    }

    private func loadURL() {
        if let url = URL(string: urlString) {
            currentURL = url
        } else {
            print("Invalid URL")
        }
    }
}

