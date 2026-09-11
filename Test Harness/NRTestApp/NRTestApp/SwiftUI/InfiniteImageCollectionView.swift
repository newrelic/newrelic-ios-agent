//
//  InfiniteImageCollectionView.swift
//  NRTestApp
//
//  The SwiftUI counterpart to InfiniteImageCollectionViewController, instrumented with
//  MobileViewTiming:
//
//    * markViewTiming("timeToFullDisplay") once the first screenful of images has actually rendered.
//      The .NRMobileView modifier's timeToInitialDisplay stops at onAppear, where the grid is still
//      empty placeholders, so this is the only report of when the screen showed something.
//
//    * recordViewTiming("nextPageLoad", milliseconds:) for each appended page, whose zero point is
//      when that page's fetch started -- not when the view appeared, which is the only origin
//      markViewTiming can use.
//

import SwiftUI
import NewRelic

struct InfiniteImageCollectionView: View {
    @StateObject private var viewModel = InfiniteImageViewModel()
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NRConditionalMaskView(maskAllImages: false) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(viewModel.images.indices, id: \.self) { index in
                        AsyncImageView(imageURL: viewModel.images[index],
                                       // Reported per image so the view model can tell when the
                                       // first screenful is real. The mark itself happens once, in
                                       // the view model -- marking per image would exhaust the
                                       // per-view cap on the first scroll.
                                       onLoaded: { viewModel.imageDidLoad(at: index) })
                            .frame(width: 150, height: 150)
                            .onAppear {
                                if index == viewModel.images.count - 5 {
                                    viewModel.loadMoreImages()
                                }
                            }
                    }
                }
                
                if viewModel.isLoading {
                    if #available(iOS 16.0, *) {
                        ProgressView()
                            .frame(height: 50)
                            .gridCellColumns(2)
                    } else {
                        // Fallback on earlier versions
                        ProgressView()
                            .frame(height: 50)

                    }
                }
            }
            .padding()
        }
        .navigationTitle("Infinite Images")
        .NRMobileView(name: "Infinite Images")
        .onAppear {
            viewModel.loadInitialImages()
        }
    }
}

class InfiniteImageViewModel: ObservableObject {
    @Published var images: [String] = []
    @Published var isLoading = false

    // MARK: - MobileViewTiming state

    /// Stand-in for "one screenful" on a two-column grid. The UIKit version derives this from the
    /// collection view's visible cells; SwiftUI does not hand out that information, so this is an
    /// approximation kept deliberately below the real fold rather than above it -- waiting on images
    /// the user cannot see would time the network instead of the screen.
    private static let firstScreenfulCount = 6

    /// Deduplicated by index, because SwiftUI re-runs onAppear whenever a lazy cell scrolls back in.
    private var firstScreenfulLoaded = Set<Int>()
    private var didMarkFullDisplay = false

    /// The agent caps customer timings at 16 per view instance. Appended pages are unbounded, the
    /// mark above is not, so the appends are the ones that get a budget.
    private static let pageTimingBudget = 8
    private var pageTimingsRecorded = 0
    
    private let imageURLs = [
        "https://picsum.photos/300/300?random=1",
        "https://picsum.photos/300/300?random=2",
        "https://picsum.photos/300/300?random=3",
        "https://picsum.photos/300/300?random=4",
        "https://picsum.photos/300/300?random=5"
    ]
    
    func loadInitialImages() {
        guard images.isEmpty else { return }
        images = Array(0..<20).map { index in
            imageURLs[index % imageURLs.count] + "&id=\(index)"
        }
    }
    
    func loadMoreImages() {
        guard !isLoading else { return }
        isLoading = true

        // Zero point for this page, which is unrelated to when the view appeared.
        let pageStart = ProcessInfo.processInfo.systemUptime
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let startIndex = self.images.count
            let newImages = Array(0..<20).map { index in
                self.imageURLs[(startIndex + index) % self.imageURLs.count] + "&id=\(startIndex + index)"
            }
            self.images.append(contentsOf: newImages)
            self.isLoading = false
            self.recordPageLoad(startedAt: pageStart)
        }
    }

    // MARK: - MobileViewTiming

    /// One image finished rendering. Once the first screenful has, the screen is genuinely displayed,
    /// and the mark is measured from the same instant the .NRMobileView modifier used for
    /// timeToInitialDisplay -- which is what makes subtracting the two meaningful.
    ///
    /// A failed download simply leaves the set short and no timeToFullDisplay is recorded: the screen
    /// never fully displayed, and a stand-in value would count as real in every percentile.
    func imageDidLoad(at index: Int) {
        guard !didMarkFullDisplay, index < Self.firstScreenfulCount else { return }
        firstScreenfulLoaded.insert(index)

        let awaited = min(Self.firstScreenfulCount, images.count)
        guard awaited > 0, firstScreenfulLoaded.count >= awaited else { return }
        didMarkFullDisplay = true

        let marked = NewRelic.markViewTiming("timeToFullDisplay")
        NewRelic.logVerbose("markViewTiming(timeToFullDisplay) -> \(marked)  [\(awaited) images rendered]")
    }

    /// A page was appended, timed by this screen rather than from the view's zero point.
    private func recordPageLoad(startedAt start: TimeInterval) {
        guard pageTimingsRecorded < Self.pageTimingBudget else { return }
        pageTimingsRecorded += 1

        let elapsedMs = (ProcessInfo.processInfo.systemUptime - start) * 1000
        let recorded = NewRelic.recordViewTiming("nextPageLoad", milliseconds: elapsedMs)
        NewRelic.logVerbose("recordViewTiming(nextPageLoad, \(Int(elapsedMs))ms) -> \(recorded)  [\(images.count) images]")
    }
}

struct AsyncImageView: View {
    let imageURL: String
    /// Called when a real image -- not the placeholder -- is on screen. Optional and defaulted so the
    /// other screens using this view are unaffected.
    var onLoaded: (() -> Void)? = nil
    @State private var image: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
            
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    // Reported from the Image's own onAppear rather than from the assignment in
                    // loadImage(), so the callback means "rendered" and not "decoded".
                    .onAppear { onLoaded?() }
            } else if isLoading {
                ProgressView()
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: imageURL) { _ in
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = URL(string: imageURL) else { return }
        
        // Check cache first
        let cacheKey = imageURL
        if let cachedImage = ImageCache.shared.object(forKey: cacheKey as NSString) {
            self.image = cachedImage
            return
        }
        
        isLoading = true
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                guard let data = data, let uiImage = UIImage(data: data) else { return }
                
                ImageCache.shared.setObject(uiImage, forKey: cacheKey as NSString)
                self.image = uiImage
            }
        }.resume()
    }
}

class ImageCache {
    static let shared = NSCache<NSString, UIImage>()
}
