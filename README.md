# Simple Photo Editor

[![Flutter CI](https://github.com/netersoft/simple-photo-editor/actions/workflows/flutter.yml/badge.svg)](https://github.com/netersoft/simple-photo-editor/actions/workflows/flutter.yml)

## Description

Quickly edit your photos and share them. Flutter rewrite of the [Simple Photo Editor](https://play.google.com/store/apps/details?id=com.neteru.simplephotoeditor) Android app (Java). Same application ID (`com.neteru.simplephotoeditor`), so the Flutter version ships as an update of the existing Play Store listing.

The launcher icon and splash come from the Java app's lens logo (`assets/images/lens.svg`).

## Features

- **Home**: the Java app's layout, six round buttons on a hexagon around the lens: camera, gallery, collection, settings, rate the app, Netersoft's other apps (Android, its Play Store developer page). The review prompt shows once, after 10 launches over at least 10 days, like the Java app.
- **Settings**: language and theme; rate, share the app (system share sheet), other apps, privacy policy, about.
- **Editor** (`lib/view/screens/editor/`):
  - *Adjust* opens [filmkit](https://pub.dev/packages/filmkit)'s editor: crop with ratios, the Java app's 16 color filters recreated as LUTs (`lib/core/editor/legacy_looks.dart`), brightness, contrast, saturation and warmth. It always works from the original photo, reopened where the user left off.
  - *Rotate* (quarter turns and mirror), *Brush*, *Eraser* (erases strokes only), *Text*, *Emoji* and *Sticker* (the Java app's stickers, `assets/stickers/`): layers over the photo, in coordinates relative to it (`lib/core/editor/layers.dart`), drawn by the same painter on screen and at full size. Texts, emojis and stickers move, scale and turn with one or two fingers; a double tap edits a text.
  - Undo and redo of every step, image info (file, size, dimensions, camera EXIF data) with copy and share, and the Java app's prompt to save, cancel or discard when leaving with unsaved changes.
  - Saving renders the photo with its layers at full size (2048 px at most) and writes a JPEG to the **Simple Photo Editor** gallery album, then opens the sharing screen.
- **Collection**: the album's photos (on Android, `Pictures/Simple Photo Editor`, where the Java app saved them too), full screen with zoom, edit again, info, share and delete.

Not ported from the Java app: the fish eye, grain, sharpen and vignette filters (not color transforms, so not LUTs), and the per-app share buttons (WhatsApp, Facebook…), replaced by the system share sheet.

## Tech stack

- Mobile: Flutter (Android and iOS), Dart SDK `>=3.8.0 <4.0.0`; Roboto font, bundled in `assets/fonts/roboto/` (Apache 2.0)
- State management: Riverpod (`riverpod_generator`, code-gen)
- Routing: go_router (`go_router_builder`)
- Local storage: SharedPreferences
- i18n: [Slang](https://pub.dev/packages/slang), French (base) and English
- Photo editing: filmkit (crop, filters, native export), image_picker, photo_manager (gallery album), exif

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

## Permissions

- Android: `READ_MEDIA_IMAGES` (and `READ_MEDIA_VISUAL_USER_SELECTED` for Android 14's partial access) to list the album in the collection; `READ_EXTERNAL_STORAGE` up to Android 12 and `WRITE_EXTERNAL_STORAGE` up to Android 9. The camera goes through the system camera app, without the `CAMERA` permission. On the Play Store, `READ_MEDIA_IMAGES` must be declared in the Photo and video permissions form: a photo editor is one of the accepted uses.
- iOS: photo library (read, add) and camera usage descriptions in `Info.plist`.

## Running tests

```bash
flutter test
# with coverage, as run in CI:
flutter test --coverage
```

## Architecture

- `lib/main.dart`: entry point only.
- `lib/core/bootstrap/app_bootstrap.dart`: Flutter, env, DI and locale bootstrap.
- `lib/app.dart`: root app widget, theme, and router view.
- `lib/core/`: providers, services, routes, helpers, extensions, tools.
- `lib/view/`: screens, components, themes.

The editor's state (history of `PhotoDocument`s, brush, selection) is the `photoEditorProvider` (`lib/core/providers/editor/`); the gallery album is `GalleryService` (`lib/core/services/gallery/`).

All providers use `@riverpod` code generation. `GetIt` (with `injectable`) holds the infrastructure singletons: shared preferences and navigation.

Routes are defined in `lib/core/routes/app_route.dart` (type-safe `go_router_builder` routes) and built in `lib/core/routes/router.dart`.

Translations live in `assets/i18n/*.i18n.json` (base locale: en, the fallback for unsupported device languages) and are used through `context.t`. The locale comes from the device at first launch.

Generated files (`*.g.dart`, `*.config.dart`) are not committed: rebuild them with `dart run slang` and `dart run build_runner build`.

## Privacy policy

The privacy policy ships in the app (`assets/docs/<locale>/privacy_policy.html`, one per app language, opened from Settings). The store listings link to the public copy at https://netersoft.github.io/simple-photo-editor/privacy/ (English: `/en/`), served by GitHub Pages from the public `netersoft/netersoft.github.io` repository. After editing the policy, regenerate the pages and push that repository:

```bash
python3 tool/build_privacy_pages.py ~/Dev/Projects/Web/netersoft.github.io
```

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

## License

Simple Photo Editor is free software by Netersoft.

- **Code**: the source code (`lib/`, `test/`, `tool/` and the platform folders) is licensed under the [GNU General Public License v3.0](LICENSE).
- **Content**: the texts, translations and pictures made by Netersoft for the app are licensed under [Creative Commons Attribution-ShareAlike 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
- **Third-party files** keep their own licenses: the OpenMoji emoji stickers (CC BY-SA 4.0), the error screen icon from game-icons.net (CC BY 3.0) and the Roboto font (Apache 2.0), listed in the in-app Sources and credits page (`assets/docs/<locale>/credits.html`).
- **Names and icons**: the Netersoft name, the Simple Photo Editor name, and the app icons and logos (`assets/images/launcher/` and `assets/images/lens.svg`) are not covered by these licenses. A modified version must use another name and icon.

Copyright © 2018-2026 Netersoft.
