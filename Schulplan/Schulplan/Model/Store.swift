import Foundation
import Observation

@Observable @MainActor
final class Store {
    private(set) var schedule: ScheduleFile?
    private(set) var homeworkFile: HomeworkFile?
    private(set) var isLoading = false
    private(set) var error: String?
    var isDemo: Bool { token.isEmpty }

    // MARK: Settings

    private let defaults = UserDefaults.standard

    var owner: String { didSet { defaults.set(owner, forKey: "owner") } }
    var repo: String { didSet { defaults.set(repo, forKey: "repo") } }
    var branch: String { didSet { defaults.set(branch, forKey: "branch") } }
    var token: String { didSet { Keychain.write(token, for: "github-token") } }
    /// normalized homework subject -> timetable course ("" = no course)
    var overrides: [String: String] { didSet { defaults.set(overrides, forKey: "overrides"); rebuild() } }
    private(set) var done: Set<String> { didSet { defaults.set(Array(done), forKey: "done") } }

    // MARK: Derived

    private(set) var days: [Day] = []
    private(set) var courses: [String: Int] = [:]
    private(set) var homework: [Homework] = []

    init() {
        owner = defaults.string(forKey: "owner") ?? "jdftrapp"
        repo = defaults.string(forKey: "repo") ?? "SchulmanagerWidgetV3"
        branch = defaults.string(forKey: "branch") ?? "main"
        token = Keychain.read("github-token")
        overrides = defaults.dictionary(forKey: "overrides") as? [String: String] ?? [:]
        done = Set(defaults.stringArray(forKey: "done") ?? [])
        loadLocal()
    }

    // MARK: Loading

    private func cacheURL(_ name: String) -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(name)
    }

    /// Cached files from the last successful fetch, or the bundled sample without a token.
    func loadLocal() {
        let decoder = JSONDecoder()
        if isDemo {
            schedule = Bundle.main.url(forResource: "sample-schedule", withExtension: "json")
                .flatMap { try? Data(contentsOf: $0) }.flatMap { try? decoder.decode(ScheduleFile.self, from: $0) }
            homeworkFile = Bundle.main.url(forResource: "sample-homework", withExtension: "json")
                .flatMap { try? Data(contentsOf: $0) }.flatMap { try? decoder.decode(HomeworkFile.self, from: $0) }
        } else {
            schedule = (try? Data(contentsOf: cacheURL("schedule.json"))).flatMap { try? decoder.decode(ScheduleFile.self, from: $0) }
            homeworkFile = (try? Data(contentsOf: cacheURL("homework.json"))).flatMap { try? decoder.decode(HomeworkFile.self, from: $0) }
        }
        rebuild()
    }

    func refresh() async {
        guard !isDemo else { loadLocal(); return }
        isLoading = true
        defer { isLoading = false }
        let source = GitHubSource(owner: owner, repo: repo, branch: branch, token: token)
        do {
            async let s = source.file("schedule.json")
            async let h = source.file("homework.json")
            let (sData, hData) = try await (s, h)
            let decoder = JSONDecoder()
            if let sData {
                schedule = try decoder.decode(ScheduleFile.self, from: sData)
                try? sData.write(to: cacheURL("schedule.json"))
            }
            if let hData {
                homeworkFile = try decoder.decode(HomeworkFile.self, from: hData)
                try? hData.write(to: cacheURL("homework.json"))
            }
            error = nil
            rebuild()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: Done state

    func isDone(_ hw: Homework) -> Bool { done.contains(hw.id) }

    func toggle(_ hw: Homework) {
        if done.contains(hw.id) { done.remove(hw.id) } else { done.insert(hw.id) }
    }

    // MARK: Derivation

    var updated: Date? {
        [schedule?.updated, homeworkFile?.updated].compactMap { SchoolCalendar.updatedDate($0) }.max()
    }

    /// Distinct homework subjects with the course they were matched to.
    var subjectMapping: [(subject: String, course: String?, isManual: Bool)] {
        let subjects = Set(homeworkFile?.days.flatMap { $0.entries.map(\.subject) } ?? [])
        return subjects.sorted().map { s in
            (s, course(for: s), overrides[SubjectMatcher.normalize(s)] != nil)
        }
    }

    func course(for subject: String) -> String? {
        SubjectMatcher.match(subject, courses: courses, overrides: overrides)
    }

    func setOverride(_ course: String?, for subject: String) {
        let key = SubjectMatcher.normalize(subject)
        if let course { overrides[key] = course } else { overrides.removeValue(forKey: key) }
    }

    /// The lesson a task was meant for is over: it moves to "Alte Aufgaben".
    func isOld(_ hw: Homework) -> Bool {
        guard let due = hw.due else { return false }
        return due < SchoolCalendar.startOfToday()
    }

    private func rebuild() {
        days = (schedule?.weeks.flatMap(\.days) ?? []).sorted { $0.date < $1.date }

        var counts: [String: Int] = [:]
        for d in days { for l in d.lessons where l.isCourse { counts[l.subject, default: 0] += 1 } }
        courses = counts

        homework = (homeworkFile?.days ?? []).flatMap { day -> [Homework] in
            guard let listed = SchoolCalendar.date(from: day.date) else { return [] }
            return day.entries.map { e in
                let course = course(for: e.subject)
                return Homework(
                    id: "\(day.date)|\(e.subject)|\(e.text.prefix(120))",
                    subject: e.subject, text: e.text, links: e.links,
                    given: listed, course: course,
                    // The page lists the day a task was given; it is due in the course's next lesson.
                    due: course.flatMap { nextLesson(of: $0, after: listed) }
                )
            }
        }
    }

    private func teaches(_ lesson: Lesson, _ course: String) -> Bool {
        lesson.subject == course
    }

    /// Next day the course actually takes place after `date`.
    func nextLesson(of course: String, after date: Date) -> Date? {
        let cal = SchoolCalendar.calendar
        guard let first = days.first?.day else { return nil }

        // Before the scraped range: project the weekly pattern backwards.
        if date < first {
            let weekdays = Set(days.filter { $0.lessons.contains { teaches($0, course) } }
                .compactMap { $0.day.map { cal.component(.weekday, from: $0) } })
            var d = date
            for _ in 0..<14 {
                d = cal.date(byAdding: .day, value: 1, to: d)!
                if d >= first { break }
                if weekdays.contains(cal.component(.weekday, from: d)) { return d }
            }
        }
        return days.first { day in
            guard let dd = day.day, dd > date else { return false }
            return day.lessons.contains { teaches($0, course) && !$0.isCancelled }
        }?.day
    }

    /// Today until its last lesson is over, then the next school day (tomorrow, or Monday on a Friday).
    func currentSchoolDay(now: Date = .now) -> Day? {
        Self.schoolDay(in: days, now: now)
    }

    /// Same rule as the widget's pickDay(), but only lessons that actually take place count.
    nonisolated static func schoolDay(in days: [Day], now: Date) -> Day? {
        let today = SchoolCalendar.string(from: now)
        for day in days where day.date >= today {
            guard let end = day.lessonsEnd else { continue }
            if day.date > today || now < end { return day }
        }
        return nil
    }

    var today: Day? {
        let key = SchoolCalendar.string(from: .now)
        return days.first { $0.date == key }
    }

    func homework(dueOn day: Date) -> [Homework] {
        homework.filter { $0.due == day }
    }
}
