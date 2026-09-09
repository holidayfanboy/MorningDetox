import 'package:alarm/alarm.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/analytics_service.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Alarm.init();
  await SettingsService.load();
  await AnalyticsService.init();
  runApp(const DetoxApp());
}
