import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/alarm_sound_service.dart';
import '../services/analytics_service.dart';
import '../services/settings_service.dart';
import '../widgets/toggle_dot.dart';
import 'allowed_apps_screen.dart';

/// App-wide settings, reached from the alarm list's overflow menu:
///  - alarm volume, with a speaker button that plays the default ringtone
///    at the chosen level so it can be heard before committing,
///  - the dark ("reversed") theme toggle,
///  - a shortcut to the Allowed Apps picker (Android only).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _analytics = AnalyticsService();

  /// Where the hosted privacy policy lives. TODO: replace with the real URL
  /// once `docs/privacy-policy.html` is published (e.g. GitHub Pages from
  /// the `/docs` folder) -- and mirror it into Play Console.
  static const _privacyPolicyUrl =
      'https://holidayfanboy.github.io/morning-detox/privacy-policy.html';

  /// Plays the ringtone preview for the volume test. Its own player, kept
  /// well away from `package:alarm`'s playback.
  final AudioPlayer _preview = AudioPlayer();
  StreamSubscription<void>? _previewDone;
  bool _previewing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_analytics.screenView('settings'));
    _previewDone = _preview.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _previewing = false);
    });
  }

  @override
  void dispose() {
    _previewDone?.cancel();
    _preview.dispose();
    super.dispose();
  }

  Future<void> _openPrivacyPolicy() async {
    try {
      final ok = await launchUrl(
        Uri.parse(_privacyPolicyUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted) _privacyLinkFailed();
    } catch (_) {
      if (mounted) _privacyLinkFailed();
    }
  }

  void _privacyLinkFailed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Couldn't open the privacy policy.")),
    );
  }

  Future<void> _togglePreview() async {
    if (_previewing) {
      await _preview.stop();
      if (mounted) setState(() => _previewing = false);
      return;
    }
    // AlarmSoundService.defaultPath is an `assets/...` path; AssetSource
    // wants it relative to the assets root.
    final assetPath = AlarmSoundService.defaultPath.replaceFirst('assets/', '');
    try {
      await _preview.stop();
      await _preview.setVolume(SettingsService.volume.value);
      await _preview.play(AssetSource(assetPath));
      if (mounted) setState(() => _previewing = true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't play the sample sound.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dividerColor = scheme.onSurface.withValues(alpha: 0.15);
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to alarms',
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _SettingsSection(
              title: 'Alarm volume',
              dividerColor: dividerColor,
              child: Row(
                children: [
                  Expanded(
                    child: ValueListenableBuilder<double>(
                      valueListenable: SettingsService.volume,
                      builder: (context, volume, _) {
                        return Slider(
                          value: volume,
                          onChanged: (value) => SettingsService.volume.value =
                              double.parse(value.toStringAsFixed(2)),
                          onChangeEnd: (value) {
                            unawaited(SettingsService.setVolume(value));
                            unawaited(
                              _analytics.settingChanged(
                                setting: 'alarm_volume',
                                value: value.toStringAsFixed(2),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _previewing ? Icons.stop_circle_outlined : Icons.volume_up,
                      size: 30,
                    ),
                    tooltip: _previewing ? 'Stop' : 'Test volume',
                    onPressed: () => unawaited(_togglePreview()),
                  ),
                ],
              ),
            ),
            _SettingsSection(
              title: 'Dark mode',
              dividerColor: dividerColor,
              child: Align(
                alignment: Alignment.centerLeft,
                child: ValueListenableBuilder<bool>(
                  valueListenable: SettingsService.darkMode,
                  builder: (context, dark, _) => ToggleDot(
                    value: dark,
                    seed: 42,
                    onChanged: (value) {
                      unawaited(SettingsService.setDarkMode(value));
                      unawaited(
                        _analytics.settingChanged(
                          setting: 'dark_mode',
                          value: '$value',
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            _SettingsSection(
              title: 'Share anonymous usage data',
              dividerColor: dividerColor,
              child: Align(
                alignment: Alignment.centerLeft,
                child: ValueListenableBuilder<bool>(
                  valueListenable: SettingsService.analyticsEnabled,
                  builder: (context, enabled, _) => ToggleDot(
                    value: enabled,
                    seed: 84,
                    onChanged: (value) =>
                        unawaited(SettingsService.setAnalyticsEnabled(value)),
                  ),
                ),
              ),
            ),
            _SettingsSection(
              title: 'Privacy',
              dividerColor: dividerColor,
              child: InkWell(
                onTap: () => unawaited(_openPrivacyPolicy()),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'How your usage data is handled',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Icon(Icons.open_in_new, color: scheme.onSurface),
                    ],
                  ),
                ),
              ),
            ),
            if (isAndroid)
              _SettingsSection(
                title: 'Allowed apps',
                dividerColor: dividerColor,
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AllowedAppsScreen(),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Choose apps that stay open during a lock',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Icon(Icons.chevron_right, color: scheme.onSurface),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One titled block in the settings list, with a hairline rule beneath it --
/// matches the row styling used on the alarm list and Allowed Apps screens.
class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.child,
    required this.dividerColor,
  });

  final String title;
  final Widget child;
  final Color dividerColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
