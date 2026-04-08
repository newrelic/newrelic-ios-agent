//
//  TintedSymbolsView.swift
//  NRTestApp
//
//  Created for testing tinted SF Symbols
//

import SwiftUI
import NewRelic

struct TintedSymbolsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Text("Tinted SF Symbols")
                    .font(.largeTitle)
                    .padding(.top)

                // Blue Tints
                VStack(spacing: 15) {
                    Text("Blue Tints")
                        .font(.headline)

                    HStack(spacing: 20) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.blue)
                            .font(.system(size: 24))

                        Image(systemName: "heart.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 30))

                        Image(systemName: "star.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 28))

                        Image(systemName: "bookmark.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 26))
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)

                // Red Tints
                VStack(spacing: 15) {
                    Text("Red Tints")
                        .font(.headline)

                    HStack(spacing: 20) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 30))

                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 28))

                        Image(systemName: "trash.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 26))
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)

                // Green Tints
                VStack(spacing: 15) {
                    Text("Green Tints")
                        .font(.headline)

                    HStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 30))

                        Image(systemName: "leaf.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 28))

                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 28))
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)

                // Purple Tints
                VStack(spacing: 15) {
                    Text("Purple Tints")
                        .font(.headline)

                    HStack(spacing: 20) {
                        Image(systemName: "moon.stars.fill")
                            .foregroundColor(.purple)
                            .font(.system(size: 30))

                        Image(systemName: "crown.fill")
                            .foregroundColor(.purple)
                            .font(.system(size: 28))

                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                            .font(.system(size: 26))
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)

                // Orange Tints
                VStack(spacing: 15) {
                    Text("Orange Tints")
                        .font(.headline)

                    HStack(spacing: 20) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 30))

                        Image(systemName: "sun.max.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 28))

                        Image(systemName: "bell.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 26))
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)

                // System Colors
                VStack(spacing: 15) {
                    Text("System Colors")
                        .font(.headline)

                    HStack(spacing: 20) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 26))

                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 26))

                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.primary)
                            .font(.system(size: 26))
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)

                // Custom Colors
                VStack(spacing: 15) {
                    Text("Custom Colors")
                        .font(.headline)

                    HStack(spacing: 20) {
                        Image(systemName: "paintbrush.fill")
                            .foregroundColor(Color(red: 0.2, green: 0.6, blue: 0.9))
                            .font(.system(size: 28))

                        Image(systemName: "wand.and.stars")
                            .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.5))
                            .font(.system(size: 28))

                        Image(systemName: "circle.hexagongrid.fill")
                            .foregroundColor(Color(red: 0.1, green: 0.8, blue: 0.7))
                            .font(.system(size: 28))
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)

                Spacer()
            }
            .padding()
        }
        .NRTrackView(name: "TintedSymbolsView")
    }
}

struct TintedSymbolsView_Previews: PreviewProvider {
    static var previews: some View {
        TintedSymbolsView()
    }
}
