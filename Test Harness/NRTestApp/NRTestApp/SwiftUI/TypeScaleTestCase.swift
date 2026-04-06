import SwiftUI
import NewRelic

/// Test Case: Type Scale
///
/// Displays all SwiftUI Dynamic Type text styles to test rrweb translation
/// of font sizes across the entire type scale.
///
/// Each text style has a default point size that scales with user accessibility settings.
/// This test helps verify whether the translator captures:
/// - The correct base font sizes
/// - Font weights (headline is semibold, others are regular)
/// - Proper CSS output for each style
struct TypeScaleTestCase: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Header explaining the test
                VStack(alignment: .leading, spacing: 8) {
                    Text("Dynamic Type Scale")
                        .font(.system(size: 24, weight: .bold))
                    Text("All SwiftUI text styles with their default point sizes")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)

                Divider()

                // MARK: - Large Title Styles
                Group {
                    TypeStyleRow(
                        styleName: ".largeTitle",
                        defaultSize: "34pt",
                        sample: Text("Large Title").font(.largeTitle)
                    )

                    TypeStyleRow(
                        styleName: ".title",
                        defaultSize: "28pt",
                        sample: Text("Title").font(.title)
                    )

                    TypeStyleRow(
                        styleName: ".title2",
                        defaultSize: "22pt",
                        sample: Text("Title 2").font(.title2)
                    )

                    TypeStyleRow(
                        styleName: ".title3",
                        defaultSize: "20pt",
                        sample: Text("Title 3").font(.title3)
                    )
                }

                Divider()

                // MARK: - Body Styles
                Group {
                    TypeStyleRow(
                        styleName: ".headline",
                        defaultSize: "17pt semibold",
                        sample: Text("Headline").font(.headline)
                    )

                    TypeStyleRow(
                        styleName: ".body",
                        defaultSize: "17pt",
                        sample: Text("Body").font(.body)
                    )

                    TypeStyleRow(
                        styleName: ".callout",
                        defaultSize: "16pt",
                        sample: Text("Callout").font(.callout)
                    )

                    TypeStyleRow(
                        styleName: ".subheadline",
                        defaultSize: "15pt",
                        sample: Text("Subheadline").font(.subheadline)
                    )
                }

                Divider()

                // MARK: - Small Styles
                Group {
                    TypeStyleRow(
                        styleName: ".footnote",
                        defaultSize: "13pt",
                        sample: Text("Footnote").font(.footnote)
                    )

                    TypeStyleRow(
                        styleName: ".caption",
                        defaultSize: "12pt",
                        sample: Text("Caption").font(.caption)
                    )

                    TypeStyleRow(
                        styleName: ".caption2",
                        defaultSize: "11pt",
                        sample: Text("Caption 2").font(.caption2)
                    )
                }

                Divider()

                // MARK: - Fixed System Fonts (for comparison)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Fixed System Fonts")
                        .font(.system(size: 18, weight: .semibold))
                    Text("These use explicit sizes and should translate reliably")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)

                Group {
                    TypeStyleRow(
                        styleName: ".system(size: 34)",
                        defaultSize: "34pt fixed",
                        sample: Text("System 34").font(.system(size: 34))
                    )

                    TypeStyleRow(
                        styleName: ".system(size: 17)",
                        defaultSize: "17pt fixed",
                        sample: Text("System 17").font(.system(size: 17))
                    )

                    TypeStyleRow(
                        styleName: ".system(size: 12)",
                        defaultSize: "12pt fixed",
                        sample: Text("System 12").font(.system(size: 12))
                    )

                    TypeStyleRow(
                        styleName: ".system(size: 17, weight: .bold)",
                        defaultSize: "17pt bold",
                        sample: Text("System 17 Bold").font(.system(size: 17, weight: .bold))
                    )
                }
            }
            .padding(20)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Type Scale")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            NewRelic.recordCustomEvent("ScreenView", attributes: [
                "screenName": "TypeScaleTestCase",
                "testCase": "TypeScale"
            ])
        }
    }
}

/// A row displaying a text style with its name, default size, and sample
struct TypeStyleRow: View {
    let styleName: String
    let defaultSize: String
    let sample: Text

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(styleName)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.purple)

                Spacer()

                Text(defaultSize)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            sample
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        TypeScaleTestCase()
    }
}
