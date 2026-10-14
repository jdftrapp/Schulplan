import SwiftUI

/// Week timetable: one column per day, one row per period (same cell rules as the
/// home-screen widget), drawn in the app's own style. Tap a day for its timeline,
/// tap a lesson with a dot to see its homework.
struct WeekView: View {
    @Environment(Store.self) private var store
    @State private var weekIndex: Int?
    @State private var selected: String?
    @State private var tasks: TaskRef?

    private var weeks: [Week] { store.schedule?.weeks ?? [] }
    private var today: String { SchoolCalendar.string(from: .now) }

    /// The week containing today; after the last school day the next week (pickWeek).
    private var defaultWeek: Int {
        if let i = weeks.firstIndex(where: { $0.days.contains { $0.date == today } }) { return i }
        if let i = weeks.firstIndex(where: { ($0.days.last?.date ?? "") >= today }) { return i }
        return max(weeks.count - 1, 0)
    }

    var body: some View {
        let index = min(weekIndex ?? defaultWeek, max(weeks.count - 1, 0))
        ScrollView {
            // The weekday row stays pinned while the periods scroll underneath, like Calendar.
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                if weeks.indices.contains(index) {
                    let week = weeks[index]
                    let sel = selectedID(in: week)
                    header(week, index: index)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                    Section {
                        WeekGrid(days: week.days, selected: sel,
                                 onSelect: select, onTasks: { tasks = $0 })
                            .padding(.horizontal, 12)
                        if let day = week.days.first(where: { $0.date == sel }) {
                            dayList(day).padding(.horizontal, 16)
                        }
                    } header: {
                        WeekdayRow(days: week.days, selected: sel, onSelect: select)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemBackground))
                            .overlay(alignment: .bottom) { Divider() }
                    }
                }
            }
        }
        // Content stops at the status bar, so nothing peeks out above the pinned weekday row;
        // at the bottom it still scrolls under the floating tab bar.
        .mask(Rectangle().ignoresSafeArea(edges: .bottom))
        .refreshable { await store.refresh() }
        .gesture(DragGesture(minimumDistance: 40).onEnded { v in
            guard abs(v.translation.width) > abs(v.translation.height) * 1.5 else { return }
            jump(to: index + (v.translation.width < 0 ? 1 : -1))
        })
        .sheet(item: $tasks) { TaskSheet(ref: $0) }
        .sensoryFeedback(.selection, trigger: selected)
    }

    private func select(_ id: String) {
        withAnimation(.snappy) { selected = id }
    }

    private func selectedID(in week: Week) -> String {
        if let s = selected, week.days.contains(where: { $0.date == s }) { return s }
        return week.days.first { $0.date >= today && $0.lastLessonPeriod > 0 }?.date
            ?? week.days.first { $0.lastLessonPeriod > 0 }?.date
            ?? week.days.first?.date ?? ""
    }

    private func jump(to index: Int) {
        guard weeks.indices.contains(index) else { return }
        withAnimation(.snappy) { weekIndex = index; selected = nil }
    }

    private func header(_ week: Week, index: Int) -> some View {
        let atToday = index == defaultWeek && (selected == nil || selected == today)
        return PageHeader(caption: week.week.map { "KW \($0)" } ?? "Woche", title: "Stundenplan") {
            HStack(spacing: 18) {
                // Like Calendar's "Today" button: back to the current week and day.
                if !atToday {
                    Button("Heute") {
                        withAnimation(.snappy) { weekIndex = nil; selected = nil }
                    }
                    .font(.subheadline.weight(.medium))
                    .transition(.opacity)
                }
                Button { jump(to: index - 1) } label: { Image(systemName: "chevron.left") }
                    .disabled(index == 0)
                    .accessibilityLabel("Vorherige Woche")
                Button { jump(to: index + 1) } label: { Image(systemName: "chevron.right") }
                    .disabled(index >= weeks.count - 1)
                    .accessibilityLabel("Nächste Woche")
            }
            .font(.body.weight(.semibold))
        }
    }

    @ViewBuilder
    private func dayList(_ day: Day) -> some View {
        let due = day.day.map { store.homework(dueOn: $0) } ?? []
        Caption(text: day.day?.formatted("EEEEdMMMM") ?? day.weekday)
            .padding(.top, 24).padding(.bottom, 10)
        if day.slots.isEmpty {
            Text("Keine Stunden")
                .font(.subheadline).foregroundStyle(.secondary)
        } else {
            DayTimeline(day: day, homework: due)
        }
        UpdatedFooter()
    }
}

// MARK: - Layout constants

