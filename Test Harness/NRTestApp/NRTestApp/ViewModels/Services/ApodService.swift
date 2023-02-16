//
//  ApodService.swift
//  NRTestApp
//
//  Created by Mike Bruin on 1/12/23.
//

import UIKit

struct ApodService {
    
    func getApod(nasaURL: URL, completion: @escaping (Result<ApodResult, Error>) -> Void) {
        URLSession.shared.dataTask(with: nasaURL) { data, _, error in
            guard error == nil else {
                completion(.failure(error!))
                return
            }
            do {
                let decoded = try JSONDecoder().decode(ApodResult.self, from: data!)
                completion(.success(decoded))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
