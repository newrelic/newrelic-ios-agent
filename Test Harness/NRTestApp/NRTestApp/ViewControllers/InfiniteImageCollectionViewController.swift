//
//  InfiniteImageCollectionViewController.swift
//  NRTestApp
//
//  Created by Mike Bruin on 8/25/25.
//
//  MobileViewTiming on an infinitely-scrolling image grid. This screen is the clearest case for the
//  API, because "displayed" and "usable" happen at genuinely different moments:
//
//      viewDidAppear   nothing yet                      -> agent records timeToInitialDisplay
//      laid out        spinners, but scrollable         -> markViewTiming("timeToInteractive")
//      images decoded  the first screenful is real      -> markViewTiming("timeToFullDisplay")
//
//  Appended pages are timed from when their fetch started rather than from the view's zero point, so
//  they go through recordViewTiming(_:milliseconds:) instead.
//

import UIKit
import NewRelic

class InfiniteImageCollectionViewController: UIViewController {
    
    private var collectionView: UICollectionView!
    private var images: [String] = []
    private var isLoading = false
    private let imageCache = NSCache<NSString, UIImage>()

    // MARK: - MobileViewTiming state

    /// Both marks describe one visit, so each is emitted once per appearance of this screen.
    private var didMarkInteractive = false
    private var didMarkFullDisplay = false

    /// How many of the first screenful of cells still owe a real image before this screen counts as
    /// fully displayed. Cells below the fold are deliberately not waited on -- they are not part of
    /// the first impression, and waiting on all 20 would time the network, not the screen.
    private var visibleImagesAwaited = 0
    private var visibleImagesDisplayed = 0

    /// The agent caps customer timings at 16 per view instance, and this list appends pages for as
    /// long as the user keeps scrolling. Budgeting the appends keeps the two marks above from being
    /// crowded out by a long scroll session.
    private static let appendTimingBudget = 8
    private var appendTimingsRecorded = 0
    
