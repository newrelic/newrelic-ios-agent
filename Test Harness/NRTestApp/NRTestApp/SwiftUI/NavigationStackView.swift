//
//  NavigationStackView.swift
//  NRTestApp
//

import SwiftUI

// MARK: - Data models for typed navigation

struct NavItem: Hashable, Identifiable {
    let id: Int
    let title: String
    let color: Color
}

struct NavSubItem: Hashable, Identifiable {
    let id: Int
    let parentTitle: String
    let detail: String
}

struct NavLeafItem: Hashable {
    let label: String
    let symbol: String
}

// MARK: - Root view
//if ios 16

@available(iOS 16.0, tvOS 16.0, *)
struct NavigationStackView: View {
    /// Fully-typed path – drives programmatic navigation.
    @State private var path = NavigationPath()
    @State private var searchText = ""

    private let items: [NavItem] = [
        NavItem(id: 1, title: "Alpha",   color: .blue),
        NavItem(id: 2, title: "Beta",    color: .green),
        NavItem(id: 3, title: "Gamma",   color: .orange),
        NavItem(id: 4, title: "Delta",   color: .purple),
        NavItem(id: 5, title: "Epsilon", color: .red),
    ]

    private var filteredItems: [NavItem] {
        searchText.isEmpty ? items : items.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        // NavigationStack with an explicit, bindable path.
        NavigationStack(path: $path) {
            List {
                // ── Section 1: value-based NavigationLinks ──────────────────
                Section("Value-based Links (iOS 16+)") {
                    ForEach(filteredItems) { item in
                        // NavigationLink(value:) – destination resolved by .navigationDestination
                        NavigationLink(value: item) {
                            Label(item.title, systemImage: "circle.fill")
                                .foregroundStyle(item.color)
                        }
                    }
                }

                // ── Section 2: programmatic / deep-link navigation ──────────
                Section("Programmatic Navigation") {
                    Button("Push Alpha (programmatic)") {
                        if let alpha = items.first {
                            path.append(alpha)
                        }
                    }
                    Button("Push Alpha → Sub-1 (deep link, 2 levels)") {
                        if let alpha = items.first {
                            path.append(alpha)
                            path.append(NavSubItem(id: 1, parentTitle: alpha.title, detail: "Sub-item 1 of Alpha"))
                        }
                    }
                    Button("Push Leaf directly") {
                        path.append(NavLeafItem(label: "Leaf pushed programmatically", symbol: "leaf.fill"))
                    }
                    Button("Pop to root") {
                        path = NavigationPath()
                    }
                    .foregroundStyle(.red)
                }

                // ── Section 3: legacy destination-style link ────────────────
                Section("Inline-destination Link (pre-iOS 16 style)") {
                    NavigationLink("Settings Detail (inline destination)") {
                        NavSettingsDetailView()
                    }
                }
            }
            .navigationTitle("NavigationStack")
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            // Searchable – exercises the search bar attached to the navigation stack.
            #if os(tvOS)
            .searchable(text: $searchText, prompt: "Filter items")
            #else
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Filter items")
            #endif
            .toolbar {
                #if !os(tvOS)
                // ToolbarItem in principal position (title area on compact)
                ToolbarItem(placement: .principal) {
                    Text("Stack Demo")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                #endif
                // Trailing button – pushes a leaf item
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        path.append(NavLeafItem(label: "From toolbar", symbol: "bolt.fill"))
                    } label: {
                        Image(systemName: "bolt.fill")
                    }
                }
            }
            // ── navigationDestination modifiers ──────────────────────────────
            // Each handles a distinct Hashable type in the path.
            .navigationDestination(for: NavItem.self) { item in
                NavItemDetailView(item: item, path: $path)
            }
            .navigationDestination(for: NavSubItem.self) { sub in
                NavSubItemDetailView(sub: sub, path: $path)
            }
            .navigationDestination(for: NavLeafItem.self) { leaf in
                NavLeafView(leaf: leaf, path: $path)
            }
        }
        .NRTrackView(name: "NavigationStackView")
    }
}

