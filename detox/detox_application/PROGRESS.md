# Progress log

Running notes on what's been built, session by session, so context isn't
lost between sessions. Newest first.

## 2026-09-05 -- Alarm sound picker, Allowed Apps, list/edit screen polish

### Alarm sound picker
- New model `lib/models/sound_option.dart` (`SoundOption`: name/path/isCustom).
- `DetoxAlarm.soundPath` (nullable) added in `lib/models/detox_alarm.dart`.
- New `lib/services/alarm_sound_service.dart`:
  - `builtIn` -- 4 bundled sounds: Classic, Chimes, Gentle Rise, Digital.
  - `import()` / `loadCustom()` / `deleteCustom()` -- lets the user pick an
    mp3 via `file_picker`, copies it into `<Documents>/custom_sounds/`.
  - `defaultPath` / `resolve()` -- the "Default" chip now resolves to one
    of two bundled files depending on platform (see below), instead of the
    OS's own default alarm tone.
- `lib/services/alarm_service.dart` arms the OS alarm with
  `AlarmSoundService.resolve(alarm.soundPath)`.
- `lib/screens/edit_alarm_screen.dart` gained an "Alarm Sound" section:
  chips for Default + the 4 built-ins + any imported sounds, plus an
  "Add mp3" chip that opens the file picker. Custom chips can be deleted.
- New deps: `path_provider`, `file_picker`, `path`.
- **TODO (user): drop real `.mp3` files into `assets/sounds/`** -- see that
  folder's `README.md` for the exact filenames expected:
  `classic.mp3`, `chimes.mp3`, `gentle_rise.mp3`, `digital.mp3`,
  `default_android.mp3`, `default_ios.mp3`. Until those exist, selecting
  those chips arms a path that isn't actually bundled.

### Platform-specific default sound
- `AlarmSoundService.defaultPath` picks `default_android.mp3` on Android,
  `default_ios.mp3` on iOS, via `defaultTargetPlatform`. The "Default" chip
  in the picker is unchanged in the UI -- only what it resolves to at
  arm-time differs per platform now.

### Allowed Apps (Android only)
Lets the user choose which apps stay reachable during a detox lock session
instead of being blocked entirely. Global list (not per-alarm). No iOS
equivalent exists (Apple's Screen Time/Family Controls needs a special
entitlement, out of scope) -- the entry point is hidden on iOS.

- `lib/models/installed_app.dart` -- `{packageName, label}`.
- `lib/services/allowed_apps_service.dart` -- persists the allow-list as a
  single JSON-string `SharedPreferences` key (`allowed_packages`),
  deliberately not `setStringList` so the native side can read it with a
  plain `getString`.
- `lib/services/installed_apps_bridge.dart` -- `MethodChannel('morningdetox/apps')`,
  wraps `listLaunchableApps()`; empty list on iOS.
- `lib/screens/allowed_apps_screen.dart` -- name + `ToggleDot` per row,
  auto-saves on toggle.
- `lib/screens/alarm_list_screen.dart` -- new toolbar icon
  (`Icons.apps_rounded`, Android-only) opens the picker.
- Native (Android):
  - `AndroidManifest.xml` -- added a `MAIN`/`LAUNCHER` `<queries>` entry so
    the app can see other apps' names under Android 11+ visibility rules.
  - `MainActivity.kt` -- new `morningdetox/apps` channel,
    `listLaunchableApps()` via `PackageManager.queryIntentActivities`.
  - `DetoxAccessibilityService.kt` -- reads `flutter.allowed_packages`
    directly (same pattern as `detox_active`/`detox_end_at_millis`) and
    skips re-fronting the app when the foreground package is on the list.
- Design choices: nothing is force-allowed besides the Detox app itself
  (no hardcoded Phone/dialer exception -- "Emergency Unlock" is still the
  full escape hatch); one global list rather than per-alarm.
- **TODO (user): test on a real Android device/emulator** -- grant the
  accessibility permission, toggle a couple of apps on, start a detox
  session, confirm allowed apps stay open and everything else snaps back.

### Alarm list & edit screen polish
- `lib/screens/alarm_list_screen.dart`: time display converted from 12-hour
  AM/PM to 24-hour (`17:30` instead of `5:30 PM`).
- Alarm row caption now reads `Memo • Locked <duration> • <countdown>`
  (added `formatMinutesShort` to `lib/utils/duration_format.dart`).
- `lib/screens/edit_alarm_screen.dart`:
  - "Label" renamed to "Memo".
  - Memo field is now a plain borderless `TextField` (no box outline).
  - "Stay off your phone for" is now a typed number + "minutes", with
    30m/1h/1h 30m/2h quick-pick chips below (`_detoxPresets`).
  - Time picker replaced with a custom 24-hour scroll-wheel
    (`lib/widgets/wheel_time_picker.dart`) -- drag to change hour/minute,
    or tap a number to type it directly.
- `lib/theme/app_theme.dart`: `AppTheme.clockLetterSpacing` -- extra
  letter-spacing applied only to the alarm time + its caption (not
  app-wide), currently `7.5`.

## Earlier

- Initial exploration of the app's phone-lock mechanism (for the Allowed
  Apps feature): confirmed enforcement is entirely native
  (`DetoxAccessibilityService.kt`, Android-only, re-fronts `MainActivity`
  on any foreground-app change while a session is active), with no iOS
  equivalent.
- App font (`PeachesForBreakfast`) letter-spacing widened for readability.
