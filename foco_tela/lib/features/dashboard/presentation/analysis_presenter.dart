import '../../catalog/domain/app_catalog.dart';
import '../domain/analysis_window.dart';
import '../domain/behavioral_signal_calibration.dart';
import '../domain/daily_usage_summary.dart';
import '../domain/episode_analysis.dart';
import '../domain/score_total.dart';

class AnalysisPagePresenter {
  const AnalysisPagePresenter();

  AnalysisPageData present(WeeklyUsageDashboard dashboard) {
    return AnalysisPageData(
      selectedWindow: dashboard.window,
      generatedAt: dashboard.generatedAt,
      summary: _summary(dashboard),
      observedConcepts: _observedConcepts(dashboard),
      periodChange: _periodChange(dashboard),
    );
  }

  AnalysisWindowSummary _summary(WeeklyUsageDashboard dashboard) {
    final availableDays = dashboard.days
        .where((day) => day.coverageStatus.isAvailable)
        .length;
    final metrics = [
      AnalysisMetric(
        label: 'Tempo de tela',
        value: _formatDuration(dashboard.totalUsage),
      ),
      AnalysisMetric(
        label: 'Episódios',
        value: '${dashboard.totalEpisodeCount}',
      ),
      if (dashboard.totalNotificationCount case final int count)
        AnalysisMetric(label: 'Notificações', value: '$count'),
    ].take(3).toList(growable: false);

    return AnalysisWindowSummary(
      title: 'Resumo da janela',
      headline: _summaryHeadline(dashboard),
      coverageLabel:
          'Cobertura: $availableDays de ${dashboard.days.length} dias carregados',
      metrics: metrics,
      notificationLabel: dashboard.totalNotificationCount == null
          ? dashboard.notificationAvailability.label
          : null,
    );
  }

  String _summaryHeadline(WeeklyUsageDashboard dashboard) {
    if (!dashboard.hasAnyAvailableDay) {
      return 'Ainda não há dados suficientes para comparar esta janela.';
    }
    final comparison = dashboard.comparison;
    if (comparison.isAvailable && comparison.activeTimeMinutes != null) {
      final delta = comparison.activeTimeMinutes!.absoluteDelta;
      if (delta > 0) {
        return 'O tempo de tela observado aumentou em relação à janela anterior.';
      }
      if (delta < 0) {
        return 'O tempo de tela observado reduziu em relação à janela anterior.';
      }
    }
    return 'A janela mostra uso observado para revisão longitudinal.';
  }

  List<ObservedConcept> _observedConcepts(WeeklyUsageDashboard dashboard) {
    final concepts = <String, ObservedConcept>{};
    for (final analysis in dashboard.days.expand(
      (day) => day.episodeAnalyses,
    )) {
      for (final signal in analysis.signalObservations) {
        if (signal.isActive != true) continue;
        concepts.putIfAbsent(
          'signal-${signal.kind.name}',
          () => ObservedConcept(
            category: 'Sinal comportamental',
            label: signal.kind.simpleLabel,
            detail:
                '${signal.observedValue}; limiar ${signal.threshold.value} ${signal.threshold.unit}',
            iri: signal.kind.name,
            evidence: 'observado localmente',
            scope: signal.scope.name,
            version: signal.threshold.version,
            caution:
                'Sinal descritivo; não indica diagnóstico nem causalidade.',
          ),
        );
      }
      if (analysis case ClassifiedEpisodeAnalysis classified) {
        for (final contribution in classified.context.contributions) {
          concepts.putIfAbsent(
            'technical-${contribution.iri}',
            () => ObservedConcept(
              category: 'Mecanismo técnico',
              label: contribution.label,
              detail: 'Evidência ${contribution.confidence.label}',
              iri: contribution.iri,
              evidence: contribution.evidence.map((item) => item.id).join(', '),
              scope: contribution.evidence.isEmpty
                  ? 'indisponível'
                  : contribution.evidence.first.scope,
              version: classified.versions.catalogVersion,
              caution:
                  'Mecanismo catalogado é contexto exploratório, não prova causal.',
            ),
          );
        }
        for (final association in classified.scoreTotal.curatedAssociations) {
          concepts.putIfAbsent(
            '${association.kind.value}-${association.iri}',
            () => ObservedConcept(
              category: association.kind.label,
              label: association.label,
              detail: 'Evidência ${association.confidence.label}',
              iri: association.iri,
              evidence: association.evidence.map((item) => item.id).join(', '),
              scope: association.scope ?? 'indisponível',
              version: classified.versions.catalogVersion,
              caution: association.caution ?? 'Cautela indisponível.',
            ),
          );
        }
      }
    }
    return concepts.values.take(6).toList(growable: false);
  }

