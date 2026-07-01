import 'daily_usage_analysis.dart';
import 'smartphone_usage_episode.dart';
import 'usage_event.dart';

const Duration _continuityThreshold = Duration(seconds: 5);

class UsageEpisodeAnalyzer {
  const UsageEpisodeAnalyzer();

  DailyUsageAnalysis analyzeDay({
    required DateTime day,
    required Iterable<UsageEvent> events,
  }) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final sortedEvents = events.toList()
      ..sort((left, right) {
        final timeComparison = left.timestamp.compareTo(right.timestamp);
        if (timeComparison != 0) return timeComparison;
        return _eventPriority(left.kind).compareTo(_eventPriority(right.kind));
      });

    final episodes = <SmartphoneUsageEpisode>[];
    _OpenEpisode? openEpisode;

    for (final event in sortedEvents) {
      switch (event.kind) {
        case UsageEventKind.foreground:
          openEpisode = _handleForeground(openEpisode, event, episodes);
        case UsageEventKind.background:
          if (openEpisode case final current?
              when current.packageName == event.packageName) {
            current.noteBackground(event.timestamp);
          }
        case UsageEventKind.unlock ||
            UsageEventKind.screenInteractive ||
            UsageEventKind.screenNonInteractive:
          if (event.kind == UsageEventKind.screenNonInteractive) {
            openEpisode = _closeForScreenOff(
              openEpisode,
              event.timestamp,
              episodes,
            );
          }
      }
    }

    final committed = openEpisode?.finalize();
    if (committed != null && _isSameCivilDay(committed.startedAt, dayStart)) {
      episodes.add(committed);
    }

    episodes.sort((left, right) => left.startedAt.compareTo(right.startedAt));

    return DailyUsageAnalysis(
      dayStart: dayStart,
      episodes: episodes
          .where((episode) => _isSameCivilDay(episode.startedAt, dayStart))
          .toList(),
      unlockCount: sortedEvents
          .where(
            (event) =>
                event.kind == UsageEventKind.unlock &&
                _isSameCivilDay(event.timestamp, dayStart),
          )
          .length,
    );
  }

  _OpenEpisode? _handleForeground(
    _OpenEpisode? openEpisode,
    UsageEvent event,
    List<SmartphoneUsageEpisode> episodes,
  ) {
    final packageName = event.packageName;
    if (packageName == null || packageName.isEmpty) {
      return openEpisode;
    }

    if (openEpisode == null) {
      return _OpenEpisode(
        packageName: packageName,
        appName: event.appName ?? packageName,
        startedAt: event.timestamp,
      );
    }

    if (openEpisode.packageName == packageName) {
      if (!openEpisode.isPaused) {
        return openEpisode;
      }

      if (openEpisode.canResumeAt(event.timestamp)) {
        openEpisode.resume(event.timestamp);
        return openEpisode;
      }

      final committed = openEpisode.finalize(endTime: event.timestamp);
      if (committed != null) {
        episodes.add(committed);
      }

      return _OpenEpisode(
        packageName: packageName,
        appName: event.appName ?? openEpisode.appName,
        startedAt: event.timestamp,
      );
    }

    final committed = openEpisode.finalize(endTime: event.timestamp);
    if (committed != null) {
      episodes.add(committed);
    }

    return _OpenEpisode(
      packageName: packageName,
      appName: event.appName ?? packageName,
      startedAt: event.timestamp,
    );
  }

  _OpenEpisode? _closeForScreenOff(
    _OpenEpisode? openEpisode,
    DateTime timestamp,
    List<SmartphoneUsageEpisode> episodes,
  ) {
    if (openEpisode == null) {
      return null;
    }

    final committed = openEpisode.finalize(endTime: timestamp);
    if (committed != null) {
      episodes.add(committed);
    }
    return null;
  }

  bool _isSameCivilDay(DateTime value, DateTime dayStart) =>
      value.year == dayStart.year &&
      value.month == dayStart.month &&
      value.day == dayStart.day;

  int _eventPriority(UsageEventKind kind) => switch (kind) {
    UsageEventKind.background || UsageEventKind.screenNonInteractive => 0,
    UsageEventKind.foreground ||
    UsageEventKind.unlock ||
    UsageEventKind.screenInteractive => 1,
  };
}

class _OpenEpisode {
  _OpenEpisode({
    required this.packageName,
    required this.appName,
    required this.startedAt,
  }) : _segmentStart = startedAt;

  final String packageName;
  final String appName;
  final DateTime startedAt;
  DateTime _segmentStart;
  DateTime? _pausedAt;
  Duration _activeDuration = Duration.zero;

  bool get isPaused => _pausedAt != null;

  bool canResumeAt(DateTime timestamp) {
    if (_pausedAt == null) return false;
    final pauseDuration = timestamp.difference(_pausedAt!);
    return !pauseDuration.isNegative && pauseDuration <= _continuityThreshold;
  }

  void noteBackground(DateTime timestamp) {
    if (_pausedAt != null) return;
    if (timestamp.isBefore(_segmentStart)) return;
    _activeDuration += timestamp.difference(_segmentStart);
    _pausedAt = timestamp;
  }

  void resume(DateTime timestamp) {
    _segmentStart = timestamp;
    _pausedAt = null;
  }

  SmartphoneUsageEpisode? finalize({DateTime? endTime}) {
    final effectiveEnd = _pausedAt ?? endTime;
    if (effectiveEnd == null) {
      return null;
    }

    if (_pausedAt == null) {
      if (effectiveEnd.isAfter(_segmentStart)) {
        _activeDuration += effectiveEnd.difference(_segmentStart);
      }
    }

    if (_activeDuration <= Duration.zero) {
      return null;
    }

    return SmartphoneUsageEpisode(
      packageName: packageName,
      appName: appName,
      startedAt: startedAt,
      endedAt: effectiveEnd,
      duration: _activeDuration,
    );
  }
}
