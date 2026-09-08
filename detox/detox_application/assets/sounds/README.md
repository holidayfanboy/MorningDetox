# Default alarm sounds

Drop the app's built-in ringtones here as `.mp3` files. The picker in
`lib/services/alarm_sound_service.dart` (`AlarmSoundService.builtIn`) expects
these exact filenames:

- `classic.mp3`
- `chimes.mp3`
- `gentle_rise.mp3`
- `digital.mp3`

The "Default" chip (selected when the user hasn't picked a sound) is
separate from the four above and resolves to one of two platform-specific
files, chosen automatically at runtime by `AlarmSoundService.defaultPath`:

- `default_android.mp3` -- used on Android
- `default_ios.mp3` -- used on iOS

Adding, renaming, or removing a named sound is two steps:

1. Put the `.mp3` file in this folder (already registered as a Flutter asset
   via the `assets/sounds/` entry in `pubspec.yaml` -- no pubspec edit needed
   per file).
2. Add/update the matching `SoundOption` entry in `AlarmSoundService.builtIn`.

Note: `pubspec.yaml` registers this whole folder as an asset directory, so
this README technically ships in the app bundle too (a harmless few hundred
bytes) -- Flutter has no way to register "every .mp3 in this folder" without
including whatever else is dropped alongside them.
