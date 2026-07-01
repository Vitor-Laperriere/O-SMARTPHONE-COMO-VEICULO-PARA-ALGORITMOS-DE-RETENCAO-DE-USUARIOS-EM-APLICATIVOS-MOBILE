class SmartphoneUsageEpisode {
  const SmartphoneUsageEpisode({
    required this.packageName,
    required this.appName,
    required this.startedAt,
    required this.endedAt,
    required this.duration,
  });

  final String packageName;
  final String appName;
  final DateTime startedAt;
  final DateTime endedAt;
  final Duration duration;

  String get displayName => appName.isEmpty ? packageName : appName;
}
