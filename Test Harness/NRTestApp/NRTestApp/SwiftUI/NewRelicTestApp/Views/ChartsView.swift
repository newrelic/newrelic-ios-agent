import SwiftUI
import DGCharts
import NewRelic

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
                        LineChartViewWrapper(data: viewModel.lineChartData)
                            .frame(height: 300)
                            .padding()
                    } else if selectedChart == 1 {
                        BarChartViewWrapper(data: viewModel.barChartData)
                            .frame(height: 300)
                            .padding()
                    } else {
                        PieChartViewWrapper(data: viewModel.pieChartData)
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

struct LineChartViewWrapper: UIViewRepresentable {
    let data: [ChartDataEntry]

    func makeUIView(context: Context) -> LineChartView {
        let chartView = LineChartView()
        chartView.rightAxis.enabled = false
        chartView.xAxis.labelPosition = .bottom
        chartView.animate(xAxisDuration: 1.0)

        return chartView
    }

    func updateUIView(_ uiView: LineChartView, context: Context) {
        let dataSet = LineChartDataSet(entries: data, label: "Revenue Over Time")
        dataSet.colors = [.systemBlue]
        dataSet.circleColors = [.systemBlue]
        dataSet.circleRadius = 4
        dataSet.lineWidth = 2
        dataSet.mode = .cubicBezier
        dataSet.drawValuesEnabled = false

        uiView.data = LineChartData(dataSet: dataSet)
        uiView.notifyDataSetChanged()
    }
}

struct BarChartViewWrapper: UIViewRepresentable {
    let data: [BarChartDataEntry]

    func makeUIView(context: Context) -> BarChartView {
        let chartView = BarChartView()
        chartView.rightAxis.enabled = false
        chartView.xAxis.labelPosition = .bottom
        chartView.animate(yAxisDuration: 1.0)

        return chartView
    }

    func updateUIView(_ uiView: BarChartView, context: Context) {
        let dataSet = BarChartDataSet(entries: data, label: "Monthly Sales")
        dataSet.colors = [.systemGreen, .systemBlue, .systemPurple, .systemOrange, .systemRed, .systemTeal]
        dataSet.valueFont = .systemFont(ofSize: 10)

        uiView.data = BarChartData(dataSet: dataSet)
        uiView.notifyDataSetChanged()
    }
}

struct PieChartViewWrapper: UIViewRepresentable {
    let data: [PieChartDataEntry]

    func makeUIView(context: Context) -> PieChartView {
        let chartView = PieChartView()
        chartView.usePercentValuesEnabled = true
        chartView.drawSlicesUnderHoleEnabled = false
        chartView.holeRadiusPercent = 0.4
        chartView.transparentCircleRadiusPercent = 0.45
        chartView.chartDescription.enabled = false
        chartView.setExtraOffsets(left: 10, top: 10, right: 10, bottom: 10)
        chartView.animate(xAxisDuration: 1.0, easingOption: .easeOutBack)

        return chartView
    }

    func updateUIView(_ uiView: PieChartView, context: Context) {
        let dataSet = PieChartDataSet(entries: data, label: "")
        dataSet.sliceSpace = 2
        dataSet.colors = [.systemRed, .systemOrange, .systemYellow, .systemGreen, .systemBlue]
        dataSet.valueTextColor = .black
        dataSet.valueFont = .systemFont(ofSize: 12, weight: .bold)

        uiView.data = PieChartData(dataSet: dataSet)
        uiView.notifyDataSetChanged()
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

class ChartsViewModel: ObservableObject {
    @Published var lineChartData: [ChartDataEntry] = []
    @Published var barChartData: [BarChartDataEntry] = []
    @Published var pieChartData: [PieChartDataEntry] = []
    @Published var stats: [ChartStat] = []
    @Published var recentMetrics: [Metric] = []

    func loadData() {
        let startTime = Date()

        lineChartData = (0..<12).map { i in
            ChartDataEntry(x: Double(i), y: Double.random(in: 50...200))
        }

        barChartData = (0..<6).map { i in
            BarChartDataEntry(x: Double(i), y: Double.random(in: 30...150))
        }

        pieChartData = [
            PieChartDataEntry(value: 25, label: "Category A"),
            PieChartDataEntry(value: 20, label: "Category B"),
            PieChartDataEntry(value: 18, label: "Category C"),
            PieChartDataEntry(value: 22, label: "Category D"),
            PieChartDataEntry(value: 15, label: "Category E")
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
    ChartsView()
}
