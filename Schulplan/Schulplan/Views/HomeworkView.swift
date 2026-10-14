import SwiftUI

/// All homework, grouped by due date (soonest first) or by subject (A–Z).
/// Tasks whose lesson is over sit in a separate, faded "Alte Aufgaben" section.
struct HomeworkView: View {
    enum Sort: String, CaseIterable, Identifiable {
        case date, subject
        var id: String { rawValue }
        var label: String { self == .date ? "Datum" : "Fach" }
    }

    @Environment(Store.self) private var store
    @AppStorage("homeworkSort") private var sort: Sort = .date
    @AppStorage("showDone") private var showDone = false
    @AppStorage("showOld") private var showOld = false

    private struct Group: Identifiable {
        let id: String
        let title: String
        let items: [Homework]
        var old = false
    }

    /// Tasks whose lesson is still ahead (or unknown), filtered by the done toggle.
    private var current: [Homework] {
        store.homework.filter { !store.isOld($0) && (showDone || !store.isDone($0)) }
    }

    private var old: [Homework] {
        store.homework.filter(store.isOld).sorted { $0.due! > $1.due! }
    }

    // MARK: Grouping

    private var groups: [Group] {
        var result = sort == .date ? byDate : bySubject
        if showOld && !old.isEmpty {
            result.append(Group(id: "old", title: "Alte Aufgaben", items: old, old: true))
        }
        return result
    }

    private var byDate: [Group] {
        let dated = current.filter { $0.due != nil }
        let byDay = Dictionary(grouping: dated) { $0.due! }
        var result = byDay.keys.sorted().map { day in
            Group(id: SchoolCalendar.string(from: day), title: dayTitle(day),
                  items: byDay[day]!.sorted { ($0.course ?? $0.subject) < ($1.course ?? $1.subject) })
        }
        let undated = current.filter { $0.due == nil }
        if !undated.isEmpty {
            result.append(Group(id: "next", title: "Nächste Stunde",
                                items: undated.sorted { $0.given > $1.given }))
        }
        return result
    }

    private var bySubject: [Group] {
        Dictionary(grouping: current) { $0.subject }
            .map { subject, items in
                let course = items.compactMap(\.course).first
                return Group(id: subject, title: course.map { "\(subject) · \($0)" } ?? subject,
                             items: items.sorted { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) })
            }
            .sorted { $0.id.localizedCompare($1.id) == .orderedAscending }
    }

    private func dayTitle(_ day: Date) -> String {
        let cal = SchoolCalendar.calendar
        let rel = cal.isDateInToday(day) ? "Heute · " : cal.isDateInTomorrow(day) ? "Morgen · " : ""
        return rel + day.formatted("EEEEdMMM")
    }

    private func dueLabel(_ hw: Homework) -> String {
        guard let d = hw.due else { return "zur nächsten Stunde" }
        let cal = SchoolCalendar.calendar
        if cal.isDateInToday(d) { return "fällig heute" }
        if cal.isDateInTomorrow(d) { return "fällig morgen" }
        return "fällig \(d.formatted("EEEdMMM"))"
    }

    // MARK: Views

    var body: some View {
        let openCount = store.homework.filter { !store.isOld($0) && !store.isDone($0) }.count
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PageHeader(caption: "\(openCount) offen", title: "Aufgaben") { filterMenu }

                Picker("Sortieren nach", selection: $sort.animation(.snappy)) {
                    ForEach(Sort.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.top, 12)

                if groups.isEmpty {
                    Text(store.homework.isEmpty ? "Keine Hausaufgaben geladen." : "Alles erledigt.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .padding(.top, 28)
                }

                ForEach(groups) { group in
                    Caption(text: group.title)
                        .padding(.top, 28).padding(.bottom, 6)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(group.items) { hw in
                            row(hw, old: group.old)
                            if hw != group.items.last { Divider().padding(.leading, 30) }
                        }
                    }
                    .opacity(group.old ? 0.5 : 1)
                }

                if !showOld && !old.isEmpty {
                    Button {
                        withAnimation(.snappy) { showOld = true }
                    } label: {
                        Label("\(old.count) alte Aufgaben anzeigen", systemImage: "clock.arrow.circlepath")
                            .font(.subheadline)
                    }
                    .padding(.top, 28)
                }
                UpdatedFooter()
            }
            .padding(.horizontal, 16)
        }
        .refreshable { await store.refresh() }
    }

    private var filterMenu: some View {
        Menu {
            Toggle("Erledigte anzeigen", systemImage: "checkmark.circle", isOn: $showDone.animation(.snappy))
            Toggle("Alte Aufgaben anzeigen", systemImage: "clock.arrow.circlepath", isOn: $showOld.animation(.snappy))
        } label: {
            Image(systemName: showDone || showOld
                  ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .font(.title2)
        }
        .accessibilityLabel("Filter")
    }

    private func row(_ hw: Homework, old: Bool) -> some View {
        // Subject view: the heading names the subject, so the row says when it's due instead.
        let showSubject = sort == .date || old
        let due = old ? hw.due.map { "war fällig \($0.formatted("EEEdMMM"))" } ?? "" : dueLabel(hw)
        let soon = !old && hw.due != nil && sort == .subject
        return VStack(alignment: .leading, spacing: 4) {
            HomeworkLine(hw: hw, showSubject: showSubject)
            HStack(spacing: 0) {
                if sort == .subject || old {
                    Text(due).foregroundStyle(soon ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    Text(" · ").foregroundStyle(.tertiary)
                }
                Text("aufgegeben \(hw.given.formatted("EEEdMMM"))").foregroundStyle(.tertiary)
            }
            .font(.caption2)
            .padding(.leading, 30)
        }
        .padding(.vertical, 10)
    }
}
