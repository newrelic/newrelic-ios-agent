//
//  WebViewController.swift
//  NRTestApp
//
//  Created by Mike Bruin on 1/13/23.
//

import UIKit
#if os(iOS)
import WebKit

class WebViewController: UIViewController {
    let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Web View"
        webView.navigationDelegate = self
    }
    
    override func loadView() {
        super.loadView()

        if let url = URL(string: "https://www.newrelic.com") {
            webView.load(URLRequest(url: url))
            view = webView
        }
    }
}

extension WebViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("didStartProvisionalNavigation")
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("didFailProvisionalNavigation")
    }
    
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        print("authenticationChallenge:challenge")
        completionHandler(.performDefaultHandling, nil)
    }
        
    func webView(_ webView: WKWebView, authenticationChallenge challenge: URLAuthenticationChallenge, shouldAllowDeprecatedTLS decisionHandler: @escaping (Bool) -> Void) {
        print("authenticationChallenge:shouldAllowDeprecatedTLS")
        decisionHandler(true)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
        print("decidePolicyFor navigationResponse")
        return .allow
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        print("decidePolicyFor navigationAction")
        if let host = navigationAction.request.url?.host {
            if host.contains("newrelic.com") {
                decisionHandler(.allow)
                return
            }
        }

        decisionHandler(.cancel)
    }
}

#endif
