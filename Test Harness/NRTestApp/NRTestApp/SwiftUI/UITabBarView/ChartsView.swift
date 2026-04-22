import SwiftUI
import Charts
import NewRelic

@available(iOS 17.0, *)
struct ChartsView: View {
    @StateObject private var viewModel = ChartsViewModel()
    @State private var selectedChart = 0

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Picker("Chart Type", selection: $selectedChart) {
                        Text("Line Chart").tag(0)
                        Text("Bar Chart").tag(1)
                        Text("Pie Chart").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    .onChange(of: selectedChart) { newValue in
                        NewRelic.recordCustomEvent("ChartTypeChanged",
                                                  attributes: ["chartType": ["Line", "Bar", "Pie"][newValue]])
                    }

                    if selectedChart == 0 {
                        LineChartViewNative(data: viewModel.lineChartData)
                            .frame(height: 300)
                            .padding()
                    } else if selectedChart == 1 {
                        BarChartViewNative(data: viewModel.barChartData)
                            .frame(height: 300)
                            .padding()
                    } else {
                        PieChartViewNative(data: viewModel.pieChartData)
                            .frame(height: 300)
                            .padding()
                    }

                    // Stats Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(viewModel.stats) { stat in
                            ChartStatCard(stat: stat)
                        }
                    }
                    .padding()

                    // Time Series Data
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Metrics")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(viewModel.recentMetrics) { metric in
                            MetricRow(metric: metric)
                        }
                    }
                }
            }
            .navigationTitle("Analytics")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        refreshCharts()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                NewRelic.recordBreadcrumb("ChartsView appeared")
                viewModel.loadData()
            }
        }
    }

    private func refreshCharts() {
        let interactionId = NewRelic.startInteraction(withName: "RefreshCharts")
        NewRelic.recordMetric(withName: "Charts/Refresh", category: "User Action", value: 1)

        viewModel.loadData()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NewRelic.stopCurrentInteraction(interactionId)
        }
    }
}

// MARK: - Native SwiftUI Line Chart
@available(iOS 16.0, *)
struct LineChartViewNative: View {
    let data: [ChartDataPoint]

    var body: some View {
        Chart(data) { point in
            LineMark(
                x: .value("Time", point.x),
                y: .value("Revenue", point.y)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(.blue)
            .symbol {
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .chartXAxis {
            AxisMarks(position: .bottom)
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }
}

// MARK: - Native SwiftUI Bar Chart
@available(iOS 16.0, *)
struct BarChartViewNative: View {
    let data: [ChartDataPoint]

    let colors: [Color] = [.green, .blue, .purple, .orange, .red, .teal]

    var body: some View {
        Chart(data) { point in
            BarMark(
                x: .value("Month", point.x),
                y: .value("Sales", point.y)
            )
            .foregroundStyle(colors[Int(point.x) % colors.count])
        }
        .chartXAxis {
            AxisMarks(position: .bottom)
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }
}

// MARK: - Native SwiftUI Pie Chart
@available(iOS 17.0, *)
struct PieChartViewNative: View {
    let data: [PieChartDataPoint]

    let colors: [Color] = [.red, .orange, .yellow, .green, .blue]

    var body: some View {
        Chart(data) { point in
            SectorMark(
                angle: .value("Value", point.value),
                innerRadius: .ratio(0.4),
                angularInset: 1.5
            )
            .foregroundStyle(colors[data.firstIndex(where: { $0.id == point.id }) ?? 0 % colors.count])
            .annotation(position: .overlay) {
                Text(String(format: "%.0f%%", point.value / data.map { $0.value }.reduce(0, +) * 100))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .chartLegend(position: .bottom, alignment: .center, spacing: 10) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(data) { point in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(colors[data.firstIndex(where: { $0.id == point.id }) ?? 0 % colors.count])
                            .frame(width: 10, height: 10)
                        Text(point.label)
                            .font(.caption)
                    }
                }
            }
        }
    }
}

struct ChartStatCard: View {
    let stat: ChartStat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: stat.icon)
                    .foregroundColor(stat.color)
                Spacer()
                Image(systemName: stat.trend == .up ? "arrow.up.right" : "arrow.down.right")
                    .foregroundColor(stat.trend == .up ? .green : .red)
                    .font(.caption)
            }

            Text(stat.value)
                .font(.title2)
                .fontWeight(.bold)

            Text(stat.title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(stat.color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct MetricRow: View {
    let metric: Metric

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(metric.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(metric.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(String(format: "%.2f", metric.value))
                .font(.headline)
                .foregroundColor(metric.value > 0 ? .green : .red)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

// MARK: - Data Models for SwiftUI Charts
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let x: Double
    let y: Double
}

struct PieChartDataPoint: Identifiable {
    let id = UUID()
    let value: Double
    let label: String
}

class ChartsViewModel: ObservableObject {
    @Published var lineChartData: [ChartDataPoint] = []
    @Published var barChartData: [ChartDataPoint] = []
    @Published var pieChartData: [PieChartDataPoint] = []
    @Published var stats: [ChartStat] = []
    @Published var recentMetrics: [Metric] = []

    func loadData() {
        let startTime = Date()

        lineChartData = (0..<12).map { i in
            ChartDataPoint(x: Double(i), y: Double.random(in: 50...200))
        }

        barChartData = (0..<6).map { i in
            ChartDataPoint(x: Double(i), y: Double.random(in: 30...150))
        }

        pieChartData = [
            PieChartDataPoint(value: 25, label: "Category A"),
            PieChartDataPoint(value: 20, label: "Category B"),
            PieChartDataPoint(value: 18, label: "Category C"),
            PieChartDataPoint(value: 22, label: "Category D"),
            PieChartDataPoint(value: 15, label: "Category E")
        ]

        stats = [
            ChartStat(title: "Total Revenue", value: "$\(Int.random(in: 50000...100000))", icon: "dollarsign.circle.fill", color: .green, trend: .up),
            ChartStat(title: "Active Users", value: "\(Int.random(in: 1000...5000))", icon: "person.3.fill", color: .blue, trend: .up),
            ChartStat(title: "Avg Response Time", value: "\(Int.random(in: 100...500))ms", icon: "speedometer", color: .orange, trend: .down),
            ChartStat(title: "Error Rate", value: "\(Double.random(in: 0.1...2.0).rounded(to: 2))%", icon: "exclamationmark.triangle.fill", color: .red, trend: .down)
        ]

        recentMetrics = (0..<8).map { i in
            Metric(name: "Metric \(i + 1)",
                  value: Double.random(in: -50...150),
                  timestamp: Date().addingTimeInterval(Double(-i * 300)))
        }

        let loadTime = Date().timeIntervalSince(startTime)
        NewRelic.recordMetric(withName: "Charts/LoadTime", category: "Performance", value: NSNumber(value: loadTime))
        NewRelic.recordMetric(withName: "Charts/DataPoints", category: "Data", value: NSNumber(value: lineChartData.count + barChartData.count + pieChartData.count))
    }
}

#Preview {
    if #available(iOS 17.0, *) {
        ChartsView()
    } else {
        // Fallback on earlier versions
    }
}
