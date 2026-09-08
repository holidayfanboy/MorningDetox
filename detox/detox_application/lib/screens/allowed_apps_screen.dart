import 'dart:async';

import 'package:flutter/material.dart';

import '../models/installed_app.dart';
import '../services/allowed_apps_service.dart';
import '../services/installed_apps_bridge.dart';
import '../widgets/toggle_dot.dart';

/// Lets the user pick which apps stay reachable during a detox lock
/// session -- everything else still pulls them back to the lock screen.
/// One global list, shared by every alarm (see AllowedAppsService).
class AllowedAppsScreen extends StatefulWidget {
  const AllowedAppsScreen({super.key});

  @override
  State<AllowedAppsScreen> createState() => _AllowedAppsScreenState();
}

class _AllowedAppsScreenState extends State<AllowedAppsScreen> {
  static const _installedApps = InstalledAppsBridge();
  static const _allowedApps = AllowedAppsService();

  List<InstalledApp> _apps = [];
  Set<String> _allowed = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final apps = await _installedApps.listLaunchableApps();
    final allowed = await _allowedApps.load();
    if (!mounted) return;
    setState(() {
      _apps = apps;
      _allowed = allowed;
      _loading = false;
    });
  }

  Future<void> _toggle(String packageName, bool value) async {
    setState(() {
      if (value) {
        _allowed = {..._allowed, packageName};
      } else {
        _allowed = _allowed.where((p) => p != packageName).toSet();
      }
    });
    await _allowedApps.save(_allowed);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dividerColor = scheme.onSurface.withValues(alpha: 0.15);

    return Scaffold(
      appBar: AppBar(title: const Text('Allowed Apps')),
      body: SafeArea(
        child: _loading
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      'These apps stay reachable during a locked session -- '
                      'everything else pulls you back.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  if (_apps.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        "Couldn't load installed apps.",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: _apps.length,
                        itemBuilder: (context, index) {
                          final app = _apps[index];
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: dividerColor),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    app.label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                ),
                                ToggleDot(
                                  value: _allowed.contains(app.packageName),
                                  seed: app.packageName.hashCode,
                                  onChanged: (value) =>
                                      _toggle(app.packageName, value),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
