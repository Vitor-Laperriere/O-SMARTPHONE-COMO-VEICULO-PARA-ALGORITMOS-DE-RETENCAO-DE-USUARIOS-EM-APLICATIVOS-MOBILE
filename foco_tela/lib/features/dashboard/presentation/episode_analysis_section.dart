import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../assistive_action/domain/assistive_settings.dart';
import '../../assistive_action/presentation/assistive_action_section.dart';
import '../../catalog/domain/app_catalog.dart';
import '../domain/behavioral_signal_calibration.dart';
import '../domain/coverage_status.dart';
import '../domain/episode_analysis.dart';

class EpisodeAnalysisSection extends StatelessWidget {
  const EpisodeAnalysisSection({super.key, required this.result});

  final EpisodeAnalysisResult? result;

  @override
  Widget build(BuildContext context) {
    return switch (result) {
      null => const _AnalysisStatusCard(
        icon: Icons.info_outline,
        title: 'Análise do episódio',
        message: 'O resultado derivado deste episódio não está disponível.',
      ),
      UnclassifiedEpisodeAnalysis result => _UnclassifiedAnalysisCard(
        result: result,
      ),
      ClassifiedEpisodeAnalysis result => _ClassifiedAnalysisCard(
        result: result,
      ),
    };
  }
}

class _ClassifiedAnalysisCard extends StatelessWidget {
  const _ClassifiedAnalysisCard({required this.result});

  final ClassifiedEpisodeAnalysis result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final explanation = result.patternExplanation;

    return Card(
      key: const ValueKey('episode-analysis'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Análise do episódio', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              _analysisStateLabel(result.state),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _AnalysisValueRow(
              label: 'score_sinais',
              value:
                  '${result.behavioralScore.value.toStringAsFixed(1)} '
                  '(${_behavioralRangeLabel(result.behavioralScore.range)})',
            ),
            _AnalysisValueRow(
              label: 'Força contextual de retenção',
              value: result.context.isAvailable
                  ? '${result.context.matrixValue.toStringAsFixed(1)} '
                        '(${_contextRangeLabel(result.context.range)})'
                  : 'Contexto indisponível',
            ),
            const SizedBox(height: 16),
            Text(
              'Contribuições comportamentais',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final signal in result.signalObservations) ...[
              _SignalCard(signal: signal),
              const SizedBox(height: 8),
            ],
            Text(
              'Os sinais diários compartilhados descrevem o dia observado e '
              'não são atribuídos causalmente a este aplicativo.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text('Decomposição contextual', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              result.context.isAvailable
                  ? 'Soma bruta ${result.context.rawValue.toStringAsFixed(1)} · '
                        'valor na matriz ${result.context.matrixValue.toStringAsFixed(1)} · '
                        'teto ${result.context.cap.toStringAsFixed(1)}'
                  : 'Não há contexto catalogado verificável para calcular esta dimensão.',
            ),
            if (result.context.contributions.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final contribution in result.context.contributions) ...[
                _ContextContributionCard(contribution: contribution),
                const SizedBox(height: 8),
              ],
            ],
            if (explanation != null) ...[
              const SizedBox(height: 16),
              Text('PatternExplanation', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(explanation.summary),
              const SizedBox(height: 8),
              Text(explanation.caveat, style: theme.textTheme.bodySmall),
            ],
            ...switch (result.state) {
              AnalysisState.convergentIntensifiedRetentionSignals => [
                const SizedBox(height: 16),
                AssistiveActionSection(
                  packageName: result.episode.packageName,
                  repository: context.read<AssistiveSettingsRepository>(),
                ),
              ],
              AnalysisState.contextUnavailable ||
              AnalysisState.insufficientSignals ||
              AnalysisState.signalsForReview => const <Widget>[],
            },
            const SizedBox(height: 16),
            Text('Rastreabilidade', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _AnalysisValueRow(
              label: 'Cobertura',
              value:
                  '${result.coverageStatus.label}'
                  '${result.isProvisional ? ' · resultado provisório' : ''}',
            ),
            _AnalysisValueRow(
              label: 'Configuração',
              value: result.versions.calibrationVersion,
            ),
            _AnalysisValueRow(
              label: 'Catálogo',
              value: result.versions.catalogVersion,
            ),
            _AnalysisValueRow(
              label: 'Contrato OWL',
              value:
                  '${result.versions.owxVersion} · '
                  '${result.versions.owxHash} · '
                  '${result.versions.owxCommit}\n'
                  '${result.versions.owxIri}',
            ),
          ],
        ),
      ),
    );
  }
}

