//
//  ExpenseImage.swift
//  ExpensesTracker
//
//  Stands in for Coil's AsyncImage, which the Compose screens used to load Unsplash photographs.
//
//  Those URLs are not usable here: this app has no network beyond its own localhost stub, the images are
//  not ours to redistribute, and a demo screen full of failed loads teaches nothing. A gradient tile with
//  the category's initial is deterministic, needs no assets, and — because the hue derives from the
//  category name — gives each category a consistent colour across the list and detail screens.
//

import SwiftUI

struct ExpenseImage: View {

    let item: ExpenseItem
    var cornerRadius: CGFloat = 8

    var body: some View {
        LinearGradient(colors: [Self.color(for: item.category, brightness: 0.86),
                               Self.color(for: item.category, brightness: 0.52)],
                      startPoint: .topLeading,
                      endPoint: .bottomTrailing)
            .overlay {
                Text(Self.initial(for: item.category))
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .accessibilityLabel("\(item.category) expense")
    }

    private static func initial(for category: String) -> String {
        String(category.prefix(1)).uppercased()
    }

    /// Stable hue per category name, so "Food" is the same colour everywhere it appears.
    private static func color(for category: String, brightness: Double) -> Color {
        var hash = 0
        for scalar in category.unicodeScalars {
            hash = (hash &* 31 &+ Int(scalar.value)) % 360
        }
        return Color(hue: Double(hash) / 360.0, saturation: 0.55, brightness: brightness)
    }
}
