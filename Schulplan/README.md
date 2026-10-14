# Schulplan

Minimal iOS app (SwiftUI, iOS 17+) for the timetable and homework that
[SchulmanagerWidgetV3](https://github.com/jdftrapp/SchulmanagerWidgetV3) scrapes from Schulmanager.

- **Morgen** – today until the last lesson is over, then the next school day, as a timeline
  with each task inside the lesson it is due in. Day switcher at the bottom.
- **Plan** – week grid with the same cell rules as the home-screen widget; tap a lesson with a dot
  to see its homework.
- **Aufgaben** – homework by due date or by subject; tasks whose lesson is over move to
  "Alte Aufgaben".

## Data

The app reads `schedule.json` and `homework.json` from the scraper repo via the GitHub API.
Enter a fine-grained token (Contents: read-only, only that repo) in the settings; it is kept in
the Keychain. Without a token the app shows the sample data in `Schulplan/Resources`.

Homework dates are the day a task was given; a task is due at the course's next lesson
that is not cancelled. Homework subjects ("Mathematik") are matched to timetable courses
("M L2") automatically and can be corrected under Settings → Fächer → Kurse.

## Build

Open `Schulplan.xcodeproj` in Xcode and run. The project is generated from `project.yml`
with [XcodeGen](https://github.com/yonaskolb/XcodeGen) – after adding files run `xcodegen generate`.

The app icon is drawn by `tools/make-icon.swift`:

    swift tools/make-icon.swift Schulplan/Assets.xcassets/AppIcon.appiconset/icon.png
