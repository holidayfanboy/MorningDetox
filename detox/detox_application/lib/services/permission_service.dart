import 'package:alarm/alarm.dart';
import 'package:permission_handler/permission_handler.dart';

/// Notification + exact-alarm permission checks, following the pattern from
/// package:alarm's own example app (AlarmPermissions in its services/permission.dart).
class PermissionService {
  const PermissionService();

  Future<void> checkNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isDenied) {
      await Permission.notification.request();
    }
  }

  Future<void> checkAndroidScheduleExactAlarmPermission() async {
    if (!Alarm.android) return;
    final status = await Permission.scheduleExactAlarm.status;
    if (status.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
  }
}
