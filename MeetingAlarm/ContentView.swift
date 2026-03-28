import SwiftUI
import EventKit

struct ContentView: View {
    @StateObject private var alarm = AlarmManager.shared
    @StateObject private var audio = AudioManager.shared
    @State var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundColor(.yellow)
                Text("MeetingAlarm")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                // Next meeting preview
                if let meeting = alarm.nextMeeting {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("다음 회의")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text(meetingCountdown(meeting.startDate))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.yellow)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Tab Picker
            Picker("", selection: $selectedTab) {
                Text("알림 규칙").tag(0)
                Text("음원 관리").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            Group {
                if selectedTab == 0 {
                    RulesView()
                } else {
                    SoundsView()
                }
            }
            .frame(maxHeight: .infinity)

            Divider()

            // Footer
            HStack {
                Circle()
                    .fill(alarm.calendarAccessGranted ? Color.green : Color.red)
                    .frame(width: 6, height: 6)
                Text(alarm.calendarAccessGranted ? "캘린더 연결됨" : "캘린더 접근 필요")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
                Button("종료") { NSApp.terminate(nil) }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 360, height: 480)
    }

    func meetingCountdown(_ date: Date) -> String {
        let diff = date.timeIntervalSinceNow
        if diff < 0 { return "진행 중" }
        let minutes = Int(diff / 60)
        let hours = minutes / 60
        if hours > 0 { return "\(hours)시간 \(minutes % 60)분 후" }
        return "\(minutes)분 후"
    }
}

// MARK: - Rules Tab

struct RulesView: View {
    @StateObject var alarm = AlarmManager.shared
    @StateObject var audio = AudioManager.shared
    @State var showAddSheet = false
    @State var newLabel = ""
    @State var newType: RuleTypeSelection = .calendarMeeting
    @State var secondsBefore = 10
    @State var testFired = false

    enum RuleTypeSelection { case calendarMeeting, hourly }

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach($alarm.alarmRules) { $rule in
                    HStack {
                        Toggle("", isOn: Binding(
                            get: { rule.isEnabled },
                            set: { _ in alarm.toggleRule(id: rule.id) }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.mini)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(rule.label)
                                .font(.system(size: 12, weight: .medium))
                            Text(ruleDescription(rule))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // Sound selector per rule
                        Menu(rule.soundFileName.isEmpty ? "음원 없음" : shortName(rule.soundFileName)) {
                            Button("없음") {
                                alarm.alarmRules[alarm.alarmRules.firstIndex(where: { $0.id == rule.id })!].soundFileName = ""
                                alarm.saveRules()
                            }
                            Divider()
                            ForEach(audio.downloadedSounds) { sound in
                                Button(sound.displayName) {
                                    alarm.alarmRules[alarm.alarmRules.firstIndex(where: { $0.id == rule.id })!].soundFileName = sound.name
                                    alarm.saveRules()
                                }
                            }
                        }
                        .font(.system(size: 10))
                        .frame(maxWidth: 80)
                    }
                    .padding(.vertical, 2)
                }
                .onDelete { alarm.deleteRule(at: $0) }
            }
            .listStyle(.plain)

            Divider()

            HStack {
                Button("+ 규칙 추가") { showAddSheet = true }
                    .font(.system(size: 11))
                Spacer()
                Button("테스트") {
                    AlarmManager.shared.onAlarmFired?("테스트 알림")
                    AudioManager.shared.playAlarm()
                }
                .font(.system(size: 11))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .sheet(isPresented: $showAddSheet) {
            AddRuleSheet(isPresented: $showAddSheet)
        }
    }

    func ruleDescription(_ rule: AlarmRule) -> String {
        switch rule.type {
        case .calendarMeeting(let s): return "회의 \(s)초 전 · 캘린더"
        case .hourly: return "매 정시 알림"
        }
    }

    func shortName(_ name: String) -> String {
        let s = name.replacingOccurrences(of: ".mp3", with: "").replacingOccurrences(of: ".wav", with: "")
        return s.count > 8 ? String(s.prefix(8)) + "…" : s
    }
}

struct AddRuleSheet: View {
    @Binding var isPresented: Bool
    @State var label = ""
    @State var type: Int = 0   // 0 = meeting, 1 = hourly
    @State var seconds = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("새 알림 규칙").font(.headline)

            TextField("이름 (예: 회의 10초 전)", text: $label)
                .textFieldStyle(.roundedBorder)

            Picker("종류", selection: $type) {
                Text("회의 N초 전").tag(0)
                Text("매 정시").tag(1)
            }
            .pickerStyle(.segmented)

            if type == 0 {
                HStack {
                    Text("몇 초 전:")
                    Stepper("\(seconds)초", value: $seconds, in: 3...300, step: 1)
                }
            }

            HStack {
                Spacer()
                Button("취소") { isPresented = false }
                Button("추가") {
                    let ruleType: AlarmType = type == 0 ? .calendarMeeting(secondsBefore: seconds) : .hourly
                    let name = label.isEmpty ? (type == 0 ? "회의 \(seconds)초 전" : "매 정시") : label
                    AlarmManager.shared.addRule(AlarmRule(type: ruleType, label: name, isEnabled: true))
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 300)
    }
}

// MARK: - Sounds Tab

struct SoundsView: View {
    @StateObject var audio = AudioManager.shared
    @State var youtubeURL = ""
    @State var soundName = ""
    @State var statusMessage = ""
    @State var statusIsError = false

    var body: some View {
        VStack(spacing: 0) {
            // Download section
            VStack(alignment: .leading, spacing: 8) {
                Text("YouTube에서 음원 추가")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)

                TextField("YouTube URL (예: https://youtu.be/...)", text: $youtubeURL)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))

                TextField("음원 이름 (선택)", text: $soundName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))

                Button(action: startDownload) {
                    if audio.isDownloading {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.mini)
                            Text(audio.downloadProgress.isEmpty ? "다운로드 중..." : audio.downloadProgress)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    } else {
                        Text("⬇ 다운로드")
                    }
                }
                .disabled(audio.isDownloading || youtubeURL.isEmpty)
                .frame(maxWidth: .infinity)

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.system(size: 10))
                        .foregroundColor(statusIsError ? .red : .green)
                }
            }
            .padding(12)

            Divider()

            // Sound list
            if audio.downloadedSounds.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "music.note.list")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("다운로드된 음원 없음")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(audio.downloadedSounds) { sound in
                        HStack {
                            Image(systemName: audio.selectedSoundName == sound.name ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(audio.selectedSoundName == sound.name ? .yellow : .secondary)
                                .onTapGesture { audio.selectSound(sound.name) }

                            Text(sound.displayName)
                                .font(.system(size: 12))
                                .lineLimit(1)

                            Spacer()

                            Button("▶") { audio.previewSound(name: sound.name) }
                                .buttonStyle(.plain)
                                .foregroundColor(.secondary)
                                .font(.system(size: 11))

                            Button(action: { audio.deleteSound(sound.name) }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red.opacity(0.7))
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    func startDownload() {
        statusMessage = ""
        audio.downloadFromYouTube(url: youtubeURL, customName: soundName) { success, message in
            statusMessage = message
            statusIsError = !success
            if success {
                youtubeURL = ""
                soundName = ""
            }
        }
    }
}
