import SwiftUI
import UserNotifications
import AppKit

@main
struct MeetingAlarmApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var alarmManager: AlarmManager?
    var bannerWindow: BannerWindowController?
    
    // 메뉴바 카운트다운용
    var countdownTimer: Timer?
    var blinkTimer: Timer?
    var countdownSeconds = 0
    var blinkOn = true
    var fastBlinkTimer : Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        alarmManager = AlarmManager.shared
        bannerWindow = BannerWindowController()

        setupStatusBar()
        requestNotificationPermission()

        AlarmManager.shared.onAlarmFired = { [weak self] title in
            DispatchQueue.main.async {
                let duration = AudioManager.shared.selectedSoundDuration()
                self?.startMenuBarCountdown(title: title, totalSeconds: duration)
                AudioManager.shared.playAlarm()
            }
        }
    }

    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setMenuBarIdle()

        if let button = statusItem?.button {
            button.action = #selector(togglePopover)
            button.target = self
        }

        let popover = NSPopover()
        popover.contentViewController = NSHostingController(rootView: ContentView())
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 480)
        self.popover = popover
    }

    // MARK: - 메뉴바 카운트다운

    func startMenuBarCountdown(title: String, totalSeconds: Int) {
        countdownSeconds = totalSeconds
        blinkTimer?.invalidate()
        countdownTimer?.invalidate()
        fastBlinkTimer?.invalidate()

        // 1초마다 카운트다운
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else { return }
            if self.countdownSeconds > 1 {
                self.countdownSeconds -= 1
                self.updateMenuBarCountdown(title: title)
            } else {
                timer.invalidate()
                self.blinkTimer?.invalidate()
                self.fastBlinkTimer?.invalidate()
                self.setMenuBarLive(title: title)
                // 3초 후 원래대로
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.setMenuBarIdle()
                }
            }
        }
        RunLoop.main.add(countdownTimer!, forMode: .common)

        // 깜빡임 타이머
        // 느린 깜빡임 (10초~3초): 1초마다
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.countdownSeconds <= 10 && self.countdownSeconds > 3 {
                self.blinkOn.toggle()
                self.updateMenuBarCountdown(title: title)
            }
        }
        RunLoop.main.add(blinkTimer!, forMode: .common)

        // 빠른 깜빡임 (3초 이하): 0.15초마다
        fastBlinkTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.countdownSeconds <= 3 {
                self.blinkOn.toggle()
                self.updateMenuBarCountdown(title: title)
            }
        }
        RunLoop.main.add(fastBlinkTimer!, forMode: .common)
        updateMenuBarCountdown(title: title)
    }

    func updateMenuBarCountdown(title: String) {
        guard let button = statusItem?.button else { return }

        let m = countdownSeconds / 60
        let s = countdownSeconds % 60
        let timeStr = String(format: "%d:%02d", m, s)
        let isUrgent = countdownSeconds <= 10
        let fullText = "\(title) in \(timeStr)"

        if isUrgent && !blinkOn {
            // 깜빡임 OFF 상태: 배경 없음
            button.attributedTitle = NSAttributedString(string: fullText, attributes: [
                .foregroundColor: NSColor.labelColor,
                .font: NSFont.systemFont(ofSize: 13, weight: .regular)
            ])
            button.layer?.backgroundColor = NSColor.clear.cgColor
        } else if isUrgent {
            // 깜빡임 ON 상태: 빨간 배경 + 흰 굵은 글씨
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.labelColor,
                .font: NSFont.systemFont(ofSize: 13, weight: .bold)
            ]
            button.attributedTitle = NSAttributedString(string: fullText, attributes: attrs)
            button.layer?.backgroundColor = NSColor.systemRed.cgColor
            button.layer?.cornerRadius = 6
        } else {
            // 일반 상태
            button.attributedTitle = NSAttributedString(string: fullText, attributes: [
                .foregroundColor: NSColor.labelColor,
                .font: NSFont.systemFont(ofSize: 13, weight: .regular)
            ])
            button.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }

    func setMenuBarLive(title: String) {
        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: "antenna.radiowaves.left.and.right", accessibilityDescription: "live")
         button.imagePosition = .imageLeft
        button.attributedTitle = NSAttributedString(string: "\(title) is live!", attributes: [
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.systemFont(ofSize: 13, weight: .regular)
        ])
        button.layer?.backgroundColor = NSColor.clear.cgColor
    }

    func setMenuBarIdle() {
        guard let button = statusItem?.button else { return }
        button.attributedTitle = NSAttributedString(string: "")
        button.image = NSImage(systemSymbolName: "antenna.radiowaves.left.and.right", accessibilityDescription: "MeetingAlarm")
        button.layer?.backgroundColor = NSColor.clear.cgColor
    }

    @objc func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover?.isShown == true {
            popover?.performClose(nil)
        } else {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}
