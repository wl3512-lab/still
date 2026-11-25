import SwiftUI

struct CameraScreen: View {
    @StateObject private var camera = Camera()
    @State private var coach = Coach()
    @State private var preferCloud = false

    @State private var move: Move = .unsure
    @State private var candidate: Move = .unsure
    @State private var streak = 0
    @State private var showWords = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if camera.authorized == true {
                CameraPreview(session: camera.session).ignoresSafeArea()
                thirdsGrid.allowsHitTesting(false)
            } else if camera.authorized == false {
                Text("still needs the camera to coach you.\nTurn it on in Settings.")
                    .multilineTextAlignment(.center).foregroundStyle(.white)
            }
            if camera.flash { Color.white.ignoresSafeArea() }

            VStack {
                HStack { Spacer(); tierBadge }.padding(.horizontal)
                Spacer()
                cue
                Spacer().frame(height: 28)
                shutter
            }
            .padding(.bottom, 24)
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: camera.scene) { _, s in settle(RuleEngine.move(for: s)) }
    }

    /// Only switch cues once a move holds for ~0.5 s, so the guide never flickers.
    private func settle(_ next: Move) {
        if next.key == candidate.key { streak += 1 } else { candidate = next; streak = 0 }
        guard streak >= 3, next.key != move.key else { return }
        if next == .hold, move != .unsure { Learning.followed(move) }
        showWords = false
        withAnimation(.easeOut(duration: 0.2)) { move = next }
        // Show, then say: arrow first, words a beat later.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if move.key == next.key { withAnimation(.easeIn(duration: 0.25)) { showWords = true } }
        }
    }

    private var cue: some View {
        VStack(spacing: 12) {
            Image(systemName: move.symbol)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(move == .hold ? .yellow : .white)
                .contentTransition(.symbolEffect(.replace))
            if showWords && !Learning.isLearned(move) {
                Text(coach.phrase(for: move))
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(.black.opacity(0.45), in: Capsule())
                    .transition(.opacity)
            }
        }
        .shadow(radius: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(coach.phrase(for: move))
    }

    private var shutter: some View {
        Button { camera.shoot() } label: {
            Circle().strokeBorder(.white, lineWidth: 4).frame(width: 74, height: 74)
                .overlay(Circle().fill(move == .hold ? .yellow : .white).padding(8))
        }
        .accessibilityLabel("Take photo")
    }

    /// Shows which brain is phrasing the cue. Tap to try the cloud path; long-press to reset learning.
    private var tierBadge: some View {
        Text(coach.tier.rawValue)
            .font(.caption.weight(.semibold)).foregroundStyle(.white)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(coach.tier == .cloud ? Color.blue.opacity(0.7) : Color.black.opacity(0.5), in: Capsule())
            .onTapGesture {
                guard coach.canUseCloud else { return }
                preferCloud.toggle(); coach.configure(preferCloud: preferCloud)
            }
            .onLongPressGesture { Learning.reset() }
            .accessibilityLabel("Coach running \(coach.tier.rawValue)")
    }

    private var thirdsGrid: some View {
        GeometryReader { g in
            Path { p in
                for f in [1.0/3, 2.0/3] {
                    p.move(to: .init(x: g.size.width * f, y: 0)); p.addLine(to: .init(x: g.size.width * f, y: g.size.height))
                    p.move(to: .init(x: 0, y: g.size.height * f)); p.addLine(to: .init(x: g.size.width, y: g.size.height * f))
                }
            }.stroke(.white.opacity(0.18), lineWidth: 0.5)
        }.ignoresSafeArea()
    }
}
