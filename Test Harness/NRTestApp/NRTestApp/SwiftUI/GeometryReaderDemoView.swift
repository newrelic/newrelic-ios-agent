//
//  GeometryReaderDemoView.swift
//  NRTestApp
//

import SwiftUI

struct GeometryReaderDemoView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {

                // MARK: 1 – Container size readout
                SectionHeader("1. Container Size Readout")
                GeometryReader { geo in
                    VStack(spacing: 8) {
                        Text("width:  \(Int(geo.size.width))")
                        Text("height: \(Int(geo.size.height))")
                        Text("safeArea top: \(Int(geo.safeAreaInsets.top))")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.blue.opacity(0.15))
                    .cornerRadius(12)
                }
                .frame(height: 100)
                .padding(.horizontal)

                // MARK: 2 – Proportional widths
                SectionHeader("2. Proportional Widths")
                GeometryReader { geo in
                    VStack(spacing: 8) {
                        ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { fraction in
                            Rectangle()
                                .fill(Color.orange.opacity(0.6))
                                .frame(width: geo.size.width * fraction, height: 28)
                                .overlay(
                                    Text("\(Int(fraction * 100))%")
                                        .font(.caption).foregroundColor(.white)
                                )
                        }
                    }
                }
                .frame(height: 160)
                .padding(.horizontal)

                // MARK: 3 – Diagonal gradient bar (uses full width)
                SectionHeader("3. Width-Matched Gradient Bar")
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.purple, .pink, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width, height: 60)
                    .cornerRadius(10)
                    .overlay(
                        Text("full width: \(Int(geo.size.width))pt")
                            .foregroundColor(.white)
                            .font(.callout)
                    )
                }
                .frame(height: 60)
                .padding(.horizontal)

                // MARK: 4 – Scroll offset tracking via preference key
                SectionHeader("4. Scroll Offset via PreferenceKey")
                ScrollOffsetExample()
                    .padding(.horizontal)

                Spacer(minLength: 32)
            }
            .padding(.top)
        }
        .navigationTitle("GeometryReader")
        .navigationBarTitleDisplayMode(.inline)
        .NRTrackView(name: "GeometryReaderDemoView")
    }
}

// MARK: - Scroll offset example

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ScrollOffsetExample: View {
    @State private var offset: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scroll offset: \(Int(offset))pt")
                .font(.subheadline)
                .monospacedDigit()
                .padding(.vertical, 4)

            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 12) {
                    ForEach(0..<12) { i in
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.teal.opacity(0.7))
                                .overlay(Text("Card \(i)").foregroundColor(.white))
                                .preference(
                                    key: ScrollOffsetKey.self,
                                    value: -geo.frame(in: .named("hscroll")).minX
                                )
                        }
                        .frame(width: 100, height: 80)
                    }
                }
                .padding(.horizontal)
            }
            .coordinateSpace(name: "hscroll")
            .onPreferenceChange(ScrollOffsetKey.self) { offset = $0 }
            .frame(height: 100)
        }
    }
}

// MARK: - Helper

private struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
    }
}
