import 'package:flutter_test/flutter_test.dart';

import 'package:foco_tela/features/dashboard/domain/coverage_status.dart';
import 'package:foco_tela/features/dashboard/domain/scientific_traceability.dart';
import 'package:foco_tela/features/dashboard/domain/trend_interpretation.dart';

void main() {
  test('interpretação de tendência é determinística e versionada', () {
    const catalog = TrendInterpretationCatalog();
    final traceability = _traceability();

    final first = catalog.interpret(
      type: TrendInterpretationType.activeTimeIncreased,
      traceability: traceability,
    );
    final second = catalog.interpret(
      type: TrendInterpretationType.activeTimeIncreased,
      traceability: traceability,
    );

    expect(first.catalogVersion, '2026-06-23-v2');
    expect(first.shortExplanation, second.shortExplanation);
    expect(first.tccReading, second.tccReading);
    expect(first.owlTerms, contains('ScreenTime'));
    expect(first.traceability.isComplete, isTrue);
  });

  test('catálogo não usa linguagem diagnóstica ou causal indevida', () {
    const catalog = TrendInterpretationCatalog();
    final allText = TrendInterpretationType.values
        .map(
          (type) =>
              catalog.interpret(type: type, traceability: _traceability()),
        )
        .expand(
          (interpretation) => [
            interpretation.shortExplanation,
            interpretation.tccReading,
            interpretation.caution,
          ],
        )
        .join(' ')
        .toLowerCase();

    expect(allText, isNot(contains('diagnóstico automático')));
    expect(allText, isNot(contains('vício')));
    expect(allText, isNot(contains('prova causal')));
  });
}

ScientificTraceability _traceability() => const ScientificTraceability(
  metric: 'tempo_ativo',
  value: '50',
  unit: 'minutos',
  period: '7 dias',
  coverageStatus: CoverageStatus.partial,
  signalOrState: 'HighScreenTime',
  thresholdOrWeight: '4 horas/dia',
  configurationVersion: '2026-06-21-v1',
  catalogVersion: 'catalog-test-v1',
  owlIri: 'urn:test:owl#ScreenTime',
  caution: 'Leitura exploratória, não diagnóstica.',
);
