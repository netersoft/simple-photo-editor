# Play Store screenshots

`store/screenshots/<lang>/` holds the 6 phone screenshots of the store listing, one set per
app language: 1080×1920 (9:16) 24-bit PNGs, a white title over the app's blue gradient and a
light-theme capture in a phone frame.

## The demo photo

[Brighton beach at sunset](https://commons.wikimedia.org/wiki/File:Brighton_beach_at_sunset_2025-02-27.jpg),
by Andy Li, CC0 1.0 (public domain dedication): free to use and edit, no attribution
required. Only the screenshots contain it; it is not in the app.

## Regenerate them

1. Start the shared emulator (`test-phone`, 1080×2400), install a fresh build and put the
   demo photo, alone, in the device gallery:

   ```bash
   flutter build apk --profile --flavor dev
   adb install -r build/app/outputs/flutter-apk/app-dev-profile.apk
   curl -L -o /tmp/beach.jpg 'https://commons.wikimedia.org/wiki/Special:FilePath/Brighton_beach_at_sunset_2025-02-27.jpg?width=2048'
   adb push /tmp/beach.jpg /sdcard/Pictures/Demo/beach.jpg
   adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///sdcard/Pictures/Demo/beach.jpg
   ```

2. Clean status bar (10:00, full battery and Wi-Fi, no notifications):

   ```bash
   adb shell settings put global sysui_demo_allowed 1
   adb shell am broadcast -a com.android.systemui.demo -e command enter
   adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 1000
   adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false
   adb shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4 -e fully true
   adb shell am broadcast -a com.android.systemui.demo -e command network -e mobile hide
   adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false
   ```

3. In Gboard's settings (Text correction), turn off the suggestion strip and auto-correction;
   turn them back on afterwards.

4. Capture each language, then build the images:

   ```bash
   for lang in en fr; do python3 tool/store_screenshots/capture.py /tmp/captures $lang; done
   python3 tool/store_screenshots/compose.py /tmp/captures
   ```

   Each run clears the app's data, edits the photo (filter, brush, sticker, caption, emoji),
   saves it, then deletes the saved copy so the next run opens the demo photo again.

5. Look at every image before uploading them, then exit demo mode
   (`adb shell am broadcast -a com.android.systemui.demo -e command exit`).

## How it works

- `config.json`: screen order, titles in each language, colors.
- `capture.py` drives the app with `adb`. Tool labels move with the language, so they are
  found by their text, read with macOS Vision (`ocr.swift`) and matched against
  `assets/i18n/<lang>.i18n.json`. The heart is drawn with `adb shell input motionevent`, one
  continuous touch.
- `adb_ui.py`: taps, typing, keyboard detection and text lookup.
- `compose.py` builds the final images.
