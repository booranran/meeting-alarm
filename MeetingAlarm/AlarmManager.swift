import Foundation
import EventKit
import Combine
import SwiftUI

class AlarmManager: ObservableObject {
    static var shared = AlarmManager()

    @Published var alarmRules: [AlarmRule] = []
    @Published var nextMeeting: EKEvent?
    @Published var calendarAccessGranted = false

    var onAlarmFired: ((String) -> Void)?

    private let eventStore = EKEventStore()
    private var timer: Timer?
    private let defaults = UserDefaults.standard

    init() {
        loadRules()
        requestCalendarAccess()
        startTicking()
    }

    // MARK: - Calendar Access

    func requestCalendarAccess() {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.calendarAccessGranted = granted
                    if granted { self?.fetchUpcomingMeetings() }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.calendarAccessGranted = granted
                    if granted { self?.fetchUpcomingMeetings() }
                }
            }
        }
    }

    func fetchUpcomingMeetings() {
        let now = Date()
        let future = Calendar.current.date(byAdding: .hour, value: 24, to: now)!
        let predicate = eventStore.predicateForEvents(withStart: now, end: future, calendars: nil)
        let events = eventStore.events(matching: predicate)
            .filter { !$0.isAllDay && $0.startDate > now }
            .sorted { $0.startDate < $1.startDate }
        DispatchQueue.main.async {
            self.nextMeeting = events.first
        }
    }

    // MARK: - Tick

    func startTicking() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkAlarms()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func checkAlarms() {
        let now = Date()
        let cal = Calendar.current
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        let second = cal.component(.second, from: now)

        for rule in alarmRules where rule.isEnabled {
            switch rule.type {
            case .hourly:
                // fires at :00:00 of every hour
                if minute == 0 && second == 0 {
                    onAlarmFired?("🕐 \(hour):00")
                }

            case .calendarMeeting(let secondsBefore):
                guard calendarAccessGranted else { continue }
                fetchUpcomingMeetings()
                if let event = nextMeeting {
                    let diff = event.startDate.timeIntervalSince(now)
                    // fire within a 1-second window
                    if diff > 0 && diff <= Double(secondsBefore) + 0.5 && diff >= Double(secondsBefore) - 0.5 {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "HH:mm"
                        onAlarmFired?(event.title ?? "회의")
                    }
                }
            }
        }
    }

    // MARK: - Rule Management

    func addRule(_ rule: AlarmRule) {
        alarmRules.append(rule)
        saveRules()
    }

    func deleteRule(at offsets: IndexSet) {
        alarmRules.remove(atOffsets: offsets)
        saveRules()
    }

    func toggleRule(id: UUID) {
        if let idx = alarmRules.firstIndex(where: { $0.id == id }) {
            alarmRules[idx].isEnabled.toggle()
            saveRules()
        }
    }

    // MARK: - Persistence

    func saveRules() {
        if let data = try? JSONEncoder().encode(alarmRules) {
            defaults.set(data, forKey: "alarmRules")
        }
    }

    func loadRules() {
        if let data = defaults.data(forKey: "alarmRules"),
           let rules = try? JSONDecoder().decode([AlarmRule].self, from: data) {
            alarmRules = rules
        } else {
            // default: 10 seconds before meetings
            alarmRules = [
                AlarmRule(type: .calendarMeeting(secondsBefore: 10), label: "회의 10초 전", isEnabled: true),
                AlarmRule(type: .hourly, label: "매 정시", isEnabled: false)
            ]
        }
    }
}

// MARK: - Models

struct AlarmRule: Identifiable, Codable {
    var id = UUID()
    var type: AlarmType
    var label: String
    var isEnabled: Bool
    var soundFileName: String = ""
}

enum AlarmType: Codable {
    case calendarMeeting(secondsBefore: Int)
    case hourly
}
