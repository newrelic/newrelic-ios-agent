import SwiftUI

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
                        AsyncImageView(imageURL: viewModel.images[index])
                            .frame(width: 150, height: 150)
                            .onAppear {
                                if index == viewModel.images.count - 5 {
                                    viewModel.loadMoreImages()
                                }
                            }
                    }
                }
                
                if viewModel.isLoading {
                    ProgressView()
                        .frame(height: 50)
                        .gridCellColumns(2)
                }
            }
            .padding()
        }
        .navigationTitle("Infinite Images")
        .onAppear {
            viewModel.loadInitialImages()
        }
    }
}

class InfiniteImageViewModel: ObservableObject {
    @Published var images: [String] = []
    @Published var isLoading = false
    
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let startIndex = self.images.count
            let newImages = Array(0..<20).map { index in
                self.imageURLs[(startIndex + index) % self.imageURLs.count] + "&id=\(startIndex + index)"
            }
            self.images.append(contentsOf: newImages)
            self.isLoading = false
        }
    }
}

struct AsyncImageView: View {
    let imageURL: String
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
