# Simple Photo Editor

[![Flutter CI](https://github.com/netersoft/simple-photo-editor/actions/workflows/flutter.yml/badge.svg)](https://github.com/netersoft/simple-photo-editor/actions/workflows/flutter.yml)

## Description

Quickly edit your photos and share them. Flutter rewrite of the [Simple Photo Editor](https://play.google.com/store/apps/details?id=com.neteru.simplephotoeditor) Android app (Java). Same application ID (`com.neteru.simplephotoeditor`), so the Flutter version ships as an update of the existing Play Store listing.

Built from the [flutter-starter](https://github.com/edpage-hq/flutter-starter), keeping only what the app uses: routing, settings (language, theme, about, recommend), i18n, theming, splash, crash reporting and analytics.

## Tech stack

- Mobile: Flutter (Android and iOS), Dart SDK `>=3.8.0 <4.0.0`
- State management: Riverpod (`riverpod_generator`, code-gen)
- Routing: go_router (`go_router_builder`)
- Local storage: SharedPreferences
- i18n: [Slang](https://pub.dev/packages/slang), French (base) and English
- Crash reporting / analytics: Firebase (Crashlytics + Analytics)

## Prerequisites

- Flutter SDK matching `>=3.8.0 <4.0.0`
- A `.env` file (see [Environment variables](#environment-variables))

## Installation

```bash
cp .env.example .env
flutter pub get
dart run slang
dart run build_runner build
flutter run --flavor dev
```

## Environment variables

The `.env` file is bundled as an asset and loaded at runtime: treat every value in it as **public**.

| Variable | Description | Example |
|----------|-------------|---------|
| `APP_PRIMARY_COLOR` | Primary theme color, hex | `#0000CD` |
| `APP_SECONDARY_COLOR` | Secondary theme color, hex | `#009ee3` |
| `APP_ACCENT_COLOR` | Accent theme color, hex | `#f5f5f5` |

## Running tests

```bash
flutter test
# with coverage, as run in CI:
flutter test --coverage
```

## Architecture

- `lib/main.dart`: entry point only.
- `lib/core/bootstrap/app_bootstrap.dart`: Flutter, env, Firebase, DI and locale bootstrap.
- `lib/app.dart`: root app widget, theme, and router view.
- `lib/core/`: providers, services, routes, helpers, extensions, tools.
- `lib/view/`: screens, components, themes.

All providers use `@riverpod` code generation. `GetIt` (with `injectable`) holds the infrastructure singletons: shared preferences and navigation.

Routes are defined in `lib/core/routes/app_route.dart` (type-safe `go_router_builder` routes) and built in `lib/core/routes/router.dart`.

Translations live in `assets/i18n/*.i18n.json` (base locale: fr) and are used through `context.t`. The locale comes from the device at first launch.

Generated files (`*.g.dart`, `*.config.dart`) are not committed: rebuild them with `dart run slang` and `dart run build_runner build`.

## Firebase (Crash Reporting + Analytics)

- `FirebaseSetup` (`lib/core/services/firebase/service.dart`) initializes Firebase once at bootstrap. `FirebaseSetup.isConfigured` detects the placeholder `lib/firebase_options.dart`, and every Firebase-backed service is a no-op until `flutterfire configure` replaces it.
- `CrashReportingService` sends uncaught errors to Crashlytics; `LogHelper.e` / `LogHelper.f` also report caught errors as non-fatal.
- `AnalyticsService` wraps `FirebaseAnalytics`; screen views are tracked through the router's `FirebaseAnalyticsObserver`.

## Quality

```bash
dart format .
flutter analyze
flutter test
```

## Build Flavors (dev / staging / prod)

Flavors only separate the app identity, so the three builds can be installed side by side.

- **Android**: each flavor gets its own `applicationId` suffix (`.dev`, `.staging`, none for `prod`) and app name (`android/app/build.gradle`).

  ```bash
  flutter run --flavor dev
  flutter build apk --flavor prod --release
  ```

- **iOS**: `flutter run` / `flutter build ios` without `--flavor`. Flavors would need a scheme and build configurations per flavor, created in Xcode.

## Release Builds

Pushing a `v*` tag (or running the workflow manually) builds a `prod` release APK (uploaded as a workflow artifact) and checks that iOS compiles (`flutter build ios --release --no-codesign`). The APK is signed with the debug key until `android/key.properties` and the app's keystore are set up: the Play Store update needs the keystore of the original app.
