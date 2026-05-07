#if DEBUG

import SwiftUI

@available(iOS 15.0, *)
struct SRDevHUDView: View {
    @StateObject private var vm = SRDevHUDViewModel()
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if expanded {
                panel.transition(.move(edge: .top).combined(with: .opacity))
            }
            pill
        }
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
    }

    private var pill: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                expanded.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(vm.isRunning ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text("SR: \(vm.modeText)")
                    .font(.caption.monospaced())
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.75))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("sr_dev_hud_pill")
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 4) {
            row("Mode",         vm.modeText)
            row("Running",      vm.isRunning ? "yes" : "no")
            row("Manual",       vm.isManual ? "yes" : "no")
            row("Harvest",      "\(vm.harvestPeriod)s")
            row("Last harvest", vm.lastHarvestText)
            row("Session",      vm.sessionIdShort)

            Divider().background(Color.white.opacity(0.2))

            HStack(spacing: 8) {
                Button("Harvest") { vm.forceHarvest() }
                    .buttonStyle(.bordered)
                    .tint(.white)
                Button(vm.isRunning ? "Pause" : "Record") { vm.toggle() }
                    .buttonStyle(.bordered)
                    .tint(.white)
            }
            .padding(.top, 4)
        }
        .font(.caption.monospaced())
        .foregroundColor(.white)
        .padding(10)
        .background(Color.black.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(minWidth: 220)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundColor(.white.opacity(0.6))
            Spacer(minLength: 12)
            Text(value)
        }
    }
}

#endif
