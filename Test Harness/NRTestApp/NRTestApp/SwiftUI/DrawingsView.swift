import SwiftUI
import Foundation

struct DrawingsView: View {
    @State private var animationProgress: CGFloat = 0

    var body: some View {
        ScrollView {
            MUIToken.Design.pageContainerInverse.ignoresSafeArea(edges: .top)

            VStack(spacing: 20) {
                Text("Canvas Drawings")
                    .font(.title)
                    .padding()

                // Simple Canvas drawing
                Canvas { context, size in
                    context.fill(
                        Path(ellipseIn: CGRect(x: 0, y: 0, width: size.width, height: size.height)),
                        with: .color(.blue)
                    )
                }
                .frame(width: 200, height: 200)

                // Canvas with gradient
                Canvas { context, size in
                    let rect = CGRect(origin: .zero, size: size)
                    let gradient = Gradient(colors: [.red, .orange, .yellow])
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 20),
                        with: .linearGradient(
                            gradient,
                            startPoint: .zero,
                            endPoint: CGPoint(x: size.width, y: size.height)
                        )
                    )
                }
                .frame(width: 200, height: 200)

                // Canvas with shapes
                Canvas { context, size in
                    // Draw a star
                    let path = starPath(in: CGRect(origin: .zero, size: size))
                    context.fill(path, with: .color(.purple))
                    context.stroke(path, with: .color(.white), lineWidth: 3)
                }
                .frame(width: 200, height: 200)
                .background(Color.black.opacity(0.1))

                // Animated Canvas
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        let now = timeline.date.timeIntervalSinceReferenceDate
                        let angle = Angle.degrees(now.remainder(dividingBy: 2) * 180)

                        let center = CGPoint(x: size.width / 2, y: size.height / 2)
                        let radius = min(size.width, size.height) / 2 - 10

                        // Draw spinning circle
                        let offset = CGPoint(
                            x: center.x + CGFloat(cos(angle.radians)) * radius * 0.5,
                            y: center.y + CGFloat(sin(angle.radians)) * radius * 0.5
                        )

                        context.fill(
                            Path(ellipseIn: CGRect(x: offset.x - 20, y: offset.y - 20, width: 40, height: 40)),
                            with: .color(.green)
                        )

                        // Draw center circle
                        context.fill(
                            Path(ellipseIn: CGRect(x: center.x - 10, y: center.y - 10, width: 20, height: 20)),
                            with: .color(.red)
                        )
                    }
                }
                .frame(width: 200, height: 200)
                .background(Color.gray.opacity(0.1))

                // Canvas with lines
                Canvas { context, size in
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: size.height / 2))

                    for i in stride(from: 0, to: size.width, by: 10) {
                        let y = size.height / 2 + CGFloat(sin(Double(i) / 20)) * 50
                        path.addLine(to: CGPoint(x: i, y: y))
                    }

                    context.stroke(path, with: .color(.blue), lineWidth: 3)
                }
                .frame(width: 300, height: 150)
                .background(Color.white)
            }
            .padding()
        }
        .background(Color(red: 240/255, green: 245/255, blue: 250/255))
        .navigationBarTitle("Canvas Drawings", displayMode: .inline)
    }

    // Helper function to create a star path
    private func starPath(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2 - 10
        let innerRadius = outerRadius * 0.4
        let numberOfPoints = 5

        var path = Path()

        for i in 0..<numberOfPoints * 2 {
            let angle = Angle.degrees(Double(i) * 360 / Double(numberOfPoints * 2) - 90)
            let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle.radians)) * radius,
                y: center.y + CGFloat(sin(angle.radians)) * radius
            )

            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }
}
