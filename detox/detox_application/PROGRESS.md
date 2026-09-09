# Progress log

Running notes on what's been built, session by session, so context isn't
lost between sessions. Newest first.

## 2026-09-09 -- Detox Now screen (immediate phone lock)

Built out the placeholder `lib/screens/detox_now_screen.dart` into a real
screen: a hand-drawn circular drag dial for choosing a lock duration, then
"Lock now" drops straight onto `DetoxLockScreen`.

- New `lib/widgets/DurationDial` -- controlled circular dial. Full circle =
  `maxMinutes` (360 = 6h); the filled arc grows clockwise from 12 o'clock.
  Drag is *relative* (`onPanStart` seeds an accumulator from the current
  value, deltas are unwrapped so winding past 12 o'clock never snaps
  empty<->full, first touch never jumps). Snaps to `stepMinutes` (5),
  clamps to 5..360. Painter (`_DialPainter`) reuses the app's wobbly-polygon
  + double-stroke idiom: faint 44-gon track ring, bolder open arc for the
  fill, a small filled blob knob at the arc's leading edge (always drawn so
  there's a grab point at the minimum). One `AnimationController` (250ms,
  discrete `_SwipeableAlarmRow` flavour): `_controller.value` = fraction,
  set 1:1 while `_dragging`, `animateTo(easeOut)` on a typed edit so the arc
  glides.
- Centre of the dial: "Lock your phone for..." wrapped in `WaterRippleText`,
  and below it a big `_EditableDuration` readout ("1h 30m"). Tapping the
  readout swaps in a `TextField` (phone keyboard) -- same tap-to-edit idiom
  as `_WheelColumn`. Parsed by new `parseFlexibleDurationMinutes()` in
  `lib/utils/duration_format.dart` ("2h 30m" / "150" / "45m" / "2h").
- Square "Lock now" button = `SketchyBox(borderRadius: 3)` wrapped in
  `WaterRippleText`, in a `GestureDetector` -- exactly the Emergency Unlock
  button pattern from `detox_lock_screen.dart`.
- Back arrow top-left (bare `IconButton`, no AppBar -- matches the
  chrome-less canvas feel of `DetoxLockScreen` / `AlarmListScreen`).
- "Lock now" mirrors `RingScreen._stop()` minus the alarm bookkeeping:
  `DetoxSessionService().start(alarmId: -1, minutes: _minutes)` then
  `Navigator.pushReplacement` to `DetoxLockScreen`. `alarmId: -1` is inert
  -- `detox_alarm_id` is written but never read by Dart or the native
  service. No changes to `app.dart` / `alarm_repository.dart` / Kotlin;
  resume + cold-start pick the session up from `activeEndAt()` already.

## 2026-09-08 -- Hand-drawn ripple background on the lock screen

New `lib/widgets/RippleBackground` -- an ambient, hand-drawn "the screen is
a pool" effect behind the `DetoxLockScreen` timer. Droplets land at random
points every ~0.8-2.6s; 2-3 concentric wobbly rings spread outward
(`easeOut`), swell in over the first 15% of life then fade out over the
rest. Rings are stroked twice with different per-vertex jitter (same
double-stroke trick as `SketchyBox`), coloured from
`colorScheme.onSurface` at <=0.16 alpha, so it's faint dark rings on white
/ faint grey rings on black. A tiny impact dab shows for the first instant
of each drop. No packages -- one `AnimationController(..repeat())` as a
frame driver + a `Stopwatch` clock + `CustomPainter`.

- `detox_lock_screen.dart` -- body is now a `Stack`: `Positioned.fill`
  `IgnorePointer(RippleBackground(seed: 13))` under the existing
  `SafeArea > Center > Column`. The Emergency Unlock button still receives
  taps (ripples are pointer-transparent).
- Three ripples start mid-spread (negative birth times) so the pool is
  never a dead flat wait for the first drop. Active ripples capped at 8.

