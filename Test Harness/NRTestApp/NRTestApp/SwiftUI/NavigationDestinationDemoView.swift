//
//  NavigationDestinationDemoView.swift
//  NRTestApp
//
//  Session Replay test for NavigationStack with navigationDestination(for:)
//  using a typed NavigationContent path. This exercises the MSR capture path
//  for programmatic, type-erased navigation destinations.
//

import SwiftUI

// MARK: - NavigationContent

/// A type-erased navigation destination carried in the path of a NavigationStack.
/// Each value holds a stable `id` (for `.id()` identity resets) and a `content()`
/// factory so the destination view is resolved lazily at render time.
@available(iOS 16.0, *)
struct NavigationContent: Hashable, Identifiable {
    let id: UUID
    let title: String
    private let _content: () -> AnyView

    init(id: UUID = UUID(), title: String, content: @escaping () -> some View) {
        self.id = id
        self.title = title
        self._content = { AnyView(content()) }
    }

    func content() -> some View { _content() }

    // Hashable / Equatable on id only – views are not comparable.
    static func == (lhs: NavigationContent, rhs: NavigationContent) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - ViewModel

@available(iOS 16.0, *)
@MainActor
final class NavigationDestinationViewModel: ObservableObject {
    @Published var topLevelPath: [NavigationContent] = []

    // Pre-built destinations reused across taps so ids are stable.
    let destinations: [NavigationContent] = [
        NavigationContent(title: "Detail A") {
            NavDestDetailView(label: "Detail A", color: .blue)
        },
        NavigationContent(title: "Detail B") {
            NavDestDetailView(label: "Detail B", color: .green)
        },
        NavigationContent(title: "Detail C") {
            NavDestDetailView(label: "Detail C", color: .orange)
        },
        NavigationContent(title: "Nested (push C → B)") {
            NavDestDetailView(label: "Nested", color: .purple)
        },
    ]

    func push(_ destination: NavigationContent) {
        topLevelPath.append(destination)
    }

    func popToRoot() {
        topLevelPath.removeAll()
    }
}

// MARK: - Root view

/// NavigationStack whose path is driven by `[NavigationContent]`.
/// `.navigationDestination(for: NavigationContent.self)` is attached to the root
/// list so it is always registered, regardless of path depth.
@available(iOS 16.0, *)
struct NavigationDestinationDemoView: View {
    @StateObject private var viewModel = NavigationDestinationViewModel()

    var body: some View {
        NavigationStack(path: $viewModel.topLevelPath) {
            NavDestRootList(viewModel: viewModel)
                .navigationDestination(for: NavigationContent.self) { view in
                    view.content()
                        .id(view.id)
                        .navigationBarTitleDisplayMode(.inline)
                        .opacity(viewModel.topLevelPath.isEmpty ? 0 : 1)
                        .animation(.easeIn(duration: 0.2), value: viewModel.topLevelPath.isEmpty)
                }
                .navigationTitle("Nav Destination Demo")
                .navigationBarTitleDisplayMode(.large)
        }
        .NRTrackView(name: "NavigationDestinationDemoView")
    }
}

// MARK: - Root list

@available(iOS 16.0, *)
private struct NavDestRootList: View {
    @ObservedObject var viewModel: NavigationDestinationViewModel

    var body: some View {
        List {
            Section("Push typed destinations") {
                ForEach(viewModel.destinations) { dest in
                    Button(dest.title) {
                        viewModel.push(dest)
                    }
                }
            }

            Section("Programmatic") {
                Button("Push B then C (deep link)") {
                    if viewModel.destinations.count >= 3 {
                        viewModel.topLevelPath.append(viewModel.destinations[1])
                        viewModel.topLevelPath.append(viewModel.destinations[2])
                    }
                }
                Button("Pop to root") {
                    viewModel.popToRoot()
                }
                .foregroundStyle(.red)
            }

            Section("Path state") {
                Text("Depth: \(viewModel.topLevelPath.count)")
                    .foregroundStyle(.secondary)
                if !viewModel.topLevelPath.isEmpty {
                    Text("Top: \(viewModel.topLevelPath.last?.title ?? "")")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Destination detail

@available(iOS 16.0, *)
struct NavDestDetailView: View {
    let label: String
    let color: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(0.2))
                .frame(height: 120)
                .overlay {
                    Text(label)
                        .font(.title2.bold())
                        .foregroundStyle(color)
                }

            Text("Rendered via NavigationContent.content()")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Dismiss") { dismiss() }
                .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle(label)
    }
}
