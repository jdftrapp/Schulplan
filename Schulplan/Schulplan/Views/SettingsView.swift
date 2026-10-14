import SwiftUI

struct SettingsView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section {
                    TextField("Besitzer", text: $store.owner)
                    TextField("Repository", text: $store.repo)
                    TextField("Branch", text: $store.branch)
                    SecureField("GitHub-Token", text: $store.token)
                } header: {
                    Text("Datenquelle")
                } footer: {
                    Text("Fine-grained Token mit Lesezugriff (Contents: Read-only) nur auf dieses Repository. Er wird im Schlüsselbund gespeichert. Ohne Token zeigt die App Beispieldaten.")
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                Section {
                    if store.subjectMapping.isEmpty {
                        Text("Noch keine Hausaufgaben geladen.").foregroundStyle(.secondary)
                    }
                    ForEach(store.subjectMapping, id: \.subject) { row in
                        Picker(selection: Binding(
                            get: { row.isManual ? (row.course ?? "") : "auto" },
                            set: { store.setOverride($0 == "auto" ? nil : $0, for: row.subject) }
                        )) {
                            Text("Automatisch (\(store.autoCourse(for: row.subject) ?? "–"))").tag("auto")
                            Text("Kein Kurs").tag("")
                            ForEach(store.courses.keys.sorted(), id: \.self) { Text($0).tag($0) }
                        } label: {
                            Text(row.subject)
                        }
                    }
                } header: {
                    Text("Fächer → Kurse")
                } footer: {
                    Text("Ordnet die Fachnamen der Hausaufgaben den Kürzeln im Stundenplan zu. Automatisch erkannt, bei Bedarf hier korrigieren.")
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        dismiss()
                        store.loadLocal()
                        Task { await store.refresh() }
                    }
                }
            }
        }
    }
}

extension Store {
    func autoCourse(for subject: String) -> String? {
        SubjectMatcher.match(subject, courses: courses)
    }
}
