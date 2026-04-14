//
//  SwiftUICornerRadiusPlaygroundView.swift
//  NRTestApp
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import SwiftUI
import NewRelic

struct SwiftUICornerRadiusPlaygroundView: View {
    @State private var dynamicRadius: Double = 12.0

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Title
                VStack {
                    Text("🔵 SwiftUI Corner Radius Playground")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text("Testing corner radius capture in Session Replay")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()

                // MARK: - Basic Corner Radius Examples
                sectionHeader("📐 Basic Corner Radius")

                let basicCorners: [(String, CGFloat)] = [
                    ("No Corners", 0),
                    ("Small (4px)", 4),
                    ("Medium (8px)", 8),
                    ("Standard (10px)", 10),
                    ("Large (12px)", 12),
                    ("XL (16px)", 16),
                    ("XXL (20px)", 20),
                    ("Circle (50px)", 50)
                ]

                VStack(spacing: 12) {
                    ForEach(Array(basicCorners.enumerated()), id: \.offset) { index, corner in
                        cornerExample(title: corner.0, radius: corner.1, color: .blue)
                    }
                }

                // MARK: - System Component Examples
                sectionHeader("🎛️ System Components (Should show default radius)")

                VStack(spacing: 12) {
                    // List Example - THE KEY TEST FOR THE FIX
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SwiftUI List (Grouped Style) - TESTING FIX")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text("✅ Should show 10px corner radius on all inner elements")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        List {
                            Text("First Item (should have top corners rounded)")
                            Text("Middle Item (should have no corners rounded)")
                            Text("Last Item (should have bottom corners rounded)")
                            Section("Another Section") {
                                Text("Single Item (should have all corners rounded)")
                            }
                            Section("Multiple Items") {
                                Text("First in section")
                                Text("Middle in section")
                                Text("Last in section")
                            }
                        }
                        .frame(height: 250)
                        .listStyle(GroupedListStyle())
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                    // Specific test for UIKitPlatformViewHost detection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("UIKitPlatformViewHost Test (CRITICAL FIX)")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text("✅ Inner UIView should get border-top-left-radius: 10px, border-top-right-radius: 10px")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        List {
                            HStack {
                                Text("This should show selective corner radius")
                                Spacer()
                                Text("→")
                            }
                            HStack {
                                Text("UIKitPlatformViewHost_ListRepresentable_Collection")
                                Spacer()
                                Text("→")
                            }
                            HStack {
                                Text("SystemBackgroundView should inherit corners")
                                Spacer()
                                Text("→")
                            }
                        }
                        .frame(height: 150)
                        .listStyle(GroupedListStyle())
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                    // NavigationLink Examples
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NavigationLink Components")
                            .font(.headline)
                        List {
                            NavigationLink("NavigationLink 1", destination: Text("Destination 1"))
                            NavigationLink("NavigationLink 2", destination: Text("Destination 2"))
                            NavigationLink("NavigationLink 3", destination: Text("Destination 3"))
                        }
                        .frame(height: 120)
                        .listStyle(GroupedListStyle())
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }

                // MARK: - Button Examples
                sectionHeader("🔘 Button Examples (Testing SwiftUI Button Fix)")

                VStack(spacing: 12) {
                    // Standard SwiftUI buttons (these should get 10px default radius)
                    VStack(alignment: .leading) {
                        Text("Standard SwiftUI Buttons (should get 10px default)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        VStack(spacing: 8) {
                            Button("Default Button Style") {
                                print("Default button tapped")
                            }

                            Button("Bordered Button") {
                                print("Bordered button tapped")
                            }
                            .buttonStyle(BorderedButtonStyle())

                            Button("Prominent Button") {
                                print("Prominent button tapped")
                            }
                            .buttonStyle(BorderedProminentButtonStyle())
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                    // Custom styled buttons
                    buttonExample("Custom 8px Button", radius: 8, color: .blue)
                    buttonExample("Custom 12px Button", radius: 12, color: .green)
                    buttonExample("Custom 16px Button", radius: 16, color: .purple)
                    buttonExample("Custom Pill Button", radius: 25, color: .orange)
                }

                // MARK: - Form Controls
                sectionHeader("📝 Form Controls")

                VStack(spacing: 12) {
                    // TextField
                    VStack(alignment: .leading) {
                        Text("TextField (should have 10px radius)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter text here", text: .constant("Sample text"))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }

                    // Toggle
                    VStack(alignment: .leading) {
                        Text("Toggle (should have 16px radius)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Toggle("Sample Toggle", isOn: .constant(true))
                    }

                    // Picker
                    VStack(alignment: .leading) {
                        Text("Picker (should have 10px radius)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Sample Picker", selection: .constant(0)) {
                            Text("Option 1").tag(0)
                            Text("Option 2").tag(1)
                            Text("Option 3").tag(2)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // MARK: - Colored Examples
                sectionHeader("🎨 Colored Backgrounds")

                let coloredExamples: [(String, Color)] = [
                    ("Red Card", .red),
                    ("Green Card", .green),
                    ("Purple Card", .purple),
                    ("Orange Card", .orange),
                    ("Pink Card", .pink),
                    ("Indigo Card", .indigo)
                ]

                VStack(spacing: 12) {
                    ForEach(Array(coloredExamples.enumerated()), id: \.offset) { index, colorExample in
                        cornerExample(title: colorExample.0, radius: 12, color: colorExample.1)
                    }
                }

                // MARK: - Border Examples
                sectionHeader("🔳 Borders + Corner Radius")

                VStack(spacing: 12) {
                    borderExample("Thin Border", radius: 10, borderWidth: 1, borderColor: .gray)
                    borderExample("Medium Border", radius: 10, borderWidth: 3, borderColor: .blue)
                    borderExample("Thick Border", radius: 10, borderWidth: 5, borderColor: .red)
                    borderExample("Extra Thick", radius: 15, borderWidth: 8, borderColor: .purple)
                }

                // MARK: - Shape Examples
                sectionHeader("🔷 Shape Examples")

                VStack(spacing: 12) {
                    // RoundedRectangle
                    VStack(alignment: .leading) {
                        Text("RoundedRectangle Shape (12px)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                            .frame(height: 60)
                    }

                    // Capsule
                    VStack(alignment: .leading) {
                        Text("Capsule Shape")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Capsule()
                            .fill(Color.green)
                            .frame(height: 40)
                    }

                    // Circle
                    VStack(alignment: .leading) {
                        Text("Circle Shape")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 60, height: 60)
                            Spacer()
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // MARK: - Dynamic Corner Radius
                sectionHeader("⚡ Dynamic Corner Radius")

                VStack(spacing: 16) {
                    Text("Radius: \(Int(dynamicRadius))px")
                        .font(.headline)

                    Rectangle()
                        .fill(Color.blue)
                        .frame(height: 100)
                        .cornerRadius(CGFloat(dynamicRadius))

                    Slider(value: $dynamicRadius, in: 0...50, step: 1)
                        .padding(.horizontal)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // MARK: - Nested Examples
                sectionHeader("🏗️ Nested Corner Radius")

                VStack(spacing: 12) {
                    // Nested containers
                    VStack {
                        Text("Nested Containers")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(spacing: 16) {
                            VStack {
                                Text("Outer: 16px")
                                    .font(.caption)
                                VStack {
                                    Text("Inner")
                                    Text("8px")
                                }
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(8)
                            }
                            .padding()
                            .background(Color(.systemGray5))
                            .cornerRadius(16)

                            VStack {
                                Text("Outer: 20px")
                                    .font(.caption)
                                VStack {
                                    Text("Inner")
                                    Text("4px")
                                }
                                .padding(8)
                                .background(Color.purple)
                                .cornerRadius(4)
                            }
                            .padding()
                            .background(Color(.systemGray5))
                            .cornerRadius(20)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }

                // MARK: - Edge Cases
                sectionHeader("⚠️ Edge Cases")

                VStack(spacing: 12) {
                    // Very small view with large radius
                    VStack(alignment: .leading) {
                        Text("Tiny View, Large Radius (25px on 30x30)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Rectangle()
                                .fill(Color.yellow)
                                .frame(width: 30, height: 30)
                                .cornerRadius(25)
                            Spacer()
                        }
                    }

                    // ClipShape vs cornerRadius
                    HStack(spacing: 16) {
                        VStack {
                            Text("cornerRadius()")
                                .font(.caption)
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: 80, height: 60)
                                .cornerRadius(12)
                        }

                        VStack {
                            Text("clipShape()")
                                .font(.caption)
                            Rectangle()
                                .fill(Color.green)
                                .frame(width: 80, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    // Different corner radius on different edges
                    VStack(alignment: .leading) {
                        Text("Custom Shape - Only Top Corners")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Rectangle()
                            .fill(Color.teal)
                            .frame(height: 60)
                            .clipShape(
                                RoundedCorners(radius: 16, corners: [.topLeft, .topRight])
                            )
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // MARK: - Real-world Examples
                sectionHeader("🌍 Real-world Examples")

                VStack(spacing: 12) {
                    // iOS Settings-style cell
                    settingsStyleCell()

                    // Modern card design
                    modernCard()

                    // Message bubble
                    messageBubbleExample()
                }
            }
            .padding()
        }
        .navigationTitle("Corner Radius Tests")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            NewRelic.recordCustomEvent("SwiftUICornerRadiusPlayground",
                                     attributes: ["view": "appeared"])
        }
    }

    // MARK: - Helper Views

    private func sectionHeader(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.title2)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding(.top)
    }

    private func cornerExample(title: String, radius: CGFloat, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(title) - \(Int(radius))px")
                .font(.caption)
                .foregroundColor(.secondary)
            Rectangle()
                .fill(color)
                .frame(height: 60)
                .cornerRadius(radius)
        }
    }

    private func buttonExample(_ title: String, radius: CGFloat, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(title) - \(Int(radius))px radius")
                .font(.caption)
                .foregroundColor(.secondary)
            Button(action: {
                NewRelic.recordCustomEvent("SwiftUICornerRadiusPlayground",
                                         attributes: [
                                             "action": "button_tap",
                                             "corner_radius": radius
                                         ])
            }) {
                HStack {
                    Spacer()
                    Text(title)
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding()
                .background(color)
                .cornerRadius(radius)
            }
        }
    }

    private func borderExample(_ title: String, radius: CGFloat, borderWidth: CGFloat, borderColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(title) - \(Int(radius))px, \(Int(borderWidth))px border")
                .font(.caption)
                .foregroundColor(.secondary)
            Rectangle()
                .fill(Color(.systemBackground))
                .frame(height: 60)
                .cornerRadius(radius)
                .overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(borderColor, lineWidth: borderWidth)
                )
        }
    }

    private func settingsStyleCell() -> some View {
        VStack(alignment: .leading) {
            Text("iOS Settings Cell Style")
                .font(.caption)
                .foregroundColor(.secondary)
            HStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.blue)
                    .frame(width: 28, height: 28)

                Text("Settings Option")

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
        }
    }

    private func modernCard() -> some View {
        VStack(alignment: .leading) {
            Text("Modern Card Design")
                .font(.caption)
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 0) {
                // Header with only top corners rounded
                HStack {
                    Text("Modern Card")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding()
                .background(Color.blue)
                .clipShape(
                    RoundedCorners(radius: 12, corners: [.topLeft, .topRight])
                )

                // Body
                VStack(alignment: .leading, spacing: 8) {
                    Text("This card uses 16px corner radius")
                        .font(.subheadline)
                    Text("Header has top corners only, body has bottom corners only")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(
                    RoundedCorners(radius: 12, corners: [.bottomLeft, .bottomRight])
                )
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
    }

    private func messageBubbleExample() -> some View {
        VStack(alignment: .leading) {
            Text("Message Bubbles")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                // Sent message (right aligned, blue)
                HStack {
                    Spacer()
                    Text("Hello! How are you?")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(18)
                }

                // Received message (left aligned, gray)
                HStack {
                    Text("I'm doing great, thanks! How about you?")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray5))
                        .cornerRadius(18)
                    Spacer()
                }
            }
        }
    }
}

// Custom shape for specific corner rounding
struct RoundedCorners: Shape {
    let radius: CGFloat
    let corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    NavigationView {
        SwiftUICornerRadiusPlaygroundView()
    }
}
