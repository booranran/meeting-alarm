import AppKit
import SwiftUI

class BannerWindowController: NSObject {
    private var window: NSWindow?
    private var hideTimer: Timer?

    func show(title: String, totalSeconds: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.hideTimer?.invalidate()
            self.window?.orderOut(nil)
            self.window = nil

            guard let screen = NSScreen.main else { return }
            let bannerWidth: CGFloat = 360
            let bannerHeight: CGFloat = 56
            let x = (screen.frame.width - bannerWidth) / 2
            let y = screen.frame.maxY - 24 - bannerHeight - 12

            let win = NSWindow(
                contentRect: NSRect(x: x, y: y, width: bannerWidth, height: bannerHeight),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            win.level = .floating
            win.isOpaque = false
            win.backgroundColor = .clear
            win.hasShadow = true
            win.ignoresMouseEvents = false
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            let hostingView = NSHostingView(rootView: BannerView(title: title, totalSeconds: totalSeconds) {
                DispatchQueue.main.async { [weak self] in
                    self?.dismiss()
                }
            })
            hostingView.frame = NSRect(x: 0, y: 0, width: bannerWidth, height: bannerHeight)
            win.contentView = hostingView
            self.window = win
            win.alphaValue = 0
            win.makeKeyAndOrderFront(nil)

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.3
                win.animator().alphaValue = 1.0
            }

            self.hideTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: false) { [weak self] _ in
                self?.dismiss()
            }
        }
    }

    func dismiss() {
        hideTimer?.invalidate()
        hideTimer = nil
        guard let win = window else { return }
        self.window = nil
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            win.animator().alphaValue = 0
        }, completionHandler: {
            win.orderOut(nil)
        })
    }
}

struct BannerView: View {
    let title: String
    let onDismiss: () -> Void

    @State private var secondsLeft: Int = 0
    @State private var isBlinking = false
    @State private var blinkVisible = true
    @State private var isLive = false

    let totalSeconds: Int

    init(title: String, totalSeconds: Int, onDismiss: @escaping () -> Void) {
        self.title = title
        self.totalSeconds = totalSeconds
        self.onDismiss = onDismiss
        self._secondsLeft = State(initialValue: totalSeconds)
    }

    var isUrgent: Bool { secondsLeft <= 10 && !isLive }
    var isVeryUrgent: Bool { secondsLeft <= 3 && !isLive }

    var timeString: String {
        if isLive { return "" }
        let m = secondsLeft / 60
        let s = secondsLeft % 60
        return String(format: "%d:%02d", m, s)
    }

    var body: some View {
        HStack(spacing: 12) {
            // 라이브 아이콘
            Image(systemName: isLive ? "antenna.radiowaves.left.and.right" : "clock.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isUrgent ? .white : .yellow)

            VStack(alignment: .leading, spacing: 2) {
                if isLive {
                    Text("\(title) is live!")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text(title)
                        .font(.system(size: isUrgent ? 13 : 12, weight: isUrgent ? .bold : .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
            }

            Spacer()

            // 카운트다운
            if !isLive {
                Text(timeString)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(isUrgent ? .white : .yellow)
                    .opacity(isUrgent && !blinkVisible ? 0 : 1)
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isUrgent && blinkVisible ? Color.red : Color.clear)
                .animation(.easeInOut(duration: 0.2), value: blinkVisible)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                        .opacity(isUrgent && blinkVisible ? 0 : 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                )
        )
        .environment(\.colorScheme, .dark)
        .onAppear {
            startCountdown()
        }
    }

    func startCountdown() {
        // 매 1초마다 카운트다운
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if secondsLeft > 0 {
                secondsLeft -= 1
            } else {
                timer.invalidate()
                isLive = true
            }
        }

        // 깜빡임 타이머 (10초부터)
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if isLive {
                timer.invalidate()
                return
            }
            if secondsLeft <= 3 {
                // 3초 이하: 빠르게 깜빡
                blinkVisible.toggle()
            } else if secondsLeft <= 10 {
                // 10초 이하: 느리게 깜빡
                // 0.5초 간격으로
                if Int(Date().timeIntervalSince1970 * 2) % 2 == 0 {
                    blinkVisible = true
                } else {
                    blinkVisible = false
                }
            } else {
                blinkVisible = true
            }
        }
    }
}
