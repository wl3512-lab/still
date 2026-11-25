import SwiftUI

/// Simulator stand-in for the camera (the simulator has no camera). It draws a
/// simple scene (horizon + subject) and feeds the same `FrameScene` facts the
/// Vision pass would, so the rule engine and hybrid coach run for real.
/// Auto-plays a short script; drag to move the subject, two-finger rotate
/// (Option-drag in the simulator) to tilt the horizon.
struct DemoStage: View {
    @Binding var scene: FrameScene
    @State private var tilt: Double = 7       // degrees, + = horizon drops to the right (phone needs a clockwise turn)
    @State private var x: Double = 0.5        // subject centre, 0...1
    @State private var target = (tilt: 7.0, x: 0.5)
    @State private var step = 0
    @State private var autoplay = true
    @State private var baseTilt: Double?

    /// Simulator always; on a device only with the `-demo` launch argument.
    /// (Probing AVCaptureDevice here would trigger the camera permission prompt.)
    static var needed: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return ProcessInfo.processInfo.arguments.contains("-demo")
        #endif
    }

    // Each step: where the "phone" ends up, and how long to linger there.
    private let script: [(tilt: Double, x: Double, wait: Double)] = [
        (7, 0.50, 3.5),   // tilted -> "level it"
        (0, 0.50, 3.5),   // level, subject centred -> "move left"
        (0, 0.66, 4.0),   // on the third -> "hold, take it"
        (-5, 0.30, 3.5),  // knocked off again -> new cue
        (0, 0.33, 4.0),
    ]

    private let tick = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect()
    @State private var lastPublish = Date.distantPast
    @State private var stepStarted = Date()

    var body: some View {
        GeometryReader { g in
            ZStack {
                LinearGradient(colors: [Color(red: 0.55, green: 0.7, blue: 0.85), Color(red: 0.93, green: 0.85, blue: 0.75)],
                               startPoint: .top, endPoint: .center)
                Rectangle().fill(Color(red: 0.32, green: 0.42, blue: 0.3))
                    .frame(width: g.size.width * 3, height: g.size.height)
                    .offset(y: g.size.height * 0.5)
                    .rotationEffect(.degrees(-tilt))
                Capsule().fill(Color(red: 0.2, green: 0.18, blue: 0.22))
                    .frame(width: g.size.width * 0.16, height: g.size.height * 0.3)
                    .position(x: g.size.width * x, y: g.size.height * 0.52)
            }
            .frame(width: g.size.width, height: g.size.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(DragGesture().onChanged { v in
                autoplay = false
                x = min(max(v.location.x / g.size.width, 0.05), 0.95); target.x = x
            })
            .simultaneousGesture(RotationGesture().onChanged { a in
                autoplay = false
                if baseTilt == nil { baseTilt = tilt }
                tilt = (baseTilt ?? 0) - a.degrees; target.tilt = tilt
            }.onEnded { _ in baseTilt = nil })
        }
        .ignoresSafeArea()
        .overlay(alignment: .topLeading) {
            Button(autoplay ? "Demo · auto" : "Demo · hands-on") { autoplay.toggle(); stepStarted = Date() }
                .font(.caption.weight(.semibold)).foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(.black.opacity(0.5), in: Capsule()).padding(.leading)
        }
        .onReceive(tick) { now in advance(now) }
    }

    private func advance(_ now: Date) {
        if autoplay {
            let s = script[step]
            target = (s.tilt, s.x)
            if now.timeIntervalSince(stepStarted) > s.wait {
                step = (step + 1) % script.count; stepStarted = now
            }
            // Ease toward the target like a hand moving the phone.
            tilt += (target.tilt - tilt) * 0.08
            x += (target.x - x) * 0.08
        }
        // Publish ~6x a second, like the Vision pass.
        guard now.timeIntervalSince(lastPublish) > 1.0 / 6 else { return }
        lastPublish = now
        let w = 0.16, h = 0.3
        scene = FrameScene(horizonDegrees: abs(tilt) < 0.3 ? 0 : tilt,
                           subject: CGRect(x: x - w / 2, y: 0.52 - h / 2, width: w, height: h),
                           subjectIsFace: false)
    }
}
