import SwiftUI

// MARK: - ViewModel

final class AnimTransitionViewModel: ObservableObject {
    // Each @Published bool drives a separate `.animation(_:value:)` call —
    // mirrors the pattern: .animation(.easeInOut, value: viewModel.showingMainTabView)
    @Published var showCard: Bool = false
    @Published var showMainTabView: Bool = false   // named to match SessionReplay ViewModel
    @Published var showTransitionBox: Bool = false
    @Published var showCombinedBox: Bool = false

    // Scalar properties — demonstrate .animation on non-Bool values
    @Published var scaleValue: CGFloat = 1.0
    @Published var opacityValue: Double = 1.0
    @Published var offsetValue: CGFloat = 0
    @Published var rotationValue: Double = 0
}

// MARK: - Animation Curve Catalog

enum AnimCurveKind: String, CaseIterable, Identifiable {
    case easeInOut              = ".easeInOut"
    case easeInOutDuration      = ".easeInOut(duration: 0.6)"
    case easeIn                 = ".easeIn"
    case easeOut                = ".easeOut"
    case linear                 = ".linear"
    case springDefault          = ".spring()"
    case interactiveSpring      = ".interactiveSpring()"
    case interpolatingSpring    = ".interpolatingSpring(mass:stiffness:damping:)"
    case customSpring            = ".spring(response:dampingFraction:blendDuration:)"
    case bouncy                 = ".bouncy  [iOS 17+]"
    case smooth                 = ".smooth  [iOS 17+]"
    case delayed                = ".easeInOut + .delay(0.3)"
    case repeated               = ".easeInOut + .repeatCount(3)"

    var id: String { rawValue }

    func makeAnimation() -> Animation {
        switch self {
        case .easeInOut:
            return .easeInOut
        case .easeInOutDuration:
            return .easeInOut(duration: 0.6)
        case .easeIn:
            return .easeIn
        case .easeOut:
            return .easeOut
        case .linear:
            return .linear
        case .springDefault:
            return .spring()
        case .interactiveSpring:
            return .interactiveSpring()
        case .interpolatingSpring:
            return .interpolatingSpring(mass: 1, stiffness: 120, damping: 12)
        case .customSpring:
            return .spring(response: 0.45, dampingFraction: 0.55, blendDuration: 0.15)
        case .bouncy:
            if #available(iOS 17.0, *) { return .bouncy }
            return .spring(response: 0.4, dampingFraction: 0.5)
        case .smooth:
            if #available(iOS 17.0, *) { return .smooth }
            return .easeInOut
        case .delayed:
            return .easeInOut(duration: 0.5).delay(0.3)
        case .repeated:
            return .easeInOut(duration: 0.35).repeatCount(3, autoreverses: true)
        }
    }
}

// MARK: - Transition Catalog

enum TransitionKind: String, CaseIterable, Identifiable {
    case opacity                = ".opacity"
    case slide                  = ".slide"
    case moveLeading            = ".move(edge: .leading)"
    case moveTrailing           = ".move(edge: .trailing)"
    case moveTop                = ".move(edge: .top)"
    case moveBottom             = ".move(edge: .bottom)"
    case scale                  = ".scale"
    case scaleTopLeading        = ".scale(scale: 0, anchor: .topLeading)"
    case scaleBottomTrailing    = ".scale(scale: 0, anchor: .bottomTrailing)"
    case offsetLeft             = ".offset(x: -150, y: 0)"
    case offsetUp               = ".offset(x: 0, y: -80)"
    case asymmetricSlide        = ".asymmetric(insertion: .slide, removal: .opacity)"
    case asymmetricMove         = ".asymmetric(insertion: .move(.top), removal: .move(.bottom))"
    case combined               = ".opacity.combined(with: .scale)"
    case combinedMoveOpacity    = ".move(.leading).combined(with: .opacity)"
    case push                   = ".push(from: .leading)  [iOS 16+]"

    var id: String { rawValue }

