import SwiftUI
import NewRelic

/// Test Case: Scroll Under Header
///
/// This test case validates that the rrweb translation properly handles:
/// - A VStack with a background color applied
/// - Content scrolling underneath a fixed header/filter area
/// - Background color masking behavior (the header area should mask scrolling content)
///
/// Expected rrweb behavior:
/// - The main container should have the purple background color
/// - As list items scroll up, they should be visually clipped/masked by the header area
/// - The header and filter areas should remain fixed while content scrolls beneath them
struct ScrollUnderHeaderTestCase: View {
    @State private var selectedFilter: String = "All"
    let filters = ["All", "Active", "Completed", "Archived"]

    // Sample data for the scrollable list
    let items: [String] = (1...50).map { "List Item \($0)" }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header Toolbar
            VStack(spacing: 0) {
                HStack {
                    Text("Header Toolbar")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: {
                        NewRelic.recordCustomEvent("HeaderAction", attributes: [
                            "action": "menuTapped",
                            "testCase": "ScrollUnderHeader"
                        ])
                    }) {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.purple.opacity(0.9))
            }

            // MARK: - Filter Section
            VStack(spacing: 8) {
                Text("Filters")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filters, id: \.self) { filter in
                            Button(action: {
                                selectedFilter = filter
                                NewRelic.recordCustomEvent("FilterChanged", attributes: [
                                    "filter": filter,
                                    "testCase": "ScrollUnderHeader"
                                ])
                            }) {
                                Text(filter)
                                    .font(.subheadline)
                                    .fontWeight(selectedFilter == filter ? .semibold : .regular)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        selectedFilter == filter
                                            ? Color.white
                                            : Color.white.opacity(0.2)
                                    )
                                    .foregroundColor(
                                        selectedFilter == filter
                                            ? Color.purple
                                            : Color.white
                                    )
                                    .cornerRadius(20)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.purple.opacity(0.7))

            // MARK: - Scrollable List Content
            // This ScrollView's content should scroll UNDERNEATH the header/filter areas
            // The background color of the parent VStack should mask the content
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items, id: \.self) { item in
                        HStack {
                            Circle()
                                .fill(Color.purple.opacity(0.3))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(String(item.split(separator: " ").last ?? ""))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item)
                                    .font(.body)
                                    .fontWeight(.medium)

                                Text("Tap to select this item")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .onTapGesture {
                            NewRelic.recordCustomEvent("ItemTapped", attributes: [
                                "item": item,
                                "testCase": "ScrollUnderHeader"
                            ])
                        }

                        Divider()
                            .padding(.leading, 72)
                    }
                }
            }
            .background(Color.gray.opacity(0.1))
        }
        .background(Color.purple)
        .navigationTitle("Scroll Under Header")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            NewRelic.recordCustomEvent("ScreenView", attributes: [
                "screenName": "ScrollUnderHeaderTestCase",
                "testCase": "ScrollUnderHeader"
            ])
        }
    }
}

#Preview {
    NavigationView {
        ScrollUnderHeaderTestCase()
    }
}