    @objc func nrMobileViewName() -> String? {
        "Infinite Images View Controller"
    }
    
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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Deferred one runloop turn on purpose, for two reasons:
        //
        //   * The agent's automatic MobileViews hook calls through to viewDidAppear: first and makes
        //     this screen the current view afterwards, so a mark placed inline here would be
        //     attributed to the screen the user just left.
        //   * The grid has no settled bounds until layout has run, and its bounds are what decide
        //     how many cells count as the first screenful.
        DispatchQueue.main.async { [weak self] in self?.markGridInteractive() }
    }
    
    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 150, height: 150)
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
#if os(iOS)

        collectionView.backgroundColor = .systemBackground
        #endif
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

        // Zero point for this page. It has nothing to do with when the view appeared, which is why
        // this one is recorded rather than marked.
        let pageStart = ProcessInfo.processInfo.systemUptime

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let startIndex = self.images.count
            let newImages = Array(repeating: "", count: 20).enumerated().map { index, _ in
                self.imageURLs[(startIndex + index) % self.imageURLs.count] + "&id=\(startIndex + index)"
            }
            self.images.append(contentsOf: newImages)

            CATransaction.begin()
            CATransaction.setCompletionBlock { [weak self] in
                self?.recordPageAppend(startedAt: pageStart)
            }
            self.collectionView.reloadData()
            CATransaction.commit()

            self.isLoading = false
        }
    }

    // MARK: - MobileViewTiming

    /// The grid is on screen, laid out, scrollable and tappable -- but every cell is still a spinner.
    /// That is exactly what Time to Interactive means: usable, not finished.
    private func markGridInteractive() {
        guard !didMarkInteractive else { return }
        didMarkInteractive = true

        // Derived from the layout rather than hard-coded, because how many cells fit is a property
        // of the device and orientation, not of the grid.
        //
        // Deliberately not indexPathsForVisibleItems: that reports every cell the collection view is
        // keeping alive, which here is twice what fits on screen -- and waiting on off-screen cells
        // would make timeToFullDisplay a measure of the network rather than of the screen.
        collectionView.layoutIfNeeded()
        let visibleRect = collectionView.bounds
        let onScreenCells = collectionView.collectionViewLayout
            .layoutAttributesForElements(in: visibleRect)?
            .filter { $0.representedElementCategory == .cell && $0.frame.intersects(visibleRect) }
            .count ?? 0
        visibleImagesAwaited = max(onScreenCells, 1)

        let marked = NewRelic.markViewTiming("timeToInteractive")
        NewRelic.logVerbose("markViewTiming(timeToInteractive) -> \(marked)  [awaiting \(visibleImagesAwaited) images]")

        // Images that already landed -- a warm cache serves them synchronously inside reloadData(),
        // and a fast network can beat this call -- are counted but were never checked against a
        // target, because there was not one yet. Check now, or for those cells the check never comes.
        markFullDisplayIfFirstScreenfulComplete()
    }

    /// One cell put a real image on screen.
    private func noteImageDisplayed() {
        guard !didMarkFullDisplay else { return }
        visibleImagesDisplayed += 1
        markFullDisplayIfFirstScreenfulComplete()
    }

    /// Once the whole first screenful shows real images, the screen is genuinely displayed -- the
    /// number the agent's timeToInitialDisplay cannot report, because at viewDidAppear there was
    /// nothing but spinners.
    ///
    /// If an image download fails, the count never completes and no timeToFullDisplay is recorded.
    /// That is the honest outcome: the screen never fully displayed, and a substituted value would
    /// count as a real one in every percentile.
    private func markFullDisplayIfFirstScreenfulComplete() {
        guard !didMarkFullDisplay,
              visibleImagesAwaited > 0,
              visibleImagesDisplayed >= visibleImagesAwaited else { return }
        didMarkFullDisplay = true

        let marked = NewRelic.markViewTiming("timeToFullDisplay")
        NewRelic.logVerbose("markViewTiming(timeToFullDisplay) -> \(marked)  [\(visibleImagesDisplayed) images shown]")
    }

    /// A page was appended. Its duration was measured here, so the agent is told the value rather
    /// than asked to derive one from an origin that does not apply.
    private func recordPageAppend(startedAt start: TimeInterval) {
        guard appendTimingsRecorded < Self.appendTimingBudget else { return }
        appendTimingsRecorded += 1

        let elapsedMs = (ProcessInfo.processInfo.systemUptime - start) * 1000
        let recorded = NewRelic.recordViewTiming("nextPageAppend", milliseconds: elapsedMs)
        NewRelic.logVerbose("recordViewTiming(nextPageAppend, \(Int(elapsedMs))ms) -> \(recorded)  [\(images.count) cells]")
    }
}

extension InfiniteImageCollectionViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCell", for: indexPath) as! ImageCollectionViewCell
        let imageURL = images[indexPath.item]
        // The cell reports back when a real image lands so this controller can decide when the first
        // screenful is complete. Note that the timing is marked here, once, and never from inside
        // configure(with:) itself -- a mark per cell would blow the per-view cap on the first scroll.
        cell.configure(with: imageURL, cache: imageCache) { [weak self] in
            self?.noteImageDisplayed()
        }
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
#if os(iOS)

        imageView.backgroundColor = .systemGray6
        #endif
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
    
    /// - Parameter onImageDisplayed: Called on the main thread once a real image -- from cache or
    ///   from the network -- is in the image view. Not called when the download fails.
    func configure(with imageURL: String,
                   cache: NSCache<NSString, UIImage>,
                   onImageDisplayed: (() -> Void)? = nil) {
        currentTask?.cancel()
        imageView.image = nil
        activityIndicator.startAnimating()
        
        let cacheKey = NSString(string: imageURL)
        
        if let cachedImage = cache.object(forKey: cacheKey) {
            imageView.image = cachedImage
            activityIndicator.stopAnimating()
            onImageDisplayed?()
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
                
                cache.setObject(image, forKey: cacheKey)
                self?.imageView.image = image
                onImageDisplayed?()
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