  PeriodChangeSummary _periodChange(WeeklyUsageDashboard dashboard) {
    final classified = dashboard.days
        .expand((day) => day.episodeAnalyses)
        .whereType<ClassifiedEpisodeAnalysis>()
        .toList(growable: false);
    final highRetention = classified
        .where((analysis) => analysis.scoreTotal.band == ScoreTotalBand.high)
        .length;
    final moderateRetention = classified
        .where(
          (analysis) => analysis.scoreTotal.band == ScoreTotalBand.moderate,
        )
        .length;
    if (highRetention > 0 || moderateRetention > 0) {
      return PeriodChangeSummary(
        priority: PeriodChangePriority.retention,
        title: 'Mudanças no período',
        headline:
            'Indícios de retenção aparecem em $highRetention episódio(s) altos e $moderateRetention moderados.',
        detail:
            'A prioridade usa a classificação integrada dos episódios da janela; não cria score longitudinal do usuário.',
        caution:
            'Quando não há período anterior com indícios comparáveis, a leitura permanece descritiva.',
      );
    }

    final comparison = dashboard.comparison;
    if (!comparison.isAvailable) {
      return PeriodChangeSummary(
        priority: PeriodChangePriority.insufficientComparison,
        title: 'Mudanças no período',
        headline:
            comparison.insufficientReason ??
            'Não há comparação suficiente com a janela anterior.',
        detail:
            'Ausência de comparação não é interpretada como melhora, queda ou zero.',
        caution:
            'A leitura depende de cobertura observada e período anterior equivalente.',
      );
    }
    if (comparison.activeTimeMinutes case final activeTime?) {
      return PeriodChangeSummary(
        priority: PeriodChangePriority.screenTime,
        title: 'Mudanças no período',
        headline: 'Tempo de tela: ${_formatMetricComparison(activeTime)}.',
        detail: 'Usado como fallback quando indícios integrados não mudam.',
        caution: 'Percentual é omitido quando a base anterior é zero.',
      );
    }
    if (comparison.episodeCount case final episodes?) {
      return PeriodChangeSummary(
        priority: PeriodChangePriority.episodes,
        title: 'Mudanças no período',
        headline: 'Episódios: ${_formatMetricComparison(episodes)}.',
        detail: 'Usado como fallback após indícios e tempo de tela.',
        caution: 'Comparação apenas descritiva.',
      );
    }
    return const PeriodChangeSummary(
      priority: PeriodChangePriority.insufficientComparison,
      title: 'Mudanças no período',
      headline: 'Não há dados comparáveis suficientes.',
      detail: 'A janela atual permanece disponível para revisão.',
      caution: 'Ausência de comparação não é erro.',
    );
  }
}

class AnalysisPageData {
  const AnalysisPageData({
    required this.selectedWindow,
    required this.generatedAt,
    required this.summary,
    required this.observedConcepts,
    required this.periodChange,
  });

  final AnalysisWindow selectedWindow;
  final DateTime generatedAt;
  final AnalysisWindowSummary summary;
  final List<ObservedConcept> observedConcepts;
  final PeriodChangeSummary periodChange;
}

class AnalysisWindowSummary {
  const AnalysisWindowSummary({
    required this.title,
    required this.headline,
    required this.coverageLabel,
    required this.metrics,
    required this.notificationLabel,
  });

  final String title;
  final String headline;
  final String coverageLabel;
  final List<AnalysisMetric> metrics;
  final String? notificationLabel;
}

class AnalysisMetric {
  const AnalysisMetric({required this.label, required this.value});

  final String label;
  final String value;
}

class ObservedConcept {
  const ObservedConcept({
    required this.category,
    required this.label,
    required this.detail,
    required this.iri,
    required this.evidence,
    required this.scope,
    required this.version,
    required this.caution,
  });

  final String category;
  final String label;
  final String detail;
  final String iri;
  final String evidence;
  final String scope;
  final String version;
  final String caution;
}

enum PeriodChangePriority {
  retention,
  screenTime,
  episodes,
  insufficientComparison,
}

class PeriodChangeSummary {
  const PeriodChangeSummary({
    required this.priority,
    required this.title,
    required this.headline,
    required this.detail,
    required this.caution,
  });

  final PeriodChangePriority priority;
  final String title;
  final String headline;
  final String detail;
  final String caution;
}

extension BehavioralSignalKindSimpleLabel on BehavioralSignalKind {
  String get simpleLabel => switch (this) {
    BehavioralSignalKind.longSessionDuration => 'Sessão longa',
    BehavioralSignalKind.highScreenTime => 'Tempo de tela alto',
    BehavioralSignalKind.frequentUnlocking => 'Desbloqueios frequentes',
  };
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) {
    return minutes == 0 ? '$hours h' : '$hours h $minutes min';
  }
  return '${duration.inMinutes} min';
}

String _formatMetricComparison(WindowMetricComparison comparison) {
  final delta = comparison.absoluteDelta;
  final deltaLabel = delta >= 0 ? '+$delta' : '$delta';
  if (comparison.percentageDelta == null) {
    return '${comparison.current} atuais vs ${comparison.previous} anteriores; diferença $deltaLabel ${comparison.unit}';
  }
  return '${comparison.current} atuais vs ${comparison.previous} anteriores; diferença $deltaLabel ${comparison.unit} (${comparison.percentageDelta!.toStringAsFixed(1)}%)';
}
