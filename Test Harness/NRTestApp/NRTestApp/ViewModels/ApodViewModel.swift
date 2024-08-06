//
//  ApodViewModel.swift
//  NRTestApp
//
//  Created by Mike Bruin on 1/12/23.
//

import Foundation
import NewRelic

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
                NewRelic.logInfo("ApodViewModel loadApodData finished.")

                self?.apodResponse.value = response
            case .failure(let error):
                NewRelic.logError("ApodViewModel loadApodData encountered error=error=\(error.localizedDescription).")

                self?.error.value = error
            }
        })
    }

    func loadApodDataAsync() async {
        do {
            let nasaUrl = ApodURL(date: Date.randomBetween(start: "2015-10-31", end: Date().dateString()))
            guard let url = URL(string: nasaUrl.url) else { return }
            
            var request = URLRequest(url: url)
            request.addValue("Sucsess", forHTTPHeaderField: "Test")

            let (data, _) = try await URLSession.shared.data(for: request)
            
            let decoded = try JSONDecoder().decode(ApodResult.self, from: data)
            
            if decoded.media_type == "video" {
                return await loadApodDataAsync()
            }
            NewRelic.logInfo("ApodViewModel loadApodDataAsync finished.")

            self.apodResponse.value = decoded
        } catch {

            NewRelic.logError("ApodViewModel loadApodDataAsync encountered error=\(error.localizedDescription).")

            self.error.value = error
        }
    }
}