    var transition: AnyTransition {
        switch self {
        case .opacity:
            return .opacity
        case .slide:
            return .slide
        case .moveLeading:
            return .move(edge: .leading)
        case .moveTrailing:
            return .move(edge: .trailing)
        case .moveTop:
            return .move(edge: .top)
        case .moveBottom:
            return .move(edge: .bottom)
        case .scale:
            return .scale
        case .scaleTopLeading:
            return .scale(scale: 0.001, anchor: .topLeading)
        case .scaleBottomTrailing:
            return .scale(scale: 0.001, anchor: .bottomTrailing)
        case .offsetLeft:
            return .offset(x: -150, y: 0)
        case .offsetUp:
            return .offset(x: 0, y: -80)
        case .asymmetricSlide:
            return .asymmetric(insertion: .slide, removal: .opacity)
        case .asymmetricMove:
            return .asymmetric(insertion: .move(edge: .top), removal: .move(edge: .bottom))
        case .combined:
            return .opacity.combined(with: .scale)
        case .combinedMoveOpacity:
            return .move(edge: .leading).combined(with: .opacity)
        case .push:
            if #available(iOS 16.0, *) { return .push(from: .leading) }
            return .slide
        }
    }
}

// MARK: - Main View

@available(iOS 16.0, *)
struct AnimationTransitionDemoView: View {
    @StateObject private var viewModel = AnimTransitionViewModel()
    @State private var selectedCurve: AnimCurveKind = .easeInOut
    @State private var selectedTransition: TransitionKind = .opacity

