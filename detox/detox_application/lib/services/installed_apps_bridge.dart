import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/installed_app.dart';

/// Bridge to the launchable-apps list on Android, used to populate the
/// "Allowed Apps" picker. No-ops (empty list) on iOS, since there is no
/// platform equivalent -- call sites never need Platform.isAndroid checks.
class InstalledAppsBridge {
  const InstalledAppsBridge();

  static const _channel = MethodChannel('morningdetox/apps');

  Future<List<InstalledApp>> listLaunchableApps() async {
    if (!defaultTargetPlatform.isAndroid) return const [];
    try {
      final result = await _channel.invokeMethod<List<Object?>>(
        'listLaunchableApps',
      );
      if (result == null) return const [];
      return result
          .map(InstalledApp.fromMap)
          .whereType<InstalledApp>()
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

extension on TargetPlatform {
  bool get isAndroid => this == TargetPlatform.android;
}
