import 'smartphone_usage_episode.dart';

class DailyUsageAnalysis {
  DailyUsageAnalysis({
    required this.dayStart,
    required List<SmartphoneUsageEpisode> episodes,
    required this.unlockCount,
  }) : episodes = List.unmodifiable(episodes);

  final DateTime dayStart;
  final List<SmartphoneUsageEpisode> episodes;
  final int unlockCount;

  Duration get totalUsage => episodes.fold(
    Duration.zero,
    (total, episode) => total + episode.duration,
  );
}
