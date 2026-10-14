import SwiftUI

/// One school day as a timeline (the next one by default), with its homework inside each lesson.
/// A day switcher sits at the bottom, within thumb reach; swiping sideways works too.
struct OverviewView: View {
    @Environment(Store.self) private var store
    /// Date chosen with the switcher; nil = next school day.
    @State private var chosen: String?

    /// Days that have anything in the timetable (holiday weeks are skipped).
    private var schoolDays: [Day] { store.days.filter { !$0.lessons.isEmpty } }

    private var defaultDay: Day? { store.currentSchoolDay() ?? schoolDays.last }

    private var current: Day? {
        if let chosen, let d = schoolDays.first(where: { $0.date == chosen }) { return d }
        return defaultDay
    }

    var body: some View {
        // Re-evaluated every minute, so the page moves on by itself once the last lesson ends.
        TimelineView(.everyMinute) { _ in page }
    }

    @ViewBuilder
    private var page: some View {
        let day = current
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let day, let date = day.day {
                    content(day: day, date: date)
                } else {
                    PageHeader(caption: "Nächster Schultag", title: "Frei")
                    Text("Im geladenen Stundenplan stehen keine weiteren Stunden.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                UpdatedFooter()
            }
            .padding(.horizontal, 16)
            .id(day?.date)
            .transition(.opacity)
        }
        .refreshable { await store.refresh() }
        .gesture(DragGesture(minimumDistance: 40).onEnded { v in
            guard abs(v.translation.width) > abs(v.translation.height) * 1.5 else { return }
            step(v.translation.width < 0 ? 1 : -1)
        })
        .safeAreaInset(edge: .bottom) {
            if let day { switcher(day) }
        }
        .sensoryFeedback(.selection, trigger: day?.date)
    }

    private func step(_ by: Int) {
        guard let cur = current, let i = schoolDays.firstIndex(where: { $0.date == cur.date }),
              schoolDays.indices.contains(i + by) else { return }
        withAnimation(.snappy) { chosen = schoolDays[i + by].date }
    }

    /// ‹  Do 15.10. · Morgen  ›   - tap the middle to jump back to the next school day.
    private func switcher(_ day: Day) -> some View {
        let i = schoolDays.firstIndex { $0.date == day.date } ?? 0
        let isDefault = day.date == defaultDay?.date
        return HStack(spacing: 0) {
            Button { step(-1) } label: {
                Image(systemName: "chevron.left").frame(width: 48, height: 44)
            }
            .disabled(i == 0)
            .accessibilityLabel("Vorheriger Tag")

            Button {
                withAnimation(.snappy) { chosen = nil }
            } label: {
                HStack(spacing: 6) {
                    Text(day.day?.formatted("EEEddMM") ?? day.weekday)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.primary)
                    Text(relative(day))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if !isDefault {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tint)
                    }
                }
                .frame(minWidth: 150, minHeight: 44)
            }
            .disabled(isDefault)
            .accessibilityHint(isDefault ? "" : "Zurück zum nächsten Schultag")

            Button { step(1) } label: {
                Image(systemName: "chevron.right").frame(width: 48, height: 44)
            }
            .disabled(i >= schoolDays.count - 1)
            .accessibilityLabel("Nächster Tag")
        }
        .font(.body.weight(.semibold))
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.quaternary, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 2)
        .padding(.bottom, 8)
    }

    /// "Heute", "Morgen", "Gestern", otherwise "in 5 Tagen" / "vor 2 Tagen".
    private func relative(_ day: Day) -> String {
        guard let d = day.day else { return "" }
        let cal = SchoolCalendar.calendar
        if cal.isDateInToday(d) { return "Heute" }
        if cal.isDateInTomorrow(d) { return "Morgen" }
        if cal.isDateInYesterday(d) { return "Gestern" }
        let n = cal.dateComponents([.day], from: SchoolCalendar.startOfToday(), to: d).day ?? 0
        return n > 0 ? "in \(n) Tagen" : "vor \(-n) Tagen"
    }

    @ViewBuilder
    private func content(day: Day, date: Date) -> some View {
        let due = store.homework(dueOn: date)
        let slots = day.slots
        let courses = Set(slots.flatMap { $0.entries.compactMap(\.course) })
        let unplaced = due.filter { $0.course.map { !courses.contains($0) } ?? true }
        let open = due.filter { !store.isDone($0) }.count
        let rel = relative(day)
        let caption = day.date == defaultDay?.date && !["Heute", "Morgen"].contains(rel) ? "Nächster Schultag" : rel

        PageHeader(caption: caption, title: date.formatted("EEEEdMMMM"))

        summary(slots: slots, open: open, total: due.count)
            .padding(.top, 10)

        DayTimeline(day: day, homework: due)
            .padding(.top, 18)

        if !unplaced.isEmpty {
            Caption(text: "Außerdem fällig").padding(.top, 24).padding(.bottom, 8)
            VStack(alignment: .leading, spacing: 14) {
                ForEach(unplaced) { HomeworkLine(hw: $0, showSubject: true) }
            }
        }
    }

    /// Two small facts under the title: school hours and homework status.
    private func summary(slots: [Slot], open: Int, total: Int) -> some View {
        let taught = slots.filter { s in s.entries.contains { [.regular, .changed, .exam].contains($0.kind) } }
        let start = taught.first.flatMap { SchoolCalendar.start(of: String($0.first)) }
        let end = taught.last.flatMap { SchoolCalendar.end(of: String($0.last)) }
        let periods = taught.reduce(0) { $0 + $1.last - $1.first + 1 }

        return HStack(spacing: 8) {
            if let start, let end {
                Label("\(start)–\(end) · \(periods) Std.", systemImage: "clock")
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Group {
                if total == 0 {
                    Text("Keine Hausaufgaben").foregroundStyle(.secondary)
                } else if open == 0 {
                    Label("Alles erledigt", systemImage: "checkmark").foregroundStyle(.secondary)
                } else {
                    Label("\(open)/\(total) offen", systemImage: "book.closed").foregroundStyle(.tint)
                }
            }
        }
        .font(.subheadline)
        .labelStyle(.titleAndIcon)
    }
}
