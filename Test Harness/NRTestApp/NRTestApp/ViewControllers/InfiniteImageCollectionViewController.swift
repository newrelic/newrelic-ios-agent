//
//  InfiniteImageCollectionViewController.swift
//  NRTestApp
//
//  Created by Mike Bruin on 8/25/25.
//

import UIKit

class InfiniteImageCollectionViewController: UIViewController {
    
    private var collectionView: UICollectionView!
    private var images: [String] = []
    private var isLoading = false
    private let imageCache = NSCache<NSString, UIImage>()
    
    // Sample image URLs
    private let imageURLs = [
        "https://picsum.photos/300/300?random=1",
        "https://picsum.photos/300/300?random=2",
        "https://picsum.photos/300/300?random=3",
        "https://picsum.photos/300/300?random=4",
        "https://picsum.photos/300/300?random=5"
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Infinite Images"
        view.backgroundColor = .white
        setupCollectionView()
        loadInitialImages()
    }
    
    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 150, height: 150)
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(ImageCollectionViewCell.self, forCellWithReuseIdentifier: "ImageCell")
        
        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func loadInitialImages() {
        images = Array(repeating: "", count: 20).enumerated().map { index, _ in
            imageURLs[index % imageURLs.count] + "&id=\(index)"
        }
        collectionView.reloadData()
    }
    
    private func loadMoreImages() {
        guard !isLoading else { return }
        isLoading = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let startIndex = self.images.count
            let newImages = Array(repeating: "", count: 20).enumerated().map { index, _ in
                self.imageURLs[(startIndex + index) % self.imageURLs.count] + "&id=\(startIndex + index)"
            }
            self.images.append(contentsOf: newImages)
            self.collectionView.reloadData()
            self.isLoading = false
        }
    }
}

extension InfiniteImageCollectionViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCell", for: indexPath) as! ImageCollectionViewCell
        let imageURL = images[indexPath.item]
        cell.configure(with: imageURL, cache: imageCache)
        return cell
    }
}

extension InfiniteImageCollectionViewController: UICollectionViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let height = scrollView.frame.size.height
        
        if offsetY > contentHeight - height - 100 {
            loadMoreImages()
        }
    }
}

class ImageCollectionViewCell: UICollectionViewCell {
    
    private let imageView = UIImageView()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private var currentTask: URLSessionDataTask?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(imageView)
        contentView.addSubview(activityIndicator)
        
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .systemGray6
        imageView.layer.cornerRadius = 8
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            activityIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    func configure(with imageURL: String, cache: NSCache<NSString, UIImage>) {
        currentTask?.cancel()
        imageView.image = nil
        activityIndicator.startAnimating()
        
        let cacheKey = NSString(string: imageURL)
        
        if let cachedImage = cache.object(forKey: cacheKey) {
            imageView.image = cachedImage
            activityIndicator.stopAnimating()
            return
        }
        
        guard let url = URL(string: imageURL) else {
            activityIndicator.stopAnimating()
            return
        }
        
        currentTask = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
                
                guard let data = data, let image = UIImage(data: data) else { return }
                image.NRSessionReplayImageURL = url
                cache.setObject(image, forKey: cacheKey)
                self?.imageView.image = image
            }
        }
        currentTask?.resume()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        currentTask?.cancel()
        imageView.image = nil
        activityIndicator.stopAnimating()
    }
}
