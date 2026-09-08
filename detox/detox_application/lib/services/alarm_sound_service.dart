import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/sound_option.dart';

/// Alarm ringtones: the handful bundled with the app, plus any mp3s the
/// user has imported from their device.
///
/// Bundled sounds live under `assets/sounds/` (see that folder's README).
/// Imported ones are copied into the app's own sandbox
/// (`<Documents>/custom_sounds/`), since package:alarm needs a path it can
/// still resolve later -- the original file the user picked may move,
/// be deleted, or (on iOS) never have been accessible outside that one pick.
class AlarmSoundService {
  const AlarmSoundService();

  /// Sounds shipped with the app. Add the matching `.mp3` under
  /// `assets/sounds/` -- see that folder's README for the expected names.
  static const builtIn = [
    SoundOption(name: 'Classic', path: 'assets/sounds/classic.mp3'),
    SoundOption(name: 'Chimes', path: 'assets/sounds/chimes.mp3'),
    SoundOption(name: 'Gentle Rise', path: 'assets/sounds/gentle_rise.mp3'),
    SoundOption(name: 'Digital', path: 'assets/sounds/digital.mp3'),
  ];

  /// The app's own default ringtone, used when the user leaves the
  /// "Default" chip selected (`DetoxAlarm.soundPath == null`). Android and
  /// iOS ship separate files here rather than falling back to whatever the
  /// OS's own default alarm tone is.
  static String get defaultPath =>
      defaultTargetPlatform == TargetPlatform.android
      ? 'assets/sounds/default_android.mp3'
      : 'assets/sounds/default_ios.mp3';

  /// What to actually arm the OS alarm with: the user's explicit pick, or
  /// [defaultPath] if they left it as "Default".
  static String resolve(String? soundPath) => soundPath ?? defaultPath;

  Future<Directory> _customSoundsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'custom_sounds'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Previously imported sounds, most recently added first.
  Future<List<SoundOption>> loadCustom() async {
    final dir = await _customSoundsDir();
    final entries = await dir.list().toList();
    final files =
        entries
            .whereType<File>()
            .where((f) => p.extension(f.path).toLowerCase() == '.mp3')
            .toList()
          ..sort(
            (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
          );
    return [
      for (final file in files)
        SoundOption(
          name: p.basenameWithoutExtension(file.path),
          path: 'custom_sounds/${p.basename(file.path)}',
          isCustom: true,
        ),
    ];
  }

  /// Opens a file picker for an mp3, copies it into the app's sandbox, and
  /// returns the resulting [SoundOption] -- or null if the user cancelled.
  Future<SoundOption?> import() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
    );
    final sourcePath = picked?.path;
    if (sourcePath == null) return null;

    final dir = await _customSoundsDir();
    final fileName = _uniqueFileName(dir, p.basename(sourcePath));
    await File(sourcePath).copy(p.join(dir.path, fileName));

    return SoundOption(
      name: p.basenameWithoutExtension(fileName),
      path: 'custom_sounds/$fileName',
      isCustom: true,
    );
  }

  /// Removes a previously imported sound from the app's sandbox.
  Future<void> deleteCustom(SoundOption sound) async {
    final docs = await getApplicationDocumentsDirectory();
    final file = File(p.join(docs.path, sound.path));
    if (await file.exists()) await file.delete();
  }

  /// Appends " (1)", " (2)", ... if a file with that name was already
  /// imported, rather than silently overwriting it.
  String _uniqueFileName(Directory dir, String originalName) {
    final ext = p.extension(originalName);
    final base = p.basenameWithoutExtension(originalName);
    var candidate = originalName;
    var i = 1;
    while (File(p.join(dir.path, candidate)).existsSync()) {
      candidate = '$base ($i)$ext';
      i++;
    }
    return candidate;
  }
}
