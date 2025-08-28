//
//  SwiftUIViewRepresentableTestView.swift
//  NRTestApp
//
//  Created by Chris Dillard on 8/25/25.
//

import SwiftUI

// Customer provided SwiftUI code that was manifesting an issue with the New Relic iOS agent when using with UIViewControllerRepresentable and NRFeatureFlag_InteractionTracing and NRFeatureFlag_DefaultInteractions enabled.

@available(iOS 15.0, *)
struct SwiftUIViewRepresentableTestView: View {
    @State var items: [Int] = Array(0..<1000)
    
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(items, id: \.self) { index in
                    itemView(index)
                        .id(index)
                }
            }
        }
    }
    
    private func itemView(_ index: Int) -> some View {
        VStack(alignment: .leading) {
            imageView(index)
                
            Text("Item \(index)")
        }
        .padding()
    }
    
    private func imageView(_ index: Int) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit) // Force aspect ratio
            .frame(minHeight: 100)
            .overlay {
                OverlayView()
            }
    }
}

private struct OverlayView: UIViewControllerRepresentable {
    typealias UIViewControllerType = EmptyViewController

    func makeUIViewController(context: Context) -> UIViewControllerType {
        .init()
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        
    }
}

private class EmptyViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .red
    }
}
