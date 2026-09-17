import SwiftUI
import NewRelic

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @State private var isRefreshing = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Stats Cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatCard(title: "Total Users", value: "\(viewModel.totalUsers)", color: .blue)
                        StatCard(title: "Active Sessions", value: "\(viewModel.activeSessions)", color: .green)
                        StatCard(title: "Revenue", value: "$\(viewModel.revenue)", color: .purple)
                        StatCard(title: "Conversion Rate", value: "\(viewModel.conversionRate)%", color: .orange)
                    }
                    .padding(.horizontal)

                    // Recent Activity
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Activity")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(viewModel.recentActivities) { activity in
                            ActivityRow(activity: activity)
                        }
                    }
                    .padding(.vertical)
                }
                .padding(.top)
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        refreshData()
                    } label: {
                        Image(systemName: isRefreshing ? "arrow.clockwise.circle.fill" : "arrow.clockwise")
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    }
                }
            }
            .onAppear {
                NewRelic.recordBreadcrumb("DashboardView appeared")
                viewModel.loadData()
            }
        }
    }

    private func refreshData() {
        let interactionId = NewRelic.startInteraction(withName: "RefreshDashboard")

        isRefreshing = true
        NewRelic.recordMetric(withName: "DashboardRefresh/Count", category: "User Action", value: 1)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            viewModel.loadData()
            isRefreshing = false
            NewRelic.stopCurrentInteraction(interactionId)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ActivityRow: View {
    let activity: Activity

    var body: some View {
        HStack {
            Image(systemName: activity.icon)
                .foregroundColor(activity.color)
                .frame(width: 30, height: 30)
                .background(activity.color.opacity(0.2))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(activity.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

class DashboardViewModel: ObservableObject {
    @Published var totalUsers: Int = 0
    @Published var activeSessions: Int = 0
    @Published var revenue: Int = 0
    @Published var conversionRate: Double = 0.0
    @Published var recentActivities: [Activity] = []

    func loadData() {
        let startTime = Date()

        totalUsers = Int.random(in: 1000...5000)
        activeSessions = Int.random(in: 50...500)
        revenue = Int.random(in: 10000...50000)
        conversionRate = Double.random(in: 2.0...8.0).rounded(to: 2)

        recentActivities = [
            Activity(title: "New user registration", icon: "person.badge.plus", color: .green, timestamp: Date().addingTimeInterval(-300)),
            Activity(title: "Payment processed", icon: "creditcard", color: .blue, timestamp: Date().addingTimeInterval(-600)),
            Activity(title: "Data export completed", icon: "square.and.arrow.up", color: .purple, timestamp: Date().addingTimeInterval(-900)),
            Activity(title: "Settings updated", icon: "gearshape.fill", color: .orange, timestamp: Date().addingTimeInterval(-1200)),
            Activity(title: "Report generated", icon: "doc.text", color: .red, timestamp: Date().addingTimeInterval(-1800))
        ]

        let loadTime = Date().timeIntervalSince(startTime)
        NewRelic.recordMetric(withName: "Dashboard/LoadTime", category: "Performance", value: NSNumber(value: loadTime))
    }
}

extension Double {
    func rounded(to places: Int) -> Double {
        let multiplier = pow(10.0, Double(places))
        return (self * multiplier).rounded() / multiplier
    }
}

#Preview {
    DashboardView()
}
