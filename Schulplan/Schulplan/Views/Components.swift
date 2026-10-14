import SwiftUI

extension Slot.Kind {
    var tint: Color {
        switch self {
        case .regular, .info, .otherExam: .secondary
        case .changed: .accentColor
        case .cancelled: .red
        case .exam: .orange
        }
    }
}

/// Section heading in small caps, used everywhere instead of cards.
struct Caption: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(0.8)
            .foregroundStyle(.secondary)
    }
}

/// Course code shown as a quiet pill, e.g. "M L2".
struct CourseTag: View {
    let code: String
    var body: some View {
        Text(code)
            .font(.caption2.weight(.semibold).monospaced())
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(.quaternary, in: Capsule())
            .foregroundStyle(.secondary)
    }
}

// MARK: - Page header

private struct OpenSettingsKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var openSettings: () -> Void {
        get { self[OpenSettingsKey.self] }
        set { self[OpenSettingsKey.self] = newValue }
    }
}

/// Compact header used instead of a navigation bar: caption + gear, then the title.
struct PageHeader<Accessory: View>: View {
    @Environment(\.openSettings) private var openSettings
    let caption: String
    let title: String
    @ViewBuilder var accessory: () -> Accessory

    init(caption: String, title: String, @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }) {
        self.caption = caption
        self.title = title
        self.accessory = accessory
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Caption(text: caption)
                Spacer()
                Button(action: openSettings) {
                    Image(systemName: "gearshape").font(.body)
                }
                .foregroundStyle(.secondary)
                .accessibilityLabel("Einstellungen")
            }
            HStack(alignment: .lastTextBaseline) {
                Text(title)
                    .font(.system(size: 30, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 8)
                accessory()
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Day timeline

/// A day as a timeline: one card per lesson whose height grows with its length,
/// free periods as dashed cards, longer breaks as a small note in between.
struct DayTimeline: View {
    let day: Day
    /// Homework shown inside the card of the lesson it is due in.
    var homework: [Homework] = []
    /// Courses with homework due (shown as a dot when homework isn't listed inline).
    var dueCourses: Set<String> = []
    var cardFill: Color = Color(.secondarySystemBackground)

    private enum Item: Identifiable {
        case slot(Slot)
        case free(first: Int, last: Int)
        case pause(after: Int, minutes: Int)

        var id: String {
            switch self {
            case .slot(let s): "s\(s.id)"
            case .free(let f, let l): "f\(f)-\(l)"
            case .pause(let a, _): "p\(a)"
            }
        }
        var first: Int? {
            switch self {
            case .slot(let s): s.first
            case .free(let f, _): f
            case .pause: nil
            }
        }
        var last: Int? {
            switch self {
            case .slot(let s): s.last
            case .free(_, let l): l
            case .pause: nil
            }
        }
    }

    private var items: [Item] {
        var blocks: [Item] = []
        for slot in day.slots {
            if let prev = blocks.last?.last, slot.first > prev + 1 {
                blocks.append(.free(first: prev + 1, last: slot.first - 1))
            }
            blocks.append(.slot(slot))
        }
        // Breaks of 15 minutes or more between two blocks.
        var out: [Item] = []
        for block in blocks {
            if let prev = out.last?.last, let first = block.first,
               let end = SchoolCalendar.end(of: String(prev)).flatMap(Self.minutes),
               let start = SchoolCalendar.start(of: String(first)).flatMap(Self.minutes),
               start - end >= 15 {
                out.append(.pause(after: prev, minutes: start - end))
            }
            out.append(block)
        }
        return out
    }

    static func minutes(_ hm: String) -> Int? {
        let p = hm.split(separator: ":").compactMap { Int($0) }
        return p.count == 2 ? p[0] * 60 + p[1] : nil
    }

    var body: some View {
        VStack(spacing: 6) {
            ForEach(items) { item in
                switch item {
                case .slot(let slot): lesson(slot)
                case .free(let f, let l): free(f, l)
                case .pause(_, let m):
                    HStack(spacing: 6) {
                        Rectangle().fill(.quaternary).frame(height: 1)
                        Text("\(m) min Pause").font(.caption2).foregroundStyle(.tertiary).fixedSize()
                        Rectangle().fill(.quaternary).frame(height: 1)
                    }
                    .padding(.leading, 58)
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func height(_ first: Int, _ last: Int) -> CGFloat { CGFloat(last - first + 1) * 46 - 6 }

    private func times(_ first: Int, _ last: Int) -> some View {
        let start = SchoolCalendar.start(of: String(first)) ?? "\(first)."
        let end = SchoolCalendar.end(of: String(last)) ?? ""
        let length = (Self.minutes(end) ?? 0) - (Self.minutes(start) ?? 0)
        return VStack(alignment: .trailing, spacing: 1) {
            Text(start).font(.subheadline.weight(.semibold).monospacedDigit())
            Text(end).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            if length > 0 {
                Text("\(length) min").font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
        }
        .frame(width: 46, alignment: .trailing)
    }

    private func barColor(_ slot: Slot) -> Color {
        switch slot.entries.first?.kind ?? .regular {
        case .exam: .orange
        case .changed: .accentColor
        case .cancelled: .red.opacity(0.45)
        case .regular: .primary.opacity(0.22)
        case .info, .otherExam: .secondary.opacity(0.3)
        }
    }

    private func lesson(_ slot: Slot) -> some View {
        let dimmed = slot.entries.allSatisfy { $0.kind == .cancelled || $0.kind == .otherExam }
        return HStack(alignment: .top, spacing: 12) {
            times(slot.first, slot.last)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(slot.entries, id: \.self) { entry in
                    EntryView(entry: entry, hasDue: entry.course.map(dueCourses.contains) ?? false)
                    let own = homework.filter { $0.course != nil && $0.course == entry.course }
                    if !own.isEmpty && entry.kind != .otherExam {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(own) { HomeworkLine(hw: $0) }
                        }
                        .padding(.leading, 10)
                        .overlay(alignment: .leading) { Rectangle().fill(.tint).frame(width: 2) }
                    }
                }
            }
            .padding(.vertical, 10)
            .padding(.leading, 16)
            .padding(.trailing, 12)
            .frame(maxWidth: .infinity, minHeight: height(slot.first, slot.last), alignment: .topLeading)
            .background(cardFill)
            .overlay(alignment: .leading) { Rectangle().fill(barColor(slot)).frame(width: 4) }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(dimmed ? 0.55 : 1)
        }
    }

    private func free(_ first: Int, _ last: Int) -> some View {
        let n = last - first + 1
        return HStack(alignment: .top, spacing: 12) {
            times(first, last).opacity(0.6)
            Text(n == 1 ? "Freistunde" : "\(n) Freistunden")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.vertical, 10)
                .padding(.leading, 16)
                .frame(maxWidth: .infinity, minHeight: height(first, last), alignment: .topLeading)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.tertiary, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
        }
    }
}

private struct EntryView: View {
    let entry: Slot.Entry
    var hasDue = false

    var body: some View {
        let quiet = entry.kind == .otherExam || entry.kind == .info
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(entry.title)
                    .font(quiet ? .subheadline : .body.weight(.semibold))
                    .foregroundStyle(quiet ? .secondary : .primary)
                    .strikethrough(entry.kind == .cancelled, color: .red)
                if hasDue {
                    Circle().fill(.tint).frame(width: 6, height: 6)
                }
                Spacer(minLength: 8)
                if let note = entry.note {
                    Text(note)
                        .font(.caption.weight(entry.kind == .exam ? .bold : .medium))
                        .foregroundStyle(entry.kind.tint)
                }
            }
            if !quiet && entry.kind != .cancelled {
                HStack(spacing: 6) {
                    if !entry.roomOld.isEmpty {
                        Text(entry.roomOld).strikethrough()
                        Image(systemName: "arrow.right").font(.caption2)
                    }
                    Text(entry.room)
                        .foregroundStyle(entry.roomOld.isEmpty ? Color.secondary : Color.accentColor)
                    if !entry.teacher.isEmpty {
                        Text("·")
                        Text(entry.teacher)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
    }
}

/// Homework text with a done toggle. Used inline under lessons and in the homework list.
struct HomeworkLine: View {
    @Environment(Store.self) private var store
    let hw: Homework
    var showSubject = false

    var body: some View {
        let isDone = store.isDone(hw)
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Button {
                withAnimation(.snappy) { store.toggle(hw) }
            } label: {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(isDone ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isDone ? "Als offen markieren" : "Als erledigt markieren")

            VStack(alignment: .leading, spacing: 4) {
                if showSubject {
                    HStack(spacing: 6) {
                        Text(hw.subject).font(.subheadline.weight(.semibold))
                        if let c = hw.course { CourseTag(code: c) }
                    }
                }
                Text(hw.text.isEmpty ? "Keine Beschreibung" : hw.text)
                    .font(.subheadline)
                    .foregroundStyle(isDone ? .tertiary : .primary)
                    .strikethrough(isDone)
                    .textSelection(.enabled)
                ForEach(hw.links, id: \.self) { link in
                    if let url = URL(string: link) {
                        Link(destination: url) {
                            Label(url.host() ?? link, systemImage: "link")
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }
}

struct UpdatedFooter: View {
    @Environment(Store.self) private var store
    var body: some View {
        VStack(spacing: 4) {
            if store.isDemo {
                Text("Beispieldaten – Token in den Einstellungen eintragen")
            } else if let u = store.updated {
                // older than 20 h means the scraper hasn't run - same rule as the widget
                let stale = Date.now.timeIntervalSince(u) > 20 * 3600
                Text("Stand \(u.formatted("EEEdMMMHHmm"))" + (stale ? " · veraltet" : ""))
                    .foregroundStyle(stale ? Color.red : Color(.tertiaryLabel))
            }
            if let e = store.error {
                Text(e).foregroundStyle(.red)
            }
        }
        .font(.caption)
        .foregroundStyle(.tertiary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
