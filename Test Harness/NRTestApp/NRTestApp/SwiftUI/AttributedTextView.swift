//
//  AttributedTextView.swift
//  NRTestApp
//
//  Created for testing Session Replay SwiftUI text rendering
//

import SwiftUI
import NewRelic
import Combine

struct AttributedTextView: View {
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Section 0: Timer that updates quickly
                sectionHeader("Text - Timer (updates 10x per second)")
                HStack(spacing: 4) {
                    Text("Timer: ")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                    Text(timeString)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.blue)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.systemBackground))

                // Section 1: Multiline with Mixed Formatting
                sectionHeader("Text - Multiline with Mixed Formatting")
                VStack(alignment: .leading, spacing: 8) {
                    Text("Large Bold Red Text")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.red)

                    (Text("This is normal text with increased line spacing. ")
                        .font(.system(size: 16))
                        .foregroundColor(.primary) +
                     Text("And this is small italic green text.")
                        .font(.system(size: 14))
                        .italic()
                        .foregroundColor(.green))
                        .lineSpacing(8)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.systemBackground))

                // Section 2: Custom Spacing and Alignment
                sectionHeader("Text - Custom Letter Spacing & Center Aligned")
                Text("Text with custom letter spacing\nSecond line with same formatting")
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
                    .kerning(2.0)
                    .lineSpacing(10)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(UIColor.systemBackground))

                // Section 3: Bold, Italic, and Font Weights
                sectionHeader("Text - Bold, Italic, Font Weights")
                HStack(spacing: 4) {
                    Text("Bold ")
                        .font(.system(size: 16, weight: .bold))
                    Text("Italic ")
                        .font(.system(size: 16))
                        .italic()
                    Text("Bold+Italic ")
                        .font(.system(size: 16, weight: .bold))
                        .italic()
                    Text("Light ")
                        .font(.system(size: 16, weight: .light))
                    Text("Heavy")
                        .font(.system(size: 16, weight: .heavy))
                }
                .foregroundColor(.primary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.systemBackground))

                // Section 4: TextField with custom styling
                sectionHeader("TextField - Custom Styling")
                if #available(iOS 16.0, *) {
                    TextField("Type something...", text: .constant("Pre-filled attributed text"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.purple)
                        .kerning(0.5)
                        .padding()
                        .background(Color(UIColor.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                        .padding(.horizontal)
                } else {
                    // Fallback on earlier versions
                }

                // Section 5: TextEditor with complex formatting
                sectionHeader("TextEditor - Complex Formatting")
                VStack(alignment: .center, spacing: 10) {
                    Text("TextEditor Title")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(UIColor.systemIndigo))

                    VStack(alignment: .leading, spacing: 6) {
                        (Text("This TextEditor contains multiple paragraphs with different formatting. ")
                            .font(.system(size: 15))
                            .foregroundColor(.primary) +
                         Text("This part is emphasized ")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.orange)
                            .kerning(1.5) +
                         Text("and this is regular again with mixed colors and styles.")
                            .font(.system(size: 15))
                            .foregroundColor(.primary))

                        Text("— End of test text —")
                            .font(.system(size: 13))
                            .italic()
                            .foregroundColor(.secondary)
                            .kerning(2.0)
                    }
                    .lineSpacing(6)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
                .padding(.horizontal)

                // Section 6: Word Wrapping (unlimited lines)
                sectionHeader("Text - Word Wrapping (unlimited)")
                Text("This is a long text with unlimited lines. It should wrap to multiple lines as needed without cutting off any text. The browser should render this similarly to iOS. This tests the word wrapping behavior in session replay.")
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .kerning(0.3)
                    .lineSpacing(5)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.systemBackground))

                // Section 7: Line Limit with Truncation
                sectionHeader("Text - Line Limit (2 lines, truncated)")
                Text("This text has a line limit set to 2 with truncating tail mode. If the text is longer than two lines, it should show an ellipsis (...) at the end. This tests the truncation behavior in session replay.")
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .kerning(0.3)
                    .lineSpacing(4)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.systemBackground))

                // Section 8: Different Font Styles
                sectionHeader("Text - Different Font Families")
                VStack(alignment: .leading, spacing: 8) {
                    Text("System Font")
                        .font(.system(size: 16))
                    Text("Monospaced Font")
                        .font(.system(size: 16, design: .monospaced))
                    Text("Rounded Font")
                        .font(.system(size: 16, design: .rounded))
                    Text("Serif Font")
                        .font(.system(size: 16, design: .serif))
                }
                .foregroundColor(.primary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.systemBackground))

                // Section 9: Dynamic Type Sizes
                sectionHeader("Text - Dynamic Type Sizes")
                VStack(alignment: .leading, spacing: 8) {
                    Text("Large Title")
                        .font(.largeTitle)
                    Text("Title")
                        .font(.title)
                    Text("Title 2")
                        .font(.title2)
                    Text("Title 3")
                        .font(.title3)
                    Text("Headline")
                        .font(.headline)
                    Text("Body")
                        .font(.body)
                    Text("Callout")
                        .font(.callout)
                    Text("Subheadline")
                        .font(.subheadline)
                    Text("Footnote")
                        .font(.footnote)
                    Text("Caption")
                        .font(.caption)
                    Text("Caption 2")
                        .font(.caption2)
                }
                .foregroundColor(.primary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.systemBackground))

                // Section 10: Text with Underline and Strikethrough
                sectionHeader("Text - Underline & Strikethrough")
                VStack(alignment: .leading, spacing: 8) {
                    Text("Underlined Text")
                        .font(.system(size: 16))
                        .underline()
                    Text("Strikethrough Text")
                        .font(.system(size: 16))
                        .strikethrough()
                    Text("Underlined + Strikethrough")
                        .font(.system(size: 16))
                        .underline()
                        .strikethrough()
                    Text("Colored Underline")
                        .font(.system(size: 16))
                        .underline(true, color: .red)
                }
                .foregroundColor(.primary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.systemBackground))

                // Section 11: Multiline Text Alignment
                sectionHeader("Text - Different Alignments")
                VStack(spacing: 12) {
                    Text("Left Aligned Text\nSecond Line")
                        .font(.system(size: 16))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Center Aligned Text\nSecond Line")
                        .font(.system(size: 16))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Text("Right Aligned Text\nSecond Line")
                        .font(.system(size: 16))
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .foregroundColor(.primary)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.systemBackground))
            }
            .padding(.vertical)
        }
        .navigationBarTitle("Attributed Text", displayMode: .inline)
        .NRTrackView(name: "AttributedTextView")
        .NRMobileView(name: "AttributedTextView")
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }

    private var timeString: String {
        let totalDeciseconds = Int(elapsedTime * 10)
        let minutes = totalDeciseconds / 600
        let seconds = (totalDeciseconds / 10) % 60
        let deciseconds = totalDeciseconds % 10
        return String(format: "%02d:%02d.%d", minutes, seconds, deciseconds)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            elapsedTime += 0.1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal)
            .padding(.top, 8)
    }
}

struct AttributedTextView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AttributedTextView()
        }
    }
}
