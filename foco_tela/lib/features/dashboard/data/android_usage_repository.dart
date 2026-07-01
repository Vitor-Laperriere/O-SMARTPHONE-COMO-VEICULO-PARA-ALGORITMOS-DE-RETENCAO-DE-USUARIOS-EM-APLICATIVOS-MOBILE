import 'dart:io' show Platform;
import 'package:flutter/services.dart';

import '../domain/daily_usage_analysis.dart';
import '../domain/usage_episode_analyzer.dart';
import '../domain/usage_event.dart';
import '../domain/usage_repository.dart';

class AndroidUsageRepository implements UsageRepository {
  AndroidUsageRepository({
    MethodChannel channel = const MethodChannel('com.foco_tela/usage_stats'),
    UsageEpisodeAnalyzer analyzer = const UsageEpisodeAnalyzer(),
    bool Function()? isAndroid,
  }) : _channel = channel,
       _analyzer = analyzer,
       _isAndroid = isAndroid ?? (() => Platform.isAndroid);

  static const _contractVersion = 2;
  final MethodChannel _channel;
  final UsageEpisodeAnalyzer _analyzer;
  final bool Function() _isAndroid;

  @override
  Future<DailyUsageAnalysis> getAnalysisForDay(DateTime day) async {
    if (!_isAndroid()) {
      throw UnsupportedError('Uso real só é suportado no Android.');
    }

    final dayStart = DateTime(day.year, day.month, day.day);
    // A full following civil day is an explicit look-ahead window for episodes
    // that start before midnight and end on the next day.
    final queryEnd = DateTime(day.year, day.month, day.day + 2);
    final expectedStartMillis = dayStart.millisecondsSinceEpoch;
    final expectedEndMillis = queryEnd.millisecondsSinceEpoch;

    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getUsageEventsForInterval',
      <String, Object>{
        'startTimeMillis': expectedStartMillis,
        'endTimeMillis': expectedEndMillis,
      },
    );

    if (result == null) {
      throw Exception('Retorno nulo do nativo.');
    }

    switch (result) {
      case {
        'contractVersion': _contractVersion,
        'intervalStartMillis': final int actualStartMillis,
        'intervalEndMillis': final int actualEndMillis,
        'events': final List<dynamic> rawEvents,
      }:
        if (actualStartMillis != expectedStartMillis ||
            actualEndMillis != expectedEndMillis) {
          throw Exception(
            'O Android respondeu com um intervalo diferente do solicitado.',
          );
        }
        final events = rawEvents
            .map(
              (raw) => UsageEvent.fromContract(
                Map<Object?, Object?>.from(raw as Map),
              ),
            )
            .toList();
        return _analyzer.analyzeDay(day: dayStart, events: events);
      case {'contractVersion': final int version}:
        throw Exception('Versão do contrato de uso não suportada: $version.');
      default:
        throw Exception('Resposta inválida do canal de eventos de uso.');
    }
  }
}

/// Expõe indisponibilidade fora do Android sem fabricar dados de uso.
class UnsupportedUsageRepository implements UsageRepository {
  @override
  Future<DailyUsageAnalysis> getAnalysisForDay(DateTime day) async {
    throw UnsupportedError(
      'Dados de uso reais só estão disponíveis no Android.',
    );
  }
}
