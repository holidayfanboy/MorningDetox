import 'package:alarm/alarm.dart';

import '../models/detox_alarm.dart';
import 'alarm_sound_service.dart';
import 'settings_service.dart';

/// Thin wrapper around package:alarm -- purely the "arm/disarm with the OS"
/// half of alarm handling. [AlarmRepository] is what screens actually talk
/// to; it combines this with [AlarmStoreService] to also remember alarms
/// that are configured but currently disabled, which package:alarm has no
/// concept of.
class AlarmService {
  const AlarmService();

  Future<bool> arm(DetoxAlarm alarm) async {
    final payload = DetoxPayload(
      detoxMinutes: alarm.detoxMinutes,
      label: alarm.label,
    );
    final volume = await SettingsService.readVolume();
    return Alarm.set(
      alarmSettings: AlarmSettings(
        id: alarm.id,
        dateTime: alarm.dateTime,
        assetAudioPath: AlarmSoundService.resolve(alarm.soundPath),
        payload: payload.toJsonString(),
        loopAudio: true,
        vibrate: true,
        allowAlarmOverlap: true,
        volumeSettings: VolumeSettings.fade(
          fadeDuration: const Duration(seconds: 5),
          volume: volume,
        ),
        notificationSettings: NotificationSettings(
          title: 'Morning Detox',
          body: alarm.label == null || alarm.label!.isEmpty
              ? 'Your alarm is ringing'
              : '${alarm.label} alarm is ringing',
          stopButton: "I'm up",
        ),
      ),
    );
  }

  Future<bool> disarm(int id) => Alarm.stop(id);

  /// Caller-assigned id, same scheme the plugin's own example app uses.
  static int newId() => DateTime.now().millisecondsSinceEpoch % 100000 + 1;
}
