/// One launchable app on the device, as reported by the native
/// `morningdetox/apps` channel -- see [InstalledAppsBridge].
class InstalledApp {
  const InstalledApp({required this.packageName, required this.label});

  final String packageName;
  final String label;

  static InstalledApp? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final packageName = raw['packageName'];
    final label = raw['label'];
    if (packageName is! String || label is! String) return null;
    return InstalledApp(packageName: packageName, label: label);
  }
}
