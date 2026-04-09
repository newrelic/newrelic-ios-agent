import SwiftUI
import Lottie

// MARK: - Data Model

struct TableColumn: Identifiable {
    let id = UUID()
    let title: String
    let width: CGFloat
}

struct TableRow: Identifiable {
    let id = UUID()
    let values: [String: String]
}

// MARK: - State

final class InfraTableState: ObservableObject {
    enum ViewState { case loading, empty, data }

    @Published var viewState: ViewState = .loading
    @Published var rows: [TableRow] = []

    var isLoading: Bool { viewState == .loading }
    var isEmpty: Bool  { viewState == .empty }

    private var timerTask: Task<Void, Never>?

    let columns: [TableColumn] = [
        TableColumn(title: "Host",    width: 160),
        TableColumn(title: "Status",  width: 80),
        TableColumn(title: "CPU %",   width: 70),
        TableColumn(title: "Mem %",   width: 70),
        TableColumn(title: "Disk %",  width: 70),
        TableColumn(title: "Region",  width: 100),
    ]

    private static let sampleHosts: [[String: String]] = [
        ["Host": "web-prod-01",  "Status": "OK",   "CPU %": "12", "Mem %": "45", "Disk %": "60", "Region": "us-east-1"],
        ["Host": "web-prod-02",  "Status": "OK",   "CPU %": "9",  "Mem %": "41", "Disk %": "58", "Region": "us-east-1"],
        ["Host": "api-prod-01",  "Status": "WARN", "CPU %": "78", "Mem %": "82", "Disk %": "70", "Region": "us-west-2"],
        ["Host": "api-prod-02",  "Status": "OK",   "CPU %": "33", "Mem %": "55", "Disk %": "62", "Region": "us-west-2"],
        ["Host": "db-primary",   "Status": "OK",   "CPU %": "22", "Mem %": "70", "Disk %": "80", "Region": "eu-west-1"],
        ["Host": "db-replica-1", "Status": "OK",   "CPU %": "18", "Mem %": "65", "Disk %": "79", "Region": "eu-west-1"],
        ["Host": "cache-01",     "Status": "CRIT", "CPU %": "95", "Mem %": "99", "Disk %": "30", "Region": "ap-south-1"],
        ["Host": "cache-02",     "Status": "OK",   "CPU %": "14", "Mem %": "48", "Disk %": "31", "Region": "ap-south-1"],
        ["Host": "worker-01",    "Status": "OK",   "CPU %": "40", "Mem %": "52", "Disk %": "44", "Region": "us-east-1"],
        ["Host": "worker-02",    "Status": "WARN", "CPU %": "67", "Mem %": "74", "Disk %": "50", "Region": "us-east-1"],
    ]

    func startCycling() {
        timerTask?.cancel()
        timerTask = Task { @MainActor in
            let sequence: [ViewState] = [.loading, .data, .loading, .empty]
            var index = 0
            while !Task.isCancelled {
                self.viewState = sequence[index % sequence.count]
                self.rows = self.viewState == .data
                    ? Self.sampleHosts.map { TableRow(values: $0) }
                    : []
                index += 1
                try? await Task.sleep(nanoseconds: 2_500_000_000)
            }
        }
    }

    func stopCycling() {
        timerTask?.cancel()
        timerTask = nil
    }
}

// MARK: - View

struct ObservationTableView: View {
    @ObservedObject var state: InfraTableState

    init() {
        self.state = InfraTableState()
    }

    var body: some View {
        Group {
            if state.isLoading {
                Lottie(
                    isAnimating: .constant(true),
                    config: LottieConfig(fileName: LottieFile.Loader, speed: .loader)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if state.isEmpty {
                Text("No results for the selected filters and/or time window")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                tableContent
            }
        }
        .navigationTitle("Observation")
        .onAppear { state.startCycling() }
        .onDisappear { state.stopCycling() }
        .NRTrackView(name: "ObservationTableView")
    }

    private var tableContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    headerRow
                    Divider()
                    ForEach(state.rows) { row in
                        dataRow(row)
                        Divider()
                    }
                }
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            ForEach(state.columns) { col in
                Text(col.title)
                    .font(.caption.bold())
                    .frame(width: col.width, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 6)
                    .background(Color(.systemGroupedBackground))
            }
        }
    }

    private func dataRow(_ row: TableRow) -> some View {
        HStack(spacing: 0) {
            ForEach(state.columns) { col in
                let value = row.values[col.title] ?? "—"
                Text(value)
                    .font(.caption)
                    .foregroundColor(cellColor(column: col.title, value: value))
                    .frame(width: col.width, alignment: .leading)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 6)
            }
        }
    }

    private func cellColor(column: String, value: String) -> Color {
        guard column == "Status" else { return .primary }
        switch value {
        case "WARN": return .orange
        case "CRIT": return .red
        default:     return .green
        }
    }
}
