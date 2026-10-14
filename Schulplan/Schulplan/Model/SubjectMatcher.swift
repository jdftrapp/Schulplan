import Foundation

/// Works out which timetable course ("M L2") a homework subject ("Mathematik") belongs to.
///
/// Order of attempts:
///  1. a manual override from the settings screen
///  2. the homework subject already contains a course or code from the timetable
///  3. a dictionary of German subject names -> usual abbreviations
///  4. the abbreviation's letters appear in order in the name ("Sozialwissenschaften" ~ "SW")
enum SubjectMatcher {
    /// Usual NRW / German abbreviations. Keys are lowercased, umlauts kept.
    static let names: [(name: String, codes: [String])] = [
        ("deutsch", ["D", "DE"]),
        ("englisch", ["E", "EN"]),
        ("mathematik", ["M", "MA"]),
        ("mathe", ["M", "MA"]),
        ("kunst", ["KU"]),
        ("informatik", ["IF", "INF", "IN"]),
        ("geschichte", ["GE", "G"]),
        ("sozialwissenschaften", ["SW", "SOWI"]),
        ("sowi", ["SW", "SOWI"]),
        ("politik", ["PO", "PK", "SW"]),
        ("wirtschaft", ["WI", "PW"]),
        ("erdkunde", ["EK", "GEO"]),
        ("geographie", ["EK", "GEO"]),
        ("biologie", ["BI", "BIO"]),
        ("sport", ["SP"]),
        ("physik", ["PH"]),
        ("chemie", ["CH"]),
        ("französisch", ["F", "FR"]),
        ("latein", ["L", "LA"]),
        ("spanisch", ["S", "SN", "SPA"]),
        ("italienisch", ["I", "IT"]),
        ("niederländisch", ["N", "NL"]),
        ("griechisch", ["GR"]),
        ("russisch", ["RU"]),
        ("chinesisch", ["C", "CHI"]),
        ("musik", ["MU"]),
        ("katholische religion", ["KR", "RK"]),
        ("evangelische religion", ["ER", "RE"]),
        ("religion", ["KR", "ER", "RE", "RK", "RL"]),
        ("praktische philosophie", ["PP"]),
        ("philosophie", ["PL", "PHI", "PP"]),
        ("literatur", ["LI", "LIT"]),
        ("pädagogik", ["PA"]),
        ("erziehungswissenschaft", ["PA", "EW"]),
        ("psychologie", ["PS"]),
        ("darstellendes spiel", ["DS"]),
        ("technik", ["TC", "TE"]),
        ("projektkurs", ["PJK", "PK"]),
        ("vertiefung", ["VT"]),
    ]

    /// "KU L1" -> "KU", "E5 G1" -> "E", "F6" -> "F"
    static func base(of code: String) -> String {
        let first = code.split(separator: " ").first.map(String.init) ?? code
        let letters = first.prefix { $0.isLetter }
        return letters.isEmpty ? first.uppercased() : letters.uppercased()
    }

    /// Short all-caps tokens like "M L2", "E5 G1", "KU" - as opposed to "Klausur".
    static func looksLikeCode(_ s: String) -> Bool {
        guard let first = s.split(separator: " ").first, first.count <= 5 else { return false }
        return first.allSatisfy { $0.isUppercase || $0.isNumber }
    }

    static func normalize(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    /// - Parameters:
    ///   - courses: timetable subjects with how often they occur, e.g. ["M L2": 5, "E5": 3].
    ///   - overrides: normalized homework subject -> course, set by the user.
    static func match(_ subject: String, courses: [String: Int], overrides: [String: String] = [:]) -> String? {
        let key = normalize(subject)
        if let manual = overrides[key] { return manual.isEmpty ? nil : manual }

        let real = courses.filter { looksLikeCode($0.key) }
        guard !real.isEmpty else { return nil }
        func best(_ candidates: [String: Int]) -> String? {
            // Most frequent wins; prefer full courses ("E5 G1") over bare codes ("E5").
            candidates.max { a, b in
                let ka = (a.key.contains(" ") ? 1 : 0, a.value), kb = (b.key.contains(" ") ? 1 : 0, b.value)
                return ka < kb || (ka == kb && a.key > b.key)
            }?.key
        }

        // 2. The homework subject already names a course or code.
        let upperTokens = Set(subject.uppercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
        if let exact = real.keys.first(where: { normalize($0) == key }) { return exact }
        let byCode = real.filter { upperTokens.contains($0.key.split(separator: " ").first.map(String.init) ?? "") }
        if let hit = best(byCode) { return hit }

        // 3. Dictionary: longest name contained in the subject wins.
        let hits = names.filter { key.contains($0.name) }.sorted { $0.name.count > $1.name.count }
        for hit in hits {
            let candidates = real.filter { hit.codes.contains(base(of: $0.key)) }
            if let found = best(candidates) { return found }
        }

        // A known subject that just isn't in the timetable must not be guessed.
        if !hits.isEmpty { return nil }

        // 4. Letters of the abbreviation appear in order, starting with the first letter.
        let letters = key.filter { $0.isLetter }
        let fuzzy = real.filter { course in
            let b = base(of: course.key).lowercased()
            guard let f = b.first, letters.first == f else { return false }
            return isSubsequence(b, of: letters)
        }
        // Longer abbreviations are more specific ("SW" beats "S" for Sozialwissenschaften).
        let longest = fuzzy.map { base(of: $0.key).count }.max() ?? 0
        return best(fuzzy.filter { base(of: $0.key).count == longest })
    }

    private static func isSubsequence(_ needle: String, of haystack: String) -> Bool {
        var it = haystack.makeIterator()
        for c in needle {
            var found = false
            while let h = it.next() { if h == c { found = true; break } }
            if !found { return false }
        }
        return true
    }
}
