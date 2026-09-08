import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Alarm.init();
  await SettingsService.load();
  runApp(const DetoxApp());
}
