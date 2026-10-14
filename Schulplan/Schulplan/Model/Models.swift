import Foundation

// Mirrors the JSON written by scraper.py in SchulmanagerWidgetV3.

struct ScheduleFile: Codable {
    var updated: String?
    var weeks: [Week]
}

struct Week: Codable {
    var week: Int?
    var days: [Day]
}

struct Day: Codable, Identifiable {
    var weekday: String
    var date: String
    var lessons: [Lesson]

    var id: String { date }
    var day: Date? { SchoolCalendar.date(from: date) }

    /// When the last lesson that takes place ends; nil if nothing takes place.
    var lessonsEnd: Date? {
        let last = lessons.filter { $0.isCourse && !$0.isCancelled }.compactMap { Int($0.period) }.max()
        guard let last, let day, let end = SchoolCalendar.end(of: String(last)) else { return nil }
        let hm = end.split(separator: ":").compactMap { Int($0) }
        return SchoolCalendar.calendar.date(bySettingHour: hm[0], minute: hm[1], second: 0, of: day)
    }
}

struct Lesson: Codable, Hashable {
    var period: String
    var subject: String
    var teacher: String
    var room: String
    var room_old: String
    var status: String
    var has_comment: Bool
    var start: String?
    var end: String?

    var isCancelled: Bool { status == "cancelled" }
    var isChanged: Bool { status == "new" || status == "room_change" }
    var isExam: Bool { subject.localizedCaseInsensitiveContains("klausur") }
    /// "KU L1" -> "KU", "E5 G1" -> "E5"
    var code: String { subject.split(separator: " ").first.map(String.init) ?? subject }
    /// Real course entries look like "D G2"; bare codes and free text are special entries.
    var isCourse: Bool { SubjectMatcher.looksLikeCode(subject) }
}

struct HomeworkFile: Codable {
    var updated: String?
    var days: [HomeworkDay]
}

struct HomeworkDay: Codable {
    var date: String
    var weekday: String
    var entries: [HomeworkEntry]
}

struct HomeworkEntry: Codable, Hashable {
    var subject: String
    var text: String
    var links: [String]
}

/// A homework entry with everything the UI needs already resolved.
struct Homework: Identifiable, Hashable {
    let id: String
    let subject: String
    let text: String
    let links: [String]
    /// Day the task was given (the date on the homework page).
    let given: Date
    /// Timetable course it belongs to, e.g. "M L2".
    let course: String?
    /// When it has to be done; nil if the timetable doesn't reach that far.
    let due: Date?
}

enum SchoolCalendar {
    static let timeZone = TimeZone(identifier: "Europe/Berlin")!

    static var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = timeZone
        c.locale = Locale(identifier: "de_DE")
        c.firstWeekday = 2
        return c
    }()

    private static let isoDay: DateFormatter = {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func date(from string: String) -> Date? { isoDay.date(from: string) }
    static func string(from date: Date) -> String { isoDay.string(from: date) }
    static func startOfToday(_ now: Date = .now) -> Date { calendar.startOfDay(for: now) }

    /// Bell schedule, same as PERIOD_TIMES in widget/ScheduleLayout.js.
    static let periodStarts = ["07:50", "08:35", "09:40", "10:30", "11:35", "12:20",
                               "13:30", "14:20", "15:10", "15:55", "16:40", "17:25"]
    static let lessonMinutes = 45

    static func start(of period: String) -> String? {
        guard let n = Int(period), n >= 1, n <= periodStarts.count else { return nil }
        return periodStarts[n - 1]
    }

    static func end(of period: String) -> String? {
        guard let s = start(of: period) else { return nil }
        let parts = s.split(separator: ":").compactMap { Int($0) }
        let total = parts[0] * 60 + parts[1] + lessonMinutes
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    static func updatedDate(_ s: String?) -> Date? {
        guard let s else { return nil }
        return ISO8601DateFormatter().date(from: s)
    }
}

extension Date {
    func formatted(_ pattern: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.timeZone = SchoolCalendar.timeZone
        f.setLocalizedDateFormatFromTemplate(pattern)
        return f.string(from: self)
    }
}
