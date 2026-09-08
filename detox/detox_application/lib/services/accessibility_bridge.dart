import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridge to the Android accessibility service that redirects the user back
/// to the Detox lock screen if they leave the app mid-session. No-ops on
/// iOS (there is no platform equivalent), so call sites never need
/// Platform.isAndroid checks.
class AccessibilityBridge {
  const AccessibilityBridge();

  static const _channel = MethodChannel('morningdetox/accessibility');

  Future<bool> isEnabled() async {
    if (!defaultTargetPlatform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod<bool>('isEnabled');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openSettings() async {
    if (!defaultTargetPlatform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openSettings');
    } catch (_) {
      // Nothing actionable if the platform call fails; the explainer
      // screen's own copy already tells the user where to look manually.
    }
  }
}

extension on TargetPlatform {
  bool get isAndroid => this == TargetPlatform.android;
}