    // Mirrors the pattern in UIHostingViewRecordOrchestrator:
    // var edgeTransition: AnyTransition = .opacity
    var edgeTransition: AnyTransition { selectedTransition.transition }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                animationCurveSection
                transitionSection
                combinedSection
                scalarAnimationSection
                hardcodedExamplesSection
            }
            .padding()
        }
        .navigationTitle("Animations & Transitions")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Section 1 – Value-driven animation curves

    private var animationCurveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DemoSectionHeader(title: "1 · .animation(_:value:) — curve picker")
            Text(".animation(selectedCurve, value: viewModel.showCard)")
                .font(.caption.monospaced())
                .foregroundColor(.secondary)

            Picker("Curve", selection: $selectedCurve) {
                ForEach(AnimCurveKind.allCases) { c in
                    Text(c.rawValue).tag(c)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 110)

            HStack(spacing: 12) {
                Button("Toggle Card A") { viewModel.showCard.toggle() }
                    .buttonStyle(.borderedProminent)
                Button("Toggle Main Tab") { viewModel.showMainTabView.toggle() }
                    .buttonStyle(.bordered)
            }

            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 88)

                if viewModel.showCard {
                    if #available(iOS 16.0, *) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue.gradient)
                            .frame(height: 70)
                            .overlay(Text("Card A").bold().foregroundColor(.white))
                        // ↓ value-driven animation — the canonical form
                            .animation(selectedCurve.makeAnimation(), value: viewModel.showCard)
                    } else {
                        // Fallback on earlier versions
                    }
                }

                if viewModel.showMainTabView {
                    if #available(iOS 16.0, *) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.green.gradient)
                            .frame(height: 70)
                            .overlay(Text("showMainTabView").bold().foregroundColor(.white))
                        // ↓ mirrors: .animation(.easeInOut, value: viewModel.showingMainTabView)
                            .animation(selectedCurve.makeAnimation(), value: viewModel.showMainTabView)
                    } else {
                        // Fallback on earlier versions
                    }
                }
            }
        }
        .animDemoCard()
    }

    // MARK: Section 2 – Transition picker (edgeTransition pattern)

    private var transitionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DemoSectionHeader(title: "2 · .transition(edgeTransition)")
            Text("var edgeTransition: AnyTransition = .opacity")
                .font(.caption.monospaced())
                .foregroundColor(.secondary)

            Picker("Transition", selection: $selectedTransition) {
                ForEach(TransitionKind.allCases) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 110)

            Button("Toggle") {
                withAnimation(.easeInOut) { viewModel.showTransitionBox.toggle() }
            }
            .buttonStyle(.borderedProminent)

            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 88)
                if viewModel.showTransitionBox {
                    if #available(iOS 16.0, *) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.purple.gradient)
                            .frame(height: 70)
                            .overlay(
                                Text(selectedTransition.rawValue)
                                    .font(.caption2.bold())
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(4)
                            )
                        // ↓ uses the edgeTransition property — same pattern as in SessionReplay
                            .transition(edgeTransition)
                    } else {
                        // Fallback on earlier versions
                    }
                }
            }
        }
        .animDemoCard()
    }

    // MARK: Section 3 – Animation + Transition combined

    private var combinedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DemoSectionHeader(title: "3 · .animation + .transition combined")
            Text(".transition(edgeTransition).animation(curve, value:)")
                .font(.caption.monospaced())
                .foregroundColor(.secondary)

            Button("Toggle") {
                viewModel.showCombinedBox.toggle()
            }
            .buttonStyle(.borderedProminent)

            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 88)
                if viewModel.showCombinedBox {
                    if #available(iOS 16.0, *) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.orange.gradient)
                            .frame(height: 70)
                            .overlay(Text("Transition + Animation").bold().foregroundColor(.white))
                            .transition(edgeTransition)
                        // ↓ value-based form paired with transition
                            .animation(selectedCurve.makeAnimation(), value: viewModel.showCombinedBox)
                    } else {
                        // Fallback on earlier versions
                    }
                }
            }
        }
        .animDemoCard()
    }

    // MARK: Section 4 – Scalar (non-Bool) value animations

    private var scalarAnimationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DemoSectionHeader(title: "4 · Scalar value animations (CGFloat, Double)")

            HStack(spacing: 8) {
                Button("Scale") {
                    viewModel.scaleValue = viewModel.scaleValue == 1.0 ? 1.6 : 1.0
                }
                Button("Opacity") {
                    viewModel.opacityValue = viewModel.opacityValue == 1.0 ? 0.15 : 1.0
                }
                Button("Offset") {
                    viewModel.offsetValue = viewModel.offsetValue == 0 ? 70 : 0
                }
                Button("Rotate") {
                    viewModel.rotationValue = viewModel.rotationValue == 0 ? 45 : 0
                }
            }
            .buttonStyle(.bordered)
            .font(.caption)

            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 90)
                if #available(iOS 16.0, *) {
                    Circle()
                        .fill(Color.red.gradient)
                        .frame(width: 52, height: 52)
                        .scaleEffect(viewModel.scaleValue)
                        .animation(selectedCurve.makeAnimation(), value: viewModel.scaleValue)
                        .opacity(viewModel.opacityValue)
                        .animation(selectedCurve.makeAnimation(), value: viewModel.opacityValue)
                        .offset(x: viewModel.offsetValue)
                        .animation(selectedCurve.makeAnimation(), value: viewModel.offsetValue)
                        .rotationEffect(.degrees(viewModel.rotationValue))
                        .animation(selectedCurve.makeAnimation(), value: viewModel.rotationValue)
                } else {
                    // Fallback on earlier versions
                }
            }
        }
        .animDemoCard()
    }

    // MARK: Section 5 – Hardcoded named examples (self-contained rows)

    private var hardcodedExamplesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            DemoSectionHeader(title: "5 · Named hardcoded examples")
            ForEach(HardcodedAnimExample.allCases) { example in
                HardcodedAnimRow(example: example)
                if example != HardcodedAnimExample.allCases.last {
                    Divider()
                }
            }
        }
        .animDemoCard()
    }
}

// MARK: - Hardcoded Named Examples

enum HardcodedAnimExample: String, CaseIterable, Identifiable {
    // Animation curves (value-driven)
    case easeInOutValue         = ".animation(.easeInOut, value:)"
    case springValue            = ".animation(.spring(), value:)"
    case bouncyValue            = ".animation(.bouncy, value:)  [iOS 17+]"
    case interpolatingSpringVal = ".animation(.interpolatingSpring(...), value:)"
    case delayedValue           = ".animation(.easeInOut.delay(0.3), value:)"
    case repeatedValue          = ".animation(.easeInOut.repeatCount(3), value:)"
    // Transitions
    case transOpacity           = ".transition(.opacity)"
    case transSlide             = ".transition(.slide)"
    case transMoveLeading       = ".transition(.move(edge: .leading))"
    case transMoveTop           = ".transition(.move(edge: .top))"
    case transScale             = ".transition(.scale)"
    case transScaleAnchor       = ".transition(.scale(scale:0, anchor:.topLeading))"
    case transOffset            = ".transition(.offset(x: -150))"
    case transAsymmetric        = ".transition(.asymmetric(slide in / opacity out))"
    case transCombined          = ".transition(.opacity.combined(with: .scale))"