// MARK: - Level 1: item detail

@available(iOS 16.0, tvOS 16.0, *)
struct NavItemDetailView: View {
    let item: NavItem
    @Binding var path: NavigationPath

    private let subItems: [NavSubItem] = (1...4).map {
        NavSubItem(id: $0, parentTitle: "", detail: "Detail line \($0)")
    }

    var body: some View {
        List {
            Section("About") {
                LabeledContent("ID", value: "\(item.id)")
                LabeledContent("Color", value: item.title)
                    .listRowBackground(item.color.opacity(0.15))
            }

            Section("Sub-items (push NavSubItem)") {
                ForEach(subItems) { sub in
                    let resolved = NavSubItem(id: sub.id, parentTitle: item.title, detail: sub.detail)
                    NavigationLink(value: resolved) {
                        Text(sub.detail)
                    }
                }
            }

            Section("Programmatic from here") {
                Button("Push Leaf from level 1") {
                    path.append(NavLeafItem(label: "From \(item.title)", symbol: "leaf.fill"))
                }
                Button("Pop to root") {
                    path = NavigationPath()
                }
                .foregroundStyle(.red)
            }
        }
        .navigationTitle(item.title)
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Image(systemName: "circle.fill")
                    .foregroundStyle(item.color)
            }
        }
    }
}

// MARK: - Level 2: sub-item detail

@available(iOS 16.0, tvOS 16.0, *)
struct NavSubItemDetailView: View {
    let sub: NavSubItem
    @Binding var path: NavigationPath

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "2.square.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80)
                .foregroundStyle(.teal)

            Text(sub.detail)
                .font(.title2)

            Text("Parent: \(sub.parentTitle)")
                .foregroundStyle(.secondary)

            Button("Push Leaf (level 3)") {
                path.append(NavLeafItem(label: sub.detail, symbol: "3.square.fill"))
            }
            .buttonStyle(.borderedProminent)

            Button("Pop to root") {
                path = NavigationPath()
            }
            .buttonStyle(.bordered)
            .foregroundStyle(.red)
        }
        .padding()
        .navigationTitle("Sub-item \(sub.id)")
        // Custom back button label via toolbar
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                // Demonstrates navigationBarBackButtonHidden + custom back button
                EmptyView()
            }
        }
    }
}

// MARK: - Level 3 / leaf

@available(iOS 16.0, tvOS 16.0, *)
struct NavLeafView: View {
    let leaf: NavLeafItem
    @Binding var path: NavigationPath

    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: leaf.symbol)
                .resizable()
                .scaledToFit()
                .frame(width: 100)
                .foregroundStyle(.indigo)

            Text(leaf.label)
                .font(.title)
                .multilineTextAlignment(.center)

            Text("This is the deepest level.")
                .foregroundStyle(.secondary)

            Button("Pop to root") {
                path = NavigationPath()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding()
        .navigationTitle("Leaf")
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        // Exercises hiding the system back button and providing a custom one
        .navigationBarBackButtonHidden(true)
        #endif
        .toolbar {
            #if !os(tvOS)
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    path.removeLast()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
            }
            #endif
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    path = NavigationPath()
                } label: {
                    Image(systemName: "house.fill")
                }
            }
        }
    }
}

// MARK: - Inline-destination settings detail (legacy style)
@available(iOS 16.0, tvOS 16.0, *)
struct NavSettingsDetailView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Navigation features exercised here") {
                Label("Inline destination (no .navigationDestination)", systemImage: "checkmark.circle")
                Label(".dismiss via environment", systemImage: "checkmark.circle")
                Label(".navigationTitle", systemImage: "checkmark.circle")
                Label(".navigationBarTitleDisplayMode(.inline)", systemImage: "checkmark.circle")
            }

            Section {
                Button("Dismiss programmatically") {
                    dismiss()
                }
                .foregroundStyle(.red)
            }
        }
        .navigationTitle("Settings Detail")
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
