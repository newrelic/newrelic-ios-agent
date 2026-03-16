//
//  CacheExampleViewController.swift
//  NRTestApp
//
//  Created by Claude on 3/16/26.
//

import UIKit

class ImageDownloader {

    // Line removed: NSCache for storing downloaded images

    func downloadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        // 1. Create URL from string
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            completion(nil)
            return
        }

        // Lines removed: Check NSCache first

        // 3. If not in cache, download from network
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadRevalidatingCacheData // Forces the 304 check

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            let httpResponse = response as? HTTPURLResponse

            if let code = httpResponse?.statusCode {
                print("--- NETWORK TRACE ---")
                print("URL: \(urlString)")
                print("STATUS CODE RECEIVED BY APP: \(code)")
                print("---------------------")
            }

            if let data = data, let image = UIImage(data: data) {
                // Line removed: Save to NSCache
                DispatchQueue.main.async {
                    completion(image)
                }
            } else {
                print("❌ Invalid image data - check your Charles Trust settings")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
        task.resume()
    }
}

class CacheExampleViewController: UIViewController {

    private var imageView = UIImageView()
    private let imageDownloader = ImageDownloader()

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        setupImageView()
        loadImage()
    }

    private func setupView() {
        view.backgroundColor = .systemBackground
        title = "Cache Example"
    }

    private func setupImageView() {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .systemGray5
        imageView.layer.cornerRadius = 8
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = UIColor.systemGray3.cgColor

        // Set a placeholder image or system image
        imageView.image = UIImage(systemName: "photo.on.rectangle.angled")
        imageView.tintColor = .systemBlue

        view.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 200),
            imageView.heightAnchor.constraint(equalToConstant: 200)
        ])
    }

    private func loadImage() {
        let imageUrl = "https://digitalcontent.api.tesco.com/v2/media/ghs/962adadd-c8af-4bb4-ba4d-6ac4e29d36d3/071beb5c-9c5d-42b4-b1c0-a0829af71817_532294993.jpeg?h=225&w=225"

        // Download image (first time - will download)
        imageDownloader.downloadImage(from: imageUrl) { [weak self] image in
            self?.imageView.image = image ?? UIImage(systemName: "photo")
        }

        // Download same image again (will use NSCache)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.imageDownloader.downloadImage(from: imageUrl) { image in
                self?.imageView.image = image ?? UIImage(systemName: "photo")
            }
        }
    }
}