private enum GridMetrics {
    static let periodW: CGFloat = 30
    static let rowH: CGFloat = 52
    static let gap: CGFloat = 2
}

/// Lesson + day whose homework a sheet shows.
struct TaskRef: Identifiable {
    let course: String
    let date: Date
    var id: String { "\(course)|\(date)" }
}

// MARK: - Weekday row

/// Like the Calendar app: today's number in the accent colour, the selected day's in a filled circle.
private struct WeekdayRow: View {
    let days: [Day]
    let selected: String
    let onSelect: (String) -> Void

    var body: some View {
        let today = SchoolCalendar.string(from: .now)
        HStack(spacing: 0) {
            Color.clear.frame(width: GridMetrics.periodW, height: 1)
            ForEach(days) { day in
                let isToday = day.date == today
                let isSelected = day.date == selected
                Button { onSelect(day.date) } label: {
                    VStack(spacing: 2) {
                        Text(String(day.weekday.prefix(2)).uppercased())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(isToday ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                        Text(day.day.map { "\(SchoolCalendar.calendar.component(.day, from: $0))" } ?? "")
                            .font(.title3.weight(isSelected || isToday ? .semibold : .regular))
                            .monospacedDigit()
                            .foregroundStyle(isSelected ? (isToday ? AnyShapeStyle(.white) : AnyShapeStyle(.background))
                                             : isToday ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                            .frame(width: 36, height: 36)
                            .background {
                                if isSelected {
                                    Circle().fill(isToday ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                                }
                            }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                    .opacity(day.date < today && !isSelected ? 0.5 : 1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel((day.day?.formatted("EEEEdMMMM") ?? day.weekday) + (isToday ? ", heute" : ""))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

// MARK: - Grid

private struct WeekGrid: View {
    @Environment(Store.self) private var store
    let days: [Day]
    let selected: String
    let onSelect: (String) -> Void
    let onTasks: (TaskRef) -> Void

    var body: some View {
        let cells = days.map(\.widgetCells)
        // minRows 6, maxRows 12, like the widget
        let maxP = min(max(days.map(\.lastLessonPeriod).max() ?? 0, 6), 12)

        HStack(alignment: .top, spacing: 0) {
            periodColumn(maxP)
            ForEach(Array(days.enumerated()), id: \.element.id) { i, day in
                dayColumn(day, cells: cells[i], maxP: maxP)
            }
        }
    }

    private func periodColumn(_ maxP: Int) -> some View {
        VStack(spacing: 0) {
            ForEach(1...maxP, id: \.self) { p in
                VStack(spacing: 1) {
                    Text("\(p)").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    if let start = SchoolCalendar.start(of: String(p)), let end = SchoolCalendar.end(of: String(p)) {
                        Text(start)
                        Text(end)
                    }
                }
                .font(.system(size: 9.5).monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: GridMetrics.periodW, height: GridMetrics.rowH)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func dayColumn(_ day: Day, cells: [Int: WidgetCell], maxP: Int) -> some View {
        let today = SchoolCalendar.string(from: .now)
        let isSelected = day.date == selected
        let isPast = day.date < today
        let due = day.day.map { store.homework(dueOn: $0) } ?? []
        let lessonPeriods = cells.filter { $0.value.kind != .info }.keys
        let firstP = lessonPeriods.min() ?? 0, lastP = lessonPeriods.max() ?? 0

        return VStack(spacing: 0) {
            ForEach(segments(cells, maxP: maxP), id: \.first) { seg in
                Group {
                    if let cell = seg.cell {
                        let tasks = due.filter { $0.course == cell.subject }
                        let open = tasks.contains { !store.isDone($0) }
                        let label = accessibility(cell, seg, tasks: tasks.count)
                        if tasks.isEmpty {
                            CellView(cell: cell)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(label)
                        } else {
                            Button {
                                onSelect(day.date)
                                if let d = day.day { onTasks(TaskRef(course: cell.subject, date: d)) }
                            } label: {
                                CellView(cell: cell, taskDot: open ? .open : .done)
                            }
                            .buttonStyle(CellButtonStyle())
                            .accessibilityLabel(label)
                            .accessibilityHint("Zeigt die Hausaufgaben")
                        }
                    } else if seg.first > firstP && seg.last < lastP {
                        // a gap between lessons: free period
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color(.separator), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .overlay { Text("frei").font(.caption2).foregroundStyle(.tertiary) }
                            .accessibilityLabel("\(seg.first). Stunde frei")
                    } else {
                        Color.clear.accessibilityHidden(true)
                    }
                }
                .padding(GridMetrics.gap)
                .frame(height: CGFloat(seg.last - seg.first + 1) * GridMetrics.rowH)
            }
        }
        .opacity(isPast && !isSelected ? 0.5 : 1)
        .frame(maxWidth: .infinity)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
                    .padding(.horizontal, -1)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onSelect(day.date) }
    }

    private func accessibility(_ cell: WidgetCell, _ seg: Segment, tasks: Int) -> String {
        var parts = [cell.subject]
        if let d = cell.detail { parts.append(d) }
        parts.append(seg.first == seg.last ? "\(seg.first). Stunde" : "\(seg.first). bis \(seg.last). Stunde")
        if tasks > 0 { parts.append(tasks == 1 ? "1 Aufgabe" : "\(tasks) Aufgaben") }
        return parts.joined(separator: ", ")
    }

    fileprivate struct Segment { let first: Int; let last: Int; let cell: WidgetCell? }

    /// Identical neighbouring periods become one cell (mergeDoubles).
    private func segments(_ cells: [Int: WidgetCell], maxP: Int) -> [Segment] {
        var out: [Segment] = []
        var p = 1
        while p <= maxP {
            let cell = cells[p]
            var q = p
            while q + 1 <= maxP && cells[q + 1] == cell { q += 1 }
            out.append(Segment(first: p, last: q, cell: cell))
            p = q + 1
        }
        return out
    }
}

private struct CellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// One lesson cell, styled like a Calendar event: tinted fill with a solid bar
/// for anything special, a plain grey card for normal lessons.
private struct CellView: View {
    enum Dot { case open, done }
    @Environment(\.colorScheme) private var scheme
    let cell: WidgetCell
    var taskDot: Dot?

    /// Status colour; nil for a normal lesson.
    private var tint: Color? {
        switch cell.kind {
        case .exam: .orange
        case .new, .roomChange: .accentColor
        case .cancelled: .red
        case .regular, .info: nil
        }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if let tint, cell.kind != .cancelled {
                    // Over black a weak tint turns muddy; a stronger one keeps the hue.
                    tint.opacity(scheme == .dark ? 0.28 : 0.16)
                } else if cell.kind == .info {
                    Color(.tertiarySystemFill)
                } else {
                    Color(.secondarySystemBackground)
                }
            }
            .overlay(alignment: .leading) {
                if let tint { tint.opacity(cell.kind == .cancelled ? 0.5 : 1).frame(width: 3) }
            }
            .clipShape(shape)
            .overlay(alignment: .topTrailing) {
                if let taskDot {
                    Circle()
                        .fill(taskDot == .open ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear))
                        .strokeBorder(.tint, lineWidth: taskDot == .open ? 0 : 1.2)
                        .frame(width: 7, height: 7)
                        .padding(4)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if cell.kind == .info {
            Text(cell.hyphenatedSubject)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .padding(4)
        } else {
            VStack(spacing: 1) {
                Text(cell.subject)
                    .font(.footnote.weight(.semibold))
                    .strikethrough(cell.kind == .cancelled)
                    .foregroundStyle(cell.kind == .cancelled ? .secondary : .primary)
                if let d = cell.detail {
                    Text(d)
                        .font(.caption2.weight(tint == nil ? .regular : .medium))
                        .foregroundStyle(tint ?? .secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.leading, tint == nil ? 3 : 6).padding(.trailing, 3)
        }
    }
}

// MARK: - Task sheet

/// Homework of one lesson, opened by tapping a cell with a dot.
private struct TaskSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let ref: TaskRef

    var body: some View {
        let items = store.homework(dueOn: ref.date).filter { $0.course == ref.course }
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Caption(text: "Fällig " + ref.date.formatted("EEEEdMMM"))
                    HStack(spacing: 8) {
                        Text(items.first?.subject ?? ref.course).font(.title2.weight(.bold))
                        CourseTag(code: ref.course)
                    }
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Schließen")
            }
            VStack(alignment: .leading, spacing: 16) {
                ForEach(items) { hw in
                    VStack(alignment: .leading, spacing: 4) {
                        HomeworkLine(hw: hw)
                        Text("aufgegeben \(hw.given.formatted("EEEEdMMM"))")
                            .font(.caption2).foregroundStyle(.tertiary)
                            .padding(.leading, 30)
                    }
                }
            }
            .padding(.top, 20)
            Spacer(minLength: 0)
        }
        .padding(20)
        .presentationDetents([.fraction(0.35), .large])
        .presentationDragIndicator(.visible)
    }
}