New `lib/widgets/WaterRippleText` -- wraps the "phone-free time" label, the
`CountdownText`, and the Emergency Unlock `SketchyBox` so they read as
reflections floating on that pool: the
whole block slowly bobs, drifts sideways and tips ~1 degree (summed slow
sines on long periods), with a faint per-band horizontal ripple running
through the letters. Implementation: real child painted at opacity 0.01
inside a `RepaintBoundary`, snapshotted to a `ui.Image` via `toImageSync`
~10x/s (keeps the countdown digits current), redrawn every frame in 2px
bands with the float transform + ripple applied. Child still lays out
normally and its 1s timer keeps running. No shaders/packages.

- The distorted overlay is a painter-only `CustomPaint` (no child), so it
  doesn't absorb hits -- the Emergency Unlock `GestureDetector` still fires
  on taps over the box's laid-out bounds even while the visible box floats
  a few px off. Its float is toned down (amp 3.0) since it's a tap target.
- The Van Gogh quote above the countdown is now constrained to 78% of the
  screen width, `TextAlign.center`, with the attribution forced onto its
  own line -- was one full-bleed line running off both edges.

### Earlier this day -- Rain effect (added, then reverted)

Briefly added `flutter_rain_effect` as a background layer on
`DetoxLockScreen`, then removed it -- the effect wasn't what was wanted.
No `flutter_rain_effect` dependency remains.

## 2026-09-08 -- ToggleDot "ink drop" animation

`lib/widgets/toggle_dot.dart` -- turning a dot *on* now animates: a droplet
falls onto the geometric top of the wobbly circle (~120ms), then the fill
spreads radially from that contact point, clipped to the path, until full
(~330ms; 450ms total). Turning *off* is unchanged -- instant.

- `ToggleDot` is now a `StatefulWidget` with `SingleTickerProviderStateMixin`
  and one `AnimationController` (0 = outline, 1 = filled), matching the
  `_SwipeableAlarmRowState` idiom. `didUpdateWidget` animates only on
  false->true; true->false does `_controller.value = 0` (instant snap, stops
  any in-flight fill); an unchanged `value` is ignored, so `ListView` scroll
  rebuilds / data reloads can't restart a running fill. Constructor and all
  call sites are unchanged.
- `_DotPainter`: `bool filled` -> `double progress`. `_wobblyCircle` geometry
  untouched (built first so the seeded jitter order is preserved). Two small
  flourishes gated behind `_DotPainter._ripple`: a shrinking vertically-
  squashed "splat" blob for the first quarter of the spread, and one faint
  ring (alpha 0.22 -> 0) riding the fill front.

## 2026-09-08 -- Settings screen

Built out the previously-empty `lib/screens/settings_screen.dart`.

- New `lib/services/settings_service.dart` -- persists two prefs and exposes
  them as `ValueNotifier`s (the one service here that keeps live state, so
  the theme can flip instantly): `alarm_volume` (double 0..1, default 0.8)
  and `dark_mode` (bool). `main.dart` calls `SettingsService.load()` before
  `runApp`.
- `lib/theme/app_theme.dart` -- refactored the single `light` getter into a
  shared `_from(ColorScheme)` builder and added `AppTheme.dark`: black
  surface, `0xFFB0B0B0` grey ink/primary. `lib/app.dart` now wraps
  `MaterialApp` in a `ValueListenableBuilder` on `SettingsService.darkMode`
  and sets `theme`/`darkTheme`/`themeMode`.
- `lib/services/alarm_service.dart` -- `arm()` is now `async` and reads
  `SettingsService.readVolume()` into `VolumeSettings.fade(volume: ...)`, so
  the slider actually changes how loud alarms ring.
- Settings screen sections: alarm-volume `Slider` + a speaker `IconButton`
  that previews `AlarmSoundService.defaultPath` at the chosen level via a
  dedicated `audioplayers` `AudioPlayer` (own player, separate from
  `package:alarm`); dark-mode `ToggleDot`; an Android-only row linking to
  `AllowedAppsScreen`. Explicit back arrow in the AppBar leading slot.
- New dep: `audioplayers: ^6.1.0`.
- **TODO (user): the volume preview needs the real `assets/sounds/*.mp3`
  files** (same TODO as the sound picker) -- until they exist the speaker
  button shows a "couldn't play" snackbar.

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