    var id: String { rawValue }

    var isAnimationExample: Bool {
        switch self {
        case .easeInOutValue, .springValue, .bouncyValue,
             .interpolatingSpringVal, .delayedValue, .repeatedValue:
            return true
        default:
            return false
        }
    }

    var color: Color {
        switch self {
        case .easeInOutValue:          return .blue
        case .springValue:             return .green
        case .bouncyValue:             return .orange
        case .interpolatingSpringVal:  return .mint
        case .delayedValue:            return .purple
        case .repeatedValue:           return .indigo
        case .transOpacity:            return .pink
        case .transSlide:              return .teal
        case .transMoveLeading:        return .cyan
        case .transMoveTop:            return .brown
        case .transScale:              return .red
        case .transScaleAnchor:        return Color(red: 0.8, green: 0.2, blue: 0.6)
        case .transOffset:             return Color(red: 0.2, green: 0.6, blue: 0.4)
        case .transAsymmetric:         return Color(red: 0.6, green: 0.4, blue: 0.8)
        case .transCombined:           return Color(red: 0.9, green: 0.5, blue: 0.1)
        }
    }
}

@available(iOS 16.0, *)
struct HardcodedAnimRow: View {
    let example: HardcodedAnimExample
    @State private var isVisible: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(example.rawValue)
                    .font(.caption2.monospaced())
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                Spacer()
                Button(isVisible ? "Hide" : "Show") {
                    if example.isAnimationExample {
                        // animation modifier on the child view drives the change
                        isVisible.toggle()
                    } else {
                        withAnimation(.easeInOut) { isVisible.toggle() }
                    }
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.07))
                    .frame(height: 40)

                if isVisible {
                    rowContent
                        .transition(rowTransition)
                        .animation(rowAnimation, value: isVisible)
                }
            }
        }
    }

    @ViewBuilder private var rowContent: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(example.color.gradient)
            .frame(height: 32)
            .padding(.horizontal, 4)
            .overlay(
                Text(example.rawValue)
                    .font(.caption2)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
            )
    }

    private var rowAnimation: Animation {
        switch example {
        case .easeInOutValue:
            return .easeInOut
        case .springValue:
            return .spring()
        case .bouncyValue:
            if #available(iOS 17.0, *) { return .bouncy }
            return .spring()
        case .interpolatingSpringVal:
            return .interpolatingSpring(mass: 1, stiffness: 120, damping: 12)
        case .delayedValue:
            return .easeInOut(duration: 0.5).delay(0.3)
        case .repeatedValue:
            return .easeInOut(duration: 0.35).repeatCount(3, autoreverses: true)
        default:
            return .easeInOut
        }
    }

    private var rowTransition: AnyTransition {
        switch example {
        case .transOpacity:
            return .opacity
        case .transSlide:
            return .slide
        case .transMoveLeading:
            return .move(edge: .leading)
        case .transMoveTop:
            return .move(edge: .top)
        case .transScale:
            return .scale
        case .transScaleAnchor:
            return .scale(scale: 0.001, anchor: .topLeading)
        case .transOffset:
            return .offset(x: -150, y: 0)
        case .transAsymmetric:
            return .asymmetric(insertion: .slide, removal: .opacity)
        case .transCombined:
            return .opacity.combined(with: .scale)
        default:
            return .opacity
        }
    }
}

// MARK: - Shared Helpers

private struct DemoSectionHeader: View {
    let title: String
    var body: some View {
        Text(title).font(.headline)
    }
}

private extension View {
    func animDemoCard() -> some View {
        self
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
    }
}
