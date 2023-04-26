//
//  ApodViewModel.swift
//  NRTestApp
//
//  Created by Mike Bruin on 1/12/23.
//

import Foundation

class ApodViewModel {
    let apodResponse: Variable<ApodResult?> = Variable(nil)
    let error: Variable<Error?> = Variable(nil)
    
    private let service = ApodService()
    
    func loadApodData() {
        let nasaUrl = ApodURL(date: Date.randomBetween(start: "2015-10-31", end: Date().dateString()))
        service.getApod(nasaURL: URL(string: nasaUrl.url)!, completion: { [weak self] result in
            switch result {
            case .success(let response):
                // We do not want a video, so if we get one try again
                if response.media_type == "video"{
                    self?.loadApodData()
                    return
                }
                self?.apodResponse.value = response
            case .failure(let error):
                self?.error.value = error
            }
        })
    }

    func loadApodDataAsync() async {
        do {
            let nasaUrl = ApodURL(date: Date.randomBetween(start: "2015-10-31", end: Date().dateString()))
            guard let url = URL(string: nasaUrl.url) else { return }
            
            let request = URLRequest(url: url)
            var data:Data?
            if #available(iOS 15.0, tvOS 15.0, *) {
                (data, _) = try await URLSession.shared.data(for: request, delegate: apodDelegate())
            } else {
                (data, _) = try await URLSession.shared.data(for: request)
            }
            
            let decoded = try JSONDecoder().decode(ApodResult.self, from: data!)
            
            if decoded.media_type == "video" {
                return await loadApodDataAsync()
            }
            
            self.apodResponse.value = decoded
        } catch {
            self.error.value = error
        }
    }
}

class apodDelegate: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate {
    
    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        print("Used")
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        print("Not Used?")
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        print("Used")
        print(metrics)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        print("Not Used?")
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        print("Used Occasionally?")
        return (URLSession.AuthChallengeDisposition.performDefaultHandling, URLCredential())
    }
    
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        print("Not Used?")
    }
    
    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        print("Not Used?")
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        print("Not Used?")
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        print("Not Used?")
        print(data)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
        print("Not Used?")
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse) async -> URLSession.ResponseDisposition {
        print("Not Used?")
        return URLSession.ResponseDisposition.allow
    }
}
