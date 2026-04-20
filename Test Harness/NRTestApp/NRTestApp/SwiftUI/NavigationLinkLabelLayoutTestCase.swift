import SwiftUI
import NewRelic

/// Test Case: NavigationLink Label Layout
///
/// Tests various text layout configurations in NavigationLink labels to identify
/// issues with text bleeding into the disclosure indicator (chevron) area.
///
/// Each windowed list shows the same content with different layout modifiers applied.
/// Text content is varied: ~20% single-line, ~40% two-line, ~40% three-line descriptions.
///
/// Font weights used:
/// - Title: .headline (17pt semibold / weight 600)
/// - Description: .caption (12pt regular / weight 400)
struct NavigationLinkLabelLayoutTestCase: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                TextLayoutSectionHeader(
                    title: "NavigationLink Label Layout",
                    subtitle: "Compare how different layout modifiers affect text/chevron collision"
                )

                // MARK: - No modifications (baseline)
                ListWindow(title: "No Modifications (Baseline)", subtitle: "Default NavigationLink behavior") {
                    ForEach(sampleItems) { item in
                        NavigationLink(destination: Text(item.title)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.headline)
                                Text(item.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // MARK: - lineLimit(2)
                ListWindow(title: "lineLimit(2)", subtitle: "Description limited to 2 lines") {
                    ForEach(sampleItems) { item in
                        NavigationLink(destination: Text(item.title)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.headline)
                                Text(item.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // MARK: - lineLimit(3)
                ListWindow(title: "lineLimit(3)", subtitle: "Description limited to 3 lines") {
                    ForEach(sampleItems) { item in
                        NavigationLink(destination: Text(item.title)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.headline)
                                Text(item.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(3)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // MARK: - frame(maxWidth: .infinity)
                ListWindow(title: "frame(maxWidth: .infinity)", subtitle: "VStack constrained to full width") {
                    ForEach(sampleItems) { item in
                        NavigationLink(destination: Text(item.title)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.headline)
                                Text(item.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                        }
                    }
                }

                // MARK: - lineLimit + frame
                ListWindow(title: "lineLimit(2) + frame(maxWidth: .infinity)", subtitle: "Combined constraints") {
                    ForEach(sampleItems) { item in
                        NavigationLink(destination: Text(item.title)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.headline)
                                Text(item.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                        }
                    }
                }

                // MARK: - fixedSize vertical only
                ListWindow(title: "fixedSize(horizontal: false, vertical: true)", subtitle: "Allow vertical expansion, constrain horizontal") {
                    ForEach(sampleItems) { item in
                        NavigationLink(destination: Text(item.title)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.headline)
                                Text(item.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // MARK: - layoutPriority
                ListWindow(title: "layoutPriority(-1) on description", subtitle: "Lower priority for description text") {
                    ForEach(sampleItems) { item in
                        NavigationLink(destination: Text(item.title)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.headline)
                                Text(item.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .layoutPriority(-1)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // MARK: - truncationMode variations
                ListWindow(title: "truncationMode(.middle) + lineLimit(1)", subtitle: "Single line with middle truncation") {
                    ForEach(sampleItems) { item in
                        NavigationLink(destination: Text(item.title)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.headline)
                                Text(item.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // MARK: - Combined best practices
                ListWindow(title: "Combined: lineLimit + frame + fixedSize", subtitle: "All constraints applied") {
                    ForEach(sampleItems) { item in
                        NavigationLink(destination: Text(item.title)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.headline)
                                Text(item.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                        }
                    }
                }

                // MARK: - Using GeometryReader approach
                ListWindow(title: "Explicit width via GeometryReader", subtitle: "Text width explicitly calculated") {
                    ForEach(sampleItems) { item in
                        NavigationLink(destination: Text(item.title)) {
                            GeometryReader { geo in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.headline)
                                    Text(item.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                .frame(width: geo.size.width, alignment: .leading)
                                .padding(.vertical, 4)
                            }
                            .frame(height: 60)
                        }
                    }
                }

                Spacer(minLength: 40)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("NavigationLink Labels")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            NewRelic.recordCustomEvent("ScreenView", attributes: [
                "screenName": "NavigationLinkLabelLayoutTestCase",
                "testCase": "NavigationLinkLabelLayout"
            ])
        }
    }
}

// MARK: - Sample Data

struct SampleItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
}

/// Sample items with varied description lengths:
/// ~20% single-line, ~40% two-line, ~40% three-line
let sampleItems: [SampleItem] = [
    // Single-line descriptions (~20%)
    SampleItem(title: "Quick Settings", description: "Tap to configure"),
    SampleItem(title: "Notifications", description: "Manage your alerts"),
    SampleItem(title: "Dark Mode", description: "Toggle appearance"),
    SampleItem(title: "Language", description: "English (US)"),

    // Two-line descriptions (~40%)
    SampleItem(title: "Account Security", description: "Manage your password, two-factor authentication, and connected devices"),
    SampleItem(title: "Privacy Controls", description: "Control what data is collected and how it's used across our services"),
    SampleItem(title: "Storage Management", description: "View and manage your storage usage, cached files, and downloaded content"),
    SampleItem(title: "Sync Settings", description: "Configure automatic sync options for photos, documents, and app data"),
    SampleItem(title: "Accessibility", description: "Adjust display, audio, and interaction settings for better accessibility"),
    SampleItem(title: "Battery Optimization", description: "Manage background activity and power consumption for longer battery life"),
    SampleItem(title: "Network Preferences", description: "Configure Wi-Fi, cellular data usage limits, and VPN connections"),
    SampleItem(title: "App Permissions", description: "Review and modify permissions granted to installed applications"),

    // Three-line descriptions (~40%)
    SampleItem(title: "Data Export", description: "Download a complete copy of your data including photos, messages, contacts, and activity history. Processing may take up to 48 hours."),
    SampleItem(title: "Backup & Restore", description: "Create encrypted backups of your device settings, app data, and personal files. Backups can be stored locally or in the cloud for easy restoration."),
    SampleItem(title: "Developer Options", description: "Advanced settings for developers including USB debugging, layout bounds visualization, GPU rendering profiles, and strict mode indicators."),
    SampleItem(title: "Experimental Features", description: "Try new features before they're released to everyone. These features may be unstable and could change or be removed in future updates."),
    SampleItem(title: "Content Filtering", description: "Set up parental controls and content restrictions. Filter explicit content, limit screen time, and manage in-app purchases for family members."),
    SampleItem(title: "Connected Services", description: "Manage third-party apps and services connected to your account. Review permissions, revoke access, and see recent activity from connected applications."),
    SampleItem(title: "Location History", description: "View and manage your location history timeline. See places you've visited, delete specific entries, and control how location data is collected and stored."),
    SampleItem(title: "Digital Wellbeing", description: "Monitor your screen time, app usage patterns, and notification frequency. Set daily limits, schedule downtime, and reduce interruptions during focus hours."),
]

// MARK: - Helper Views

struct ListWindow<Content: View>: View {
    let title: String
    let subtitle: String
    let content: () -> Content

    init(title: String, subtitle: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            List {
                content()
            }
            .listStyle(.plain)
            .frame(height: 480) // Tall enough for ~8 items
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

struct TextLayoutSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationView {
        NavigationLinkLabelLayoutTestCase()
    }
}
