import Foundation

// Port of the cell logic in widget/ScheduleLayout.js (resolve / kindOf / styleOf),
// so the Plan tab shows the same thing per period as the large home-screen widget.

struct WidgetCell: Equatable {
    enum Kind: Int { case cancelled = 0, regular, roomChange, info, new, exam }

    var subject: String
    var room: String
    var roomOld: String
    var kind: Kind
    /// Outlined: a change, or several different entries in one period.
    var marked: Bool

    /// Long words get a soft hyphen in the middle ("Herbst-ferien"), like wrapToBox().
    var hyphenatedSubject: String {
        subject.split(separator: " ").map { w in
            guard w.count >= 9 else { return String(w) }
            let mid = w.index(w.startIndex, offsetBy: (w.count + 1) / 2)
            return w[..<mid] + "\u{00AD}" + w[mid...]
        }.joined(separator: " ")
    }

    var isNamedExam: Bool { subject.range(of: "klausur|prüfung|klassenarbeit", options: [.regularExpression, .caseInsensitive]) != nil }

    /// Second line under the subject, as in drawEntry().
    var detail: String? {
        switch kind {
        case .cancelled: return "entfällt"
        case .exam where !isNamedExam: return room.isEmpty ? "Klausur" : "Klausur · \(room)"
        case .roomChange: return room.isEmpty ? nil : "→ \(room)"
        case .info: return nil
        default: return room.isEmpty ? nil : room
        }
    }

    static func kind(of l: Lesson) -> Kind {
        if l.status != "cancelled" {
            if l.isExam || l.subject.range(of: "prüfung|klassenarbeit", options: [.regularExpression, .caseInsensitive]) != nil { return .exam }
            // Exam heuristic: a new entry with only the bare subject ("E5"), a room and a comment.
            if l.status == "new" && !l.room.isEmpty && l.has_comment && !l.subject.trimmingCharacters(in: .whitespaces).contains(" ") { return .exam }
        }
        if l.status == "new" && l.room.isEmpty { return .info }
        switch l.status {
        case "cancelled": return .cancelled
        case "room_change": return .roomChange
        case "new": return .new
        default: return .regular
        }
    }

    /// One period can hold several entries: show the most important one.
    static func resolve(_ lessons: [Lesson]) -> WidgetCell? {
        var best: (Lesson, Kind)?
        for l in lessons {
            let k = kind(of: l)
            if best == nil || k.rawValue > best!.1.rawValue { best = (l, k) }
        }
        guard let (lesson, k) = best else { return nil }
        var room = lesson.room
        let same = lessons.filter { kind(of: $0) == k && $0.subject == lesson.subject }
        if same.contains(where: { $0.room != room }) { room = "" } // e.g. exams in several rooms
        let multi = Set(lessons.map { "\($0.subject)|\($0.status)" }).count > 1
        let marked = k == .new || k == .roomChange || (multi && k != .exam && k != .info)
        return WidgetCell(subject: lesson.subject, room: room, roomOld: lesson.room_old, kind: k, marked: marked)
    }
}

extension Day {
    /// period number -> resolved cell
    var widgetCells: [Int: WidgetCell] {
        Dictionary(grouping: lessons) { Int($0.period) ?? 0 }
            .compactMapValues(WidgetCell.resolve)
            .filter { $0.key > 0 }
    }

    var lastLessonPeriod: Int {
        widgetCells.filter { $0.value.kind != .info }.keys.max() ?? 0
    }
}
