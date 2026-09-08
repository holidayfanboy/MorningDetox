/// One selectable alarm ringtone.
///
/// [path] is fed straight into `AlarmSettings.assetAudioPath` -- for a
/// built-in sound that's a bundled `assets/...` path; for one the user
/// imported it's a path relative to the app's Documents directory
/// (`custom_sounds/<file>.mp3`), which is the format package:alarm expects
/// for a local file so it keeps resolving across app updates.
class SoundOption {
  const SoundOption({
    required this.name,
    required this.path,
    this.isCustom = false,
  });

  final String name;
  final String path;
  final bool isCustom;
}