class _UnclassifiedAnalysisCard extends StatelessWidget {
  const _UnclassifiedAnalysisCard({required this.result});

  final UnclassifiedEpisodeAnalysis result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('episode-analysis-unavailable'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Análise do episódio', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Classificação não calculada',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'A cobertura encerrada deste dia é parcial. O episódio observado '
              'permanece visível, mas sinais diários incompletos não alimentam '
              'a matriz.',
            ),
            const SizedBox(height: 12),
            _AnalysisValueRow(
              label: 'Cobertura',
              value: result.coverageStatus.label,
            ),
            _AnalysisValueRow(
              label: 'Configuração',
              value: result.versions.calibrationVersion,
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalCard extends StatelessWidget {
  const _SignalCard({required this.signal});

  final BehavioralSignalObservation signal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeLabel = switch (signal.isActive) {
      true => 'ativo',
      false => 'inativo',
      null => 'indisponível',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_signalLabel(signal.kind), style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            '${_signalScopeLabel(signal.scope)} · $activeLabel · '
            'peso ${signal.weight.toStringAsFixed(1)} · contribuição '
            '${signal.contribution.toStringAsFixed(1)}',
          ),
          const SizedBox(height: 4),
          Text(
            'Observado: ${signal.observedValue} · limiar '
            '${signal.threshold.value} ${signal.threshold.unit}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ContextContributionCard extends StatelessWidget {
  const _ContextContributionCard({required this.contribution});

  final ContextualRetentionContribution contribution;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(contribution.label, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'IRI ${contribution.iri} · confiança '
            '${contribution.confidence.label} · peso '
            '${contribution.weight.toStringAsFixed(1)}',
          ),
          const SizedBox(height: 8),
          for (final evidence in contribution.evidence)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${evidence.id}: ${evidence.supportedStatement}',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _AnalysisValueRow extends StatelessWidget {
  const _AnalysisValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 176,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _AnalysisStatusCard extends StatelessWidget {
  const _AnalysisStatusCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text('$title\n$message')),
          ],
        ),
      ),
    );
  }
}

String _analysisStateLabel(AnalysisState state) => switch (state) {
  AnalysisState.contextUnavailable => 'Contexto indisponível',
  AnalysisState.insufficientSignals => 'Sem sinais suficientes',
  AnalysisState.signalsForReview => 'Sinais para revisão',
  AnalysisState.convergentIntensifiedRetentionSignals =>
    'Sinais convergentes de retenção intensificada',
};

String _signalLabel(BehavioralSignalKind kind) => switch (kind) {
  BehavioralSignalKind.longSessionDuration => 'LongSessionDuration',
  BehavioralSignalKind.highScreenTime => 'HighScreenTime',
  BehavioralSignalKind.frequentUnlocking => 'FrequentUnlocking',
};

String _signalScopeLabel(SignalScope scope) => switch (scope) {
  SignalScope.episode => 'sinal do episódio',
  SignalScope.sharedDay => 'sinal diário compartilhado',
};

String _behavioralRangeLabel(BehavioralScoreRange range) => switch (range) {
  BehavioralScoreRange.low => 'baixa',
  BehavioralScoreRange.medium => 'média',
  BehavioralScoreRange.high => 'alta',
};

String _contextRangeLabel(ContextualStrengthRange range) => switch (range) {
  ContextualStrengthRange.absent => 'ausente',
  ContextualStrengthRange.low => 'baixa',
  ContextualStrengthRange.medium => 'média',
  ContextualStrengthRange.high => 'alta',
};
