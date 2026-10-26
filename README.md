# KARATE ELITE — Android Kumite Scoreboard

A lightweight, offline-first, landscape scoreboard for karate kumite. Built with Flutter. English UI, dark broadcast-inspired styling, AKA red / AO blue.

## Features
- Landscape-first immersive Android interface
- Manual start/pause/resume clock with configurable 1:00, 1:30, 2:00, 3:00 or 4:00 rounds
- One-tap +1 / +2 / +3 scoring for either competitor
- Simple penalty control (+1 to the opponent)
- Automatic match end at an 8-point lead or when the clock reaches zero
- Undo recent scoring/clock actions
- Athlete names and local match history (saved on the device)
- Reset clock, reset match, end match, and match-complete dialog
- GitHub Actions workflow builds a release APK and stores it as an artifact

> This is a customizable training/club scoreboard, not an official WKF scoring or refereeing system. Confirm competition rules and penalty semantics with the event's rule set before live competition use.

## Build APK using GitHub Actions
1. Create a new GitHub repository, for example `karate-scoreboard`.
2. Extract this ZIP and upload **the contents of this folder** to the repository root (so `pubspec.yaml`, `lib/`, and `.github/` are at the root).
3. Commit and push to `main` (or `master`).
4. Open the repository's **Actions** tab and select **Build Android APK**.
5. Open the newest successful run. Under **Artifacts**, download `karate-elite-release-apk`.
6. Extract the artifact ZIP to get `app-release.apk`.

You can also run the workflow manually from **Actions → Build Android APK → Run workflow**.

## Local development
Install Flutter stable and Android SDK, then run:

```bash
flutter create --platforms=android --org com.karateelite .
flutter pub get
flutter test
flutter run
```

To build locally:

```bash
flutter build apk --release
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`.
