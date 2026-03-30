//
//  SwiftUITabBar.swift
//  NRTestApp
//
//  Created by Mike Bruin on 3/20/26.
//

import SwiftUI

struct SwiftUITabBar: View {
    @State private var selectedTab = 0
    @State private var formBadgeCount: Int? = 3
    @State private var notificationBadgeCount: Int? = 7

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(0)

            FormView(badgeCount: $formBadgeCount)
                .tabItem {
                    Label("Form", systemImage: "doc.text.fill")
                }
                .tag(1)
                .apply { view in
                    if let count = formBadgeCount {
                        view.badge(count)
                    } else {
                        view
                    }
                }

            if #available(iOS 17.0, *) {
                ChartsView()
                    .tabItem {
                        Label("Charts", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tag(2)
            }

            NotificationsPlaceholderView(badgeCount: $notificationBadgeCount)
                .tabItem {
                    Label("Alerts", systemImage: "bell.badge.fill")
                }
                .tag(3)
                .apply { view in
                    if let count = notificationBadgeCount {
                        view.badge(count)
                    } else {
                        view
                    }
                }

            ProfilePlaceholderView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
                .tag(4)

            MediaPlaceholderView()
                .tabItem {
                    Label("Media", systemImage: "photo.stack.fill")
                }
                .tag(5)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(6)
        }
        .tint(Color(red: 1.0, green: 0.27, blue: 0.23)) // Custom red/coral tint
        .onAppear {
            configureCustomTabBarAppearance()
        }
        .onChange(of: selectedTab) { newValue in
            // Track tab changes with New Relic
            let tabNames = ["Dashboard", "Form", "Charts", "Alerts", "Profile", "Media", "Settings"]
            if newValue < tabNames.count {
                NewRelic.recordCustomEvent("TabChanged",
                                           attributes: [
                                            "toTab": tabNames[newValue]
                                           ])
            }

            // Remove badge when Form tab is selected
            if newValue == 1 {
                formBadgeCount = nil
            }

            // Remove badge when Alerts tab is selected
            if newValue == 3 {
                notificationBadgeCount = nil
            }
        }
    }

    private func configureCustomTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()

        // Custom background color - light purple/lavender
        appearance.backgroundColor = UIColor(red: 0.95, green: 0.94, blue: 0.98, alpha: 1.0)

        // Custom selected item color - coral/red
        let selectedColor = UIColor(red: 1.0, green: 0.27, blue: 0.23, alpha: 1.0)
        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: selectedColor,
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]

        // Custom unselected item color - purple/gray
        let unselectedColor = UIColor(red: 0.55, green: 0.51, blue: 0.66, alpha: 1.0)
        appearance.stackedLayoutAppearance.normal.iconColor = unselectedColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: unselectedColor,
            .font: UIFont.systemFont(ofSize: 10, weight: .regular)
        ]

        // Apply to all tab bars
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

extension View {
    func apply<V: View>(@ViewBuilder _ transform: (Self) -> V) -> V {
        transform(self)
    }
}

// MARK: - Placeholder Views

struct NotificationsPlaceholderView: View {
    @Binding var badgeCount: Int?

    var body: some View {
        NRConditionalMaskView(sessionReplayIdentifier: "public") {
            ZStack {
                LinearGradient(
                    colors: [Color.orange.opacity(0.3), Color.red.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 20) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(Color.orange)

                    Text("Notifications")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    if let count = badgeCount {
                        Text("\(count) new alert\(count == 1 ? "" : "s")")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No new alerts")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }

                    Button(action: {
                        badgeCount = nil
                        NewRelic.recordCustomEvent("ClearNotifications", attributes: [:])
                    }) {
                        Label("Clear All", systemImage: "trash")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(badgeCount != nil ? Color.red : Color.gray)
                            .cornerRadius(10)
                    }
                    .disabled(badgeCount == nil)
                }
            }
        }
    }
}

struct ProfilePlaceholderView: View {
    var body: some View {
        NRConditionalMaskView(sessionReplayIdentifier: "public") {
            ZStack {
                LinearGradient(
                    colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(Color.blue)
                    
                    Text("Profile")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("User Settings & Info")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        ProfileRowView(icon: "envelope.fill", text: "user@example.com")
                        ProfileRowView(icon: "phone.fill", text: "+1 (555) 123-4567")
                        ProfileRowView(icon: "mappin.circle.fill", text: "San Francisco, CA")
                    }
                    .padding()
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(15)
                }
                .padding()
            }
        }
    }
}

struct ProfileRowView: View {
    let icon: String
    let text: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 30)
            Text(text)
                .font(.subheadline)
        }
    }
}

struct MediaPlaceholderView: View {
    let sampleImages = ["photo.fill", "video.fill", "music.note", "doc.fill"]

    var body: some View {
        ZStack {
            NRConditionalMaskView(sessionReplayIdentifier: "public") {
                LinearGradient(
                    colors: [Color.green.opacity(0.3), Color.teal.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(Color.green)
                    
                    Text("Media Gallery")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Photos, Videos & Documents")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 15) {
                        ForEach(sampleImages, id: \.self) { imageName in
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.8))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: imageName)
                                    .font(.system(size: 40))
                                    .foregroundStyle(Color.green)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
}
