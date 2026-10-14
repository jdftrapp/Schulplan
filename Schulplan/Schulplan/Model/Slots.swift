import Foundation

/// One line in a day view: a lesson (or double lesson) and what is special about it.
struct Slot: Identifiable, Hashable {
    enum Kind: Hashable { case regular, changed, cancelled, exam, otherExam, info }

    struct Entry: Hashable {
        var title: String
        var teacher: String
        var room: String
        var roomOld: String
        var kind: Kind
        var note: String?
        var course: String?
    }

    var first: Int
    var last: Int
    var entries: [Entry]

    var id: String { "\(first)-\(last)-\(entries.map(\.title).joined())" }
    var periodLabel: String { first == last ? "\(first)" : "\(first)–\(last)" }
    var startTime: String? { SchoolCalendar.start(of: String(first)) }
    var endTime: String? { SchoolCalendar.end(of: String(last)) }
}

extension Day {
    /// Lessons grouped by period, duplicates removed, double lessons merged.
    var slots: [Slot] {
        let byPeriod = Dictionary(grouping: lessons) { Int($0.period) ?? 0 }
        var result: [Slot] = []
        for period in byPeriod.keys.sorted() {
            let entries = Self.entries(for: byPeriod[period]!)
            if var last = result.last, last.last == period - 1, last.entries == entries {
                last.last = period
                result[result.count - 1] = last
            } else {
                result.append(Slot(first: period, last: period, entries: entries))
            }
        }
        return result
    }

    private static func entries(for lessons: [Lesson]) -> [Slot.Entry] {
        var seen = Set<String>()
        var out: [Slot.Entry] = []
        var otherExams = 0
        for l in lessons {
            guard seen.insert("\(l.subject)|\(l.teacher)|\(l.room)|\(l.status)").inserted else { continue }
            if l.isExam { otherExams += 1; continue }
            let kind: Slot.Kind
            var note: String?
            if !l.isCourse {
                kind = .info
            } else if l.isCancelled {
                kind = .cancelled; note = "Entfällt"
            } else if l.status == "new" && !l.subject.contains(" ") && l.has_comment {
                // Same heuristic as the widget: a new bare-code entry with a comment is an exam.
                kind = .exam; note = "Klausur"
            } else if l.status == "room_change" {
                kind = .changed; note = "Raumänderung"
            } else if l.status == "new" {
                kind = .changed; note = "Vertretung"
            } else {
                kind = .regular
            }
            out.append(.init(title: l.subject, teacher: l.teacher, room: l.room, roomOld: l.room_old,
                             kind: kind, note: note, course: l.isCourse ? l.subject : nil))
        }
        // Exams of other courses show up as many identical "Klausur" cells - fold them into one hint.
        if otherExams > 0 {
            out.append(.init(title: "Klausur", teacher: "", room: "", roomOld: "",
                             kind: .otherExam, note: otherExams > 1 ? "\(otherExams) Räume" : nil))
        }
        // Real lessons first, cancelled after them, hints last.
        let order: [Slot.Kind: Int] = [.exam: 0, .changed: 1, .regular: 1, .cancelled: 2, .info: 3, .otherExam: 4]
        return out.sorted { order[$0.kind]! < order[$1.kind]! }
    }
}
