import 'package:flutter_test/flutter_test.dart';

import 'package:foco_tela/features/dashboard/domain/usage_episode_analyzer.dart';
import 'package:foco_tela/features/dashboard/domain/usage_event.dart';

void main() {
  const analyzer = UsageEpisodeAnalyzer();

  test('mantém o mesmo episódio quando o mesmo app retorna em 4 segundos', () {
    final analysis = analyzer.analyzeDay(
      day: DateTime(2026, 6, 21),
      events: [
        _event(2026, 6, 21, 10, 0, 0, UsageEventKind.foreground, 'app.one'),
        _event(2026, 6, 21, 10, 0, 10, UsageEventKind.background, 'app.one'),
        _event(2026, 6, 21, 10, 0, 14, UsageEventKind.foreground, 'app.one'),
        _event(2026, 6, 21, 10, 0, 20, UsageEventKind.background, 'app.one'),
      ],
    );

    expect(analysis.episodes, hasLength(1));
    final episode = analysis.episodes.single;
    expect(episode.packageName, 'app.one');
    expect(episode.startedAt, DateTime(2026, 6, 21, 10));
    expect(episode.endedAt, DateTime(2026, 6, 21, 10, 0, 20));
    expect(episode.duration, const Duration(seconds: 16));
  });

  test('mantém o mesmo episódio no limite inclusivo de 5 segundos', () {
    final analysis = analyzer.analyzeDay(
      day: DateTime(2026, 6, 21),
      events: [
        _event(2026, 6, 21, 10, 0, 0, UsageEventKind.foreground, 'app.one'),
        _event(2026, 6, 21, 10, 0, 10, UsageEventKind.background, 'app.one'),
        _event(2026, 6, 21, 10, 0, 15, UsageEventKind.foreground, 'app.one'),
        _event(2026, 6, 21, 10, 0, 20, UsageEventKind.background, 'app.one'),
      ],
    );

    expect(analysis.episodes, hasLength(1));
    expect(analysis.episodes.single.duration, const Duration(seconds: 15));
  });

  test('abre novo episódio quando o mesmo app retorna em 6 segundos', () {
    final analysis = analyzer.analyzeDay(
      day: DateTime(2026, 6, 21),
      events: [
        _event(2026, 6, 21, 11, 0, 0, UsageEventKind.foreground, 'app.one'),
        _event(2026, 6, 21, 11, 0, 10, UsageEventKind.background, 'app.one'),
        _event(2026, 6, 21, 11, 0, 16, UsageEventKind.foreground, 'app.one'),
        _event(2026, 6, 21, 11, 0, 20, UsageEventKind.background, 'app.one'),
      ],
    );

    expect(analysis.episodes, hasLength(2));
    expect(analysis.episodes.first.duration, const Duration(seconds: 10));
    expect(analysis.episodes.last.duration, const Duration(seconds: 4));
  });

  test('outro app em foreground encerra o episódio imediatamente', () {
    final analysis = analyzer.analyzeDay(
      day: DateTime(2026, 6, 21),
      events: [
        _event(2026, 6, 21, 13, 0, 0, UsageEventKind.foreground, 'app.one'),
        _event(2026, 6, 21, 13, 0, 30, UsageEventKind.foreground, 'app.two'),
        _event(2026, 6, 21, 13, 1, 0, UsageEventKind.background, 'app.two'),
      ],
    );

    expect(analysis.episodes, hasLength(2));
    expect(analysis.episodes.first.packageName, 'app.one');
    expect(analysis.episodes.first.endedAt, DateTime(2026, 6, 21, 13, 0, 30));
    expect(analysis.episodes.first.duration, const Duration(seconds: 30));
  });

  test('tela não interativa encerra o episódio imediatamente', () {
    final analysis = analyzer.analyzeDay(
      day: DateTime(2026, 6, 21),
      events: [
        _event(2026, 6, 21, 14, 0, 0, UsageEventKind.foreground, 'app.one'),
        _deviceEvent(
          2026,
          6,
          21,
          14,
          2,
          0,
          UsageEventKind.screenNonInteractive,
        ),
      ],
    );

    expect(analysis.episodes, hasLength(1));
    expect(analysis.episodes.single.endedAt, DateTime(2026, 6, 21, 14, 2));
    expect(analysis.episodes.single.duration, const Duration(minutes: 2));
  });

  test('foreground duplicado do mesmo app não fragmenta o episódio', () {
    final analysis = analyzer.analyzeDay(
      day: DateTime(2026, 6, 21),
      events: [
        _event(2026, 6, 21, 15, 0, 0, UsageEventKind.foreground, 'app.one'),
        _event(2026, 6, 21, 15, 0, 5, UsageEventKind.foreground, 'app.one'),
        _event(2026, 6, 21, 15, 0, 10, UsageEventKind.background, 'app.one'),
      ],
    );

    expect(analysis.episodes, hasLength(1));
    expect(analysis.episodes.single.duration, const Duration(seconds: 10));
  });

  test('ignora fragmento sem início e episódio sem término confiável', () {
    final analysis = analyzer.analyzeDay(
      day: DateTime(2026, 6, 21),
      events: [
        _event(2026, 6, 21, 12, 5, 0, UsageEventKind.background, 'app.one'),
        _event(2026, 6, 21, 12, 10, 0, UsageEventKind.foreground, 'app.one'),
      ],
    );

    expect(analysis.episodes, isEmpty);
  });

  test('preserva um episódio que atravessa a meia-noite no dia de início', () {
    final analysis = analyzer.analyzeDay(
      day: DateTime(2026, 6, 21),
      events: [
        _event(2026, 6, 21, 23, 50, 0, UsageEventKind.foreground, 'app.one'),
        _event(2026, 6, 22, 0, 20, 0, UsageEventKind.background, 'app.one'),
      ],
    );

    expect(analysis.episodes, hasLength(1));
    final episode = analysis.episodes.single;
    expect(episode.startedAt, DateTime(2026, 6, 21, 23, 50));
    expect(episode.endedAt, DateTime(2026, 6, 22, 0, 20));
    expect(episode.duration, const Duration(minutes: 30));
  });
}

UsageEvent _event(
  int year,
  int month,
  int day,
  int hour,
  int minute,
  int second,
  UsageEventKind kind,
  String packageName,
) {
  return UsageEvent(
    timestamp: DateTime(year, month, day, hour, minute, second),
    kind: kind,
    packageName: packageName,
    appName: packageName,
  );
}

UsageEvent _deviceEvent(
  int year,
  int month,
  int day,
  int hour,
  int minute,
  int second,
  UsageEventKind kind,
) {
  return UsageEvent(
    timestamp: DateTime(year, month, day, hour, minute, second),
    kind: kind,
  );
}
