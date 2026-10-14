import XCTest
@testable import Schulplan

final class SchoolDayTests: XCTestCase {
    private func lesson(_ period: Int, _ subject: String, _ status: String = "regular") -> Lesson {
        Lesson(period: String(period), subject: subject, teacher: "", room: "", room_old: "",
               status: status, has_comment: false)
    }

    // Wed: last real lesson is period 6 (ends 13:05); period 7 is cancelled.
    private lazy var days: [Day] = [
        Day(weekday: "Mittwoch", date: "2026-10-14",
            lessons: [lesson(5, "M L2"), lesson(6, "M L2"), lesson(7, "D G2", "cancelled")]),
        Day(weekday: "Donnerstag", date: "2026-10-15", lessons: [lesson(1, "E5 G1")]),
    ]

    private func at(_ s: String) -> Date {
        let f = DateFormatter()
        f.timeZone = SchoolCalendar.timeZone
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: s)!
    }

    func testTodayBeforeAndDuringLessons() {
        XCTAssertEqual(Store.schoolDay(in: days, now: at("2026-10-14 06:30"))?.date, "2026-10-14")
        XCTAssertEqual(Store.schoolDay(in: days, now: at("2026-10-14 13:04"))?.date, "2026-10-14")
    }

    func testNextDayOnceLastLessonEnded() {
        // The cancelled period 7 does not keep today alive.
        XCTAssertEqual(Store.schoolDay(in: days, now: at("2026-10-14 13:05"))?.date, "2026-10-15")
        XCTAssertEqual(Store.schoolDay(in: days, now: at("2026-10-14 20:00"))?.date, "2026-10-15")
    }

    func testNothingLeft() {
        XCTAssertNil(Store.schoolDay(in: days, now: at("2026-10-15 09:00")))
    }
}
