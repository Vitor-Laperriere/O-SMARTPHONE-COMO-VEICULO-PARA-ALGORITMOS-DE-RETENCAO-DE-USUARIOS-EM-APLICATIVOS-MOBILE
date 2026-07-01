import 'scientific_traceability.dart';

enum TrendInterpretationType {
  activeTimeIncreased,
  activeTimeReduced,
  episodeCountIncreased,
  episodeCountReduced,
  recurringApp,
  concentratedUse,
  notificationExposureChanged,
  insufficientCoverage,
}

class TrendInterpretation {
  const TrendInterpretation({
    required this.type,
    required this.catalogVersion,
    required this.shortExplanation,
    required this.tccReading,
    required this.owlTerms,
    required this.caution,
    required this.traceability,
  });

  final TrendInterpretationType type;
  final String catalogVersion;
  final String shortExplanation;
  final String tccReading;
  final List<String> owlTerms;
  final String caution;
  final ScientificTraceability traceability;
}

class TrendInterpretationCatalog {
  const TrendInterpretationCatalog({this.version = '2026-06-23-v2'});

  final String version;

  TrendInterpretation interpret({
    required TrendInterpretationType type,
    required ScientificTraceability traceability,
  }) {
    final template = _templateFor(type);
    return TrendInterpretation(
      type: type,
      catalogVersion: version,
      shortExplanation: template.shortExplanation,
      tccReading: template.tccReading,
      owlTerms: template.owlTerms,
      caution: template.caution,
      traceability: traceability,
    );
  }

  _TrendTemplate _templateFor(TrendInterpretationType type) => switch (type) {
    TrendInterpretationType.activeTimeIncreased => const _TrendTemplate(
      shortExplanation: 'O tempo ativo observado aumentou nesta janela.',
      tccReading:
          'O TCC interpreta aumento de duração como variação descritiva de '
          'exposição ao smartphone, não como conclusão clínica.',
      owlTerms: ['ScreenTime', 'AppUsageDuration', 'UsageMetric'],
      caution:
          'A tendência depende da cobertura observada e não demonstra causa.',
    ),
    TrendInterpretationType.activeTimeReduced => const _TrendTemplate(
      shortExplanation: 'O tempo ativo observado reduziu nesta janela.',
      tccReading:
          'O TCC interpreta redução como variação intrapessoal descritiva, '
          'sem afirmar melhora clínica.',
      owlTerms: ['ScreenTime', 'UsageMetric'],
      caution: 'Redução de duração não prova mudança de bem-estar ou intenção.',
    ),
    TrendInterpretationType.episodeCountIncreased => const _TrendTemplate(
      shortExplanation: 'A quantidade de episódios observados aumentou.',
      tccReading:
          'Mais episódios podem indicar fragmentação de uso e retorno '
          'recorrente ao dispositivo.',
      owlTerms: ['UsageEpisode', 'SmartphoneUsageEpisode'],
      caution: 'A contagem não informa, sozinha, prejuízo ou causalidade.',
    ),
    TrendInterpretationType.episodeCountReduced => const _TrendTemplate(
      shortExplanation: 'A quantidade de episódios observados reduziu.',
      tccReading:
          'Menos episódios podem indicar menor fragmentação observada na '
          'janela selecionada.',
      owlTerms: ['UsageEpisode', 'SmartphoneUsageEpisode'],
      caution: 'A redução não equivale a diagnóstico ou avaliação clínica.',
    ),
    TrendInterpretationType.recurringApp => const _TrendTemplate(
      shortExplanation: 'Um aplicativo apareceu de forma recorrente.',
      tccReading:
          'Recorrência por dias cobertos ajuda a diferenciar presença '
          'frequente de uso concentrado em poucos episódios.',
      owlTerms: ['App', 'AppUsageDuration', 'UsageEpisode'],
      caution: 'Recorrência não prova intenção institucional específica.',
    ),
    TrendInterpretationType.concentratedUse => const _TrendTemplate(
      shortExplanation: 'O uso ficou concentrado em poucos aplicativos.',
      tccReading:
          'Concentração pode orientar revisão do contexto técnico e '
          'semântico desses aplicativos.',
      owlTerms: ['App', 'TechnicalMechanism', 'InstitutionalIntention'],
      caution: 'Concentração não classifica o aplicativo como problemático.',
    ),
    TrendInterpretationType.notificationExposureChanged => const _TrendTemplate(
      shortExplanation: 'A exposição observada a notificações variou.',
      tccReading:
          'Notificações são métrica passiva de exposição quando o Android '
          'permite observação real.',
      owlTerms: ['NotificationCount', 'HighNotificationExposure'],
      caution:
          'Indisponibilidade de notificação não é zero e o conteúdo textual '
          'não alimenta a análise da V2.',
    ),
    TrendInterpretationType.insufficientCoverage => const _TrendTemplate(
      shortExplanation: 'A cobertura da janela é insuficiente para comparação.',
      tccReading:
          'O TCC exige separar lacuna observacional de ausência de uso.',
      owlTerms: ['UsageMetric', 'PatternExplanation'],
      caution: 'Dados ausentes não devem ser tratados como uso zero.',
    ),
  };
}

class _TrendTemplate {
  const _TrendTemplate({
    required this.shortExplanation,
    required this.tccReading,
    required this.owlTerms,
    required this.caution,
  });

  final String shortExplanation;
  final String tccReading;
  final List<String> owlTerms;
  final String caution;
}
