//
//  NRTestAppFakeNavigationAction.swift
//  NRTestAppTests
//
//  Created by Mike Bruin on 3/20/23.
//

import XCTest
import WebKit
@testable import NRTestApp

final class FakeNavigationAction: WKNavigationAction {
    let urlRequest: URLRequest
    
    var receivedPolicy: WKNavigationActionPolicy?
    
    override var request: URLRequest { urlRequest }

    init(urlRequest: URLRequest) {
        self.urlRequest = urlRequest
        super.init()
    }
    
    convenience init(url: URL) {
        self.init(urlRequest: URLRequest(url: url))
    }
    
    func decisionHandler(_ policy: WKNavigationActionPolicy) {
        self.receivedPolicy = policy
    }
}

final class FakeNavigationResponse: WKNavigationResponse {
    let urlRequest: URLRequest
    
    var receivedPolicy: WKNavigationResponsePolicy?
    
    init(urlRequest: URLRequest) {
        self.urlRequest = urlRequest
        super.init()
    }
    
    convenience init(url: URL) {
        self.init(urlRequest: URLRequest(url: url))
    }
    
    func decisionHandler(_ policy: WKNavigationResponsePolicy) {
        self.receivedPolicy = policy
    }
}

final class FakeURLAuthenticationChallenge: URLAuthenticationChallenge {

    var receivedChallenge: URLSession.AuthChallengeDisposition?
    var receivedCredential: URLCredential?
    
    override init(protectionSpace space: URLProtectionSpace, proposedCredential credential: URLCredential?, previousFailureCount: Int, failureResponse response: URLResponse?, error: Error?, sender: URLAuthenticationChallengeSender) {
        super.init(protectionSpace: space, proposedCredential: credential, previousFailureCount: previousFailureCount, failureResponse: response, error: error, sender: sender)
    }
    
    override init() {
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func completionHandler(challenge: URLSession.AuthChallengeDisposition, credential: URLCredential?) {
        self.receivedCredential = credential
        self.receivedChallenge = challenge
    }
}
