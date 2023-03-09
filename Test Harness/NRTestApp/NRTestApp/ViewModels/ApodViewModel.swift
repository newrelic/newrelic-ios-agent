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

    func loadApodDataAsync() async throws {
        let nasaUrl = ApodURL(date: Date.randomBetween(start: "2015-10-31", end: Date().dateString()))
        guard let url = URL(string: nasaUrl.url) else { return }

        let request = URLRequest(url: url)
        let (data, _) = try await URLSession.shared.data(for: request)

        let decoded = try JSONDecoder().decode(ApodResult.self, from: data)

        if decoded.media_type == "video" {
            return try await loadApodDataAsync()
        }

        self.apodResponse.value = decoded
    }
}
