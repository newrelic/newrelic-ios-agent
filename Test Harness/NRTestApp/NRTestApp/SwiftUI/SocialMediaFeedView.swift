import SwiftUI

struct SocialMediaFeedView: View {
    @StateObject private var viewModel = SocialMediaViewModel()
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.posts) { post in
                    SocialMediaPostCard(post: post)
                        .onAppear {
                            if post.id == viewModel.posts.last?.id {
                                viewModel.loadMorePosts()
                            }
                        }
                }
                
                if viewModel.isLoading {
                    ProgressView()
                        .frame(height: 60)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Social Feed")
        .onAppear {
            viewModel.loadInitialPosts()
        }
    }
}

struct SocialMediaPostCard: View {
    let post: SocialMediaPost
    @State private var isLiked = false
    @State private var likeCount: Int
    @State private var isBookmarked = false
    
    init(post: SocialMediaPost) {
        self.post = post
        _likeCount = State(initialValue: post.likes)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with profile
            HStack(spacing: 12) {
                Circle()
                    .fill(post.profileColor)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(post.author.prefix(1))
                            .font(.headline)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.author)
                        .font(.headline)
                    Text(post.timeAgo)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.gray)
                }
            }
            .padding()
            
            // Post content
            Text(post.content)
                .font(.body)
                .padding(.horizontal)
                .padding(.bottom, 12)
            
            // Post image (if available)
            if let imageURL = post.imageURL {
                AsyncImageView(imageURL: imageURL)
                    .frame(height: 300)
                    .frame(maxWidth: .infinity)
                    .clipped()
            }
            
            // Action buttons
            HStack(spacing: 20) {
                Button(action: {
                    isLiked.toggle()
                    likeCount += isLiked ? 1 : -1
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .red : .gray)
                        Text("\(likeCount)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                
                Button(action: {}) {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.right")
                            .foregroundColor(.gray)
                        Text("\(post.comments)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                
                Button(action: {}) {
                    Image(systemName: "arrow.turn.up.right")
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button(action: {
                    isBookmarked.toggle()
                }) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundColor(isBookmarked ? .blue : .gray)
                }
            }
            .padding()
            
            Divider()
        }
    }
}

struct SocialMediaPost: Identifiable {
    let id: UUID
    let author: String
    let profileColor: Color
    let timeAgo: String
    let content: String
    let imageURL: String?
    let likes: Int
    let comments: Int
}

class SocialMediaViewModel: ObservableObject {
    @Published var posts: [SocialMediaPost] = []
    @Published var isLoading = false
    
    private let sampleAuthors = [
        "Sarah Johnson", "Mike Chen", "Emma Davis", "Alex Rodriguez",
        "Jessica Lee", "Tom Wilson", "Maya Patel", "Chris Anderson",
        "Lisa Kim", "David Brown", "Rachel Green", "James Taylor"
    ]
    
    private let sampleContent = [
        "Just finished an amazing hike at the mountains! The view was absolutely breathtaking. 🏔️ #nature #hiking",
        "New coffee shop opened downtown and I'm in love! ☕️ Best latte I've had in months.",
        "Working on an exciting new project. Can't wait to share it with you all! Stay tuned... 🚀",
        "Beautiful sunset today. Sometimes you just need to stop and appreciate the little things. 🌅",
        "Finally tried that new restaurant everyone's been talking about. The food was incredible! 🍜",
        "Weekend vibes! Time to relax and recharge. What are your plans? 😎",
        "Throwback to last summer's road trip. Missing those carefree days! 🚗",
        "Just finished reading an amazing book. Highly recommend it to anyone looking for a good read! 📚",
        "Home cooked meal tonight. Nothing beats fresh ingredients! 🍝",
        "Morning run complete! Starting the day off right. 💪 #fitness #motivation",
        "Concert last night was epic! Still riding that high. 🎵🎸",
        "Rainy days are perfect for staying in and watching movies. What's your favorite rainy day activity? ☔️"
    ]
    
    private let imageURLs = [
        "https://picsum.photos/400/300?random=",
        nil // Some posts won't have images
    ]
    
    private let colors: [Color] = [
        .blue, .green, .orange, .purple, .pink, .red, .indigo, .teal, .mint, .cyan
    ]
    
    private var postCounter = 0
    
    func loadInitialPosts() {
        guard posts.isEmpty else { return }
        posts = generatePosts(count: 10)
    }
    
    func loadMorePosts() {
        guard !isLoading else { return }
        isLoading = true
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            let newPosts = self.generatePosts(count: 5)
            self.posts.append(contentsOf: newPosts)
            self.isLoading = false
        }
    }
    
    private func generatePosts(count: Int) -> [SocialMediaPost] {
        var posts: [SocialMediaPost] = []
        
        for _ in 0..<count {
            let hasImage = Bool.random()
            let imageURL = hasImage ? "https://picsum.photos/400/300?random=\(postCounter)" : nil
            
            let post = SocialMediaPost(
                id: UUID(),
                author: sampleAuthors.randomElement()!,
                profileColor: colors.randomElement()!,
                timeAgo: generateTimeAgo(),
                content: sampleContent.randomElement()!,
                imageURL: imageURL,
                likes: Int.random(in: 5...500),
                comments: Int.random(in: 0...150)
            )
            
            posts.append(post)
            postCounter += 1
        }
        
        return posts
    }
    
    private func generateTimeAgo() -> String {
        let options = ["2m", "15m", "1h", "3h", "5h", "8h", "1d", "2d", "3d", "1w"]
        return options.randomElement()!
    }
}

// Preview
#Preview {
    NavigationView {
        SocialMediaFeedView()
    }
}
