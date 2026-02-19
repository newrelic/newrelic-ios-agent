//
//  URLCacheTestViewController.swift
//  NRTestApp
//
//  Created for testing URLCache and NSCache with image downloads
//

import UIKit

class ImageDownloader {

    // NSCache for storing downloaded images
    private static var imageCache = NSCache<NSURL, UIImage>()

    func downloadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        // 1. Create URL from string
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            completion(nil)
            return
        }

        let nsurl = url as NSURL

        // 2. Check NSCache first
        if let cachedImage = ImageDownloader.imageCache.object(forKey: nsurl) {
            print("✅ Using cached image for: \(urlString)")
            DispatchQueue.main.async {
                completion(cachedImage)
            }
            return
        }

        print("📥 Downloading image from: \(urlString)")

        // 3. Create URLRequest
        var request = URLRequest(url: url)
        // 4. Use URLSession dataTask with the specified method
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle error
            if let error = error {
                print("❌ Error downloading image: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            // Check data
            guard let data = data, let image = UIImage(data: data) else {
                print("❌ Invalid image data")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            // 5. Store in NSCache
            ImageDownloader.imageCache.setObject(image, forKey: nsurl)
            print("💾 Image cached in NSCache")

            DispatchQueue.main.async {
                completion(image)
            }
        }

        task.resume()
    }
}

class URLCacheTestViewController: UIViewController {

    private let imageDownloader = ImageDownloader()
    private let imageView = UIImageView()
    private let statusLabel = UILabel()
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    // Test image URL
    private let imageUrl = "https://picsum.photos/id/237/200/300"

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        title = "URL Cache Test"

        setupScrollView()
        setupStackView()
        setupImageView()
        setupStatusLabel()

        // Download image (first time - will download)
        imageDownloader.downloadImage(from: imageUrl) { [weak self] image in
            self?.imageView.image = image ?? UIImage(systemName: "photo")
            self?.updateStatus("First download completed")
        }

        // Download same image again (will use NSCache)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self = self else { return }
            self.updateStatus("Requesting image again after 5 seconds...")
            self.imageDownloader.downloadImage(from: self.imageUrl) { image in
                self.imageView.image = image ?? UIImage(systemName: "photo")
                self.updateStatus("Second request completed (should use cache)")
            }
        }
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupStackView() {
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.alignment = .fill
        stackView.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stackView.isLayoutMarginsRelativeArrangement = true

        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    private func setupImageView() {
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .secondarySystemBackground
        imageView.layer.cornerRadius = 8
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false

        // Placeholder
        imageView.image = UIImage(systemName: "photo")
        imageView.tintColor = .systemGray

        stackView.addArrangedSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.heightAnchor.constraint(equalToConstant: 300)
        ])
    }

    private func setupStatusLabel() {
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.font = UIFont.systemFont(ofSize: 14)
        statusLabel.textColor = .secondaryLabel
        statusLabel.text = "Downloading image..."

        stackView.addArrangedSubview(statusLabel)
    }

    private func updateStatus(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel.text = message
        }
    }
}
