import Foundation
import SwiftUI

struct Activity: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
    let timestamp: Date
}

struct ChartStat: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let icon: String
    let color: Color
    let trend: Trend

    enum Trend {
        case up, down
    }
}

struct Metric: Identifiable {
    let id = UUID()
    let name: String
    let value: Double
    let timestamp: Date
}
