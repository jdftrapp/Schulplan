import XCTest
@testable import Schulplan

final class SubjectMatcherTests: XCTestCase {
    let courses = ["KU L1": 5, "M L2": 5, "IF G2": 3, "E5 G1": 3, "E5": 3, "GE Z1": 3, "SW G1": 3,
                   "EK G1": 3, "D G2": 3, "BI G2": 3, "SP G1": 3]

    func testFullNames() {
        let expected = ["Mathematik": "M L2", "Kunst": "KU L1", "Informatik": "IF G2", "Englisch": "E5 G1",
                        "Geschichte": "GE Z1", "Sozialwissenschaften": "SW G1", "Erdkunde": "EK G1",
                        "Deutsch": "D G2", "Biologie": "BI G2", "Sport": "SP G1"]
        for (name, course) in expected {
            XCTAssertEqual(SubjectMatcher.match(name, courses: courses), course, name)
        }
    }

    func testCodesAndCourses() {
        XCTAssertEqual(SubjectMatcher.match("M L2", courses: courses), "M L2")
        XCTAssertEqual(SubjectMatcher.match("Englisch (E5)", courses: courses), "E5 G1")
        XCTAssertEqual(SubjectMatcher.match("D", courses: courses), "D G2")
    }

    func testUnknownAndOverrides() {
        XCTAssertNil(SubjectMatcher.match("Spanisch", courses: courses))
        XCTAssertNil(SubjectMatcher.match("Klausur", courses: ["Klausur": 9]))
        XCTAssertEqual(SubjectMatcher.match("Spanisch", courses: courses, overrides: ["spanisch": "SP G1"]), "SP G1")
    }
}
