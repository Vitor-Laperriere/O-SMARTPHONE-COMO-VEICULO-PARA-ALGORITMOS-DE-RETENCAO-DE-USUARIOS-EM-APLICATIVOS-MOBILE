import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../dashboard/domain/behavioral_signal_calibration.dart';
import '../../notifications/domain/notification_observation.dart';
import '../../usage_access/domain/usage_access.dart';
import '../domain/privacy_settings_snapshot.dart';
import 'settings_privacy_view_model.dart';

class SettingsPrivacyPage extends StatelessWidget {
  const SettingsPrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsPrivacyViewModel>(
      builder: (context, viewModel, _) => Scaffold(
        appBar: AppBar(title: const Text('Configurações e privacidade')),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final padding = constraints.maxWidth >= 600 ? 32.0 : 16.0;
            return switch (viewModel.state) {
              SettingsPrivacyLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
              SettingsPrivacyLoadError(:final message) => _LoadError(
                message: message,
                onRetry: viewModel.load,
              ),
              SettingsPrivacyReady(:final snapshot) => Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    key: const ValueKey('settings-privacy-list'),
                    padding: EdgeInsets.symmetric(
                      horizontal: padding,
                      vertical: 24,
                    ),
                    children: [
                      _PermissionCard(snapshot: snapshot),
                      const SizedBox(height: 16),
                      _NotificationCollectionCard(
                        snapshot: snapshot,
                        viewModel: viewModel,
                      ),
                      const SizedBox(height: 16),
                      _NotificationContentSettingsCard(
                        snapshot: snapshot,
                        viewModel: viewModel,
                      ),
                      const SizedBox(height: 16),
                      _HeuristicInformationCard(snapshot: snapshot),
                      const SizedBox(height: 16),
                      _ArtifactVersionsCard(snapshot: snapshot),
                      const SizedBox(height: 16),
                      const _PrivacyPolicyCard(),
                      const SizedBox(height: 16),
                      _HistoryDeletionCard(viewModel: viewModel),
                    ],
                  ),
                ),
              ),
            };
          },
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.snapshot});

  final PrivacySettingsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final label = switch (snapshot.usageAccessStatus) {
      UsageAccessStatus.granted => 'Concedida',
      UsageAccessStatus.denied => 'Não concedida',
    };
    return _SettingsCard(
      title: 'Acesso aos dados de uso',
      icon: Icons.lock_clock_outlined,
      children: [
        _ValueRow(label: 'Permissão atual', value: label),
        const Text(
          'O estado é consultado no Android ao abrir esta tela; ausência de '
          'permissão não é apresentada como uso zero.',
        ),
      ],
    );
  }
}

class _NotificationCollectionCard extends StatelessWidget {
  const _NotificationCollectionCard({
    required this.snapshot,
    required this.viewModel,
  });

  final PrivacySettingsSnapshot snapshot;
  final SettingsPrivacyViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final diagnostic = snapshot.notificationDiagnostic;
    final statusLabel = switch (diagnostic.status) {
      NotificationListenerDiagnosticStatus.active => 'Listener ativo',
      NotificationListenerDiagnosticStatus.inactive => 'Listener inativo',
      NotificationListenerDiagnosticStatus.apiUnavailable => 'API indisponível',
      NotificationListenerDiagnosticStatus.readFailure => 'Falha de leitura',
    };
    final observationLabel = switch (diagnostic.readiness) {
      NotificationObservationReadiness.observed => _formatLastObservation(
        diagnostic.lastObservation!,
      ),
      NotificationObservationReadiness.notObservedYet =>
        'Dado ainda não observado. O app aguardará notificações futuras '
            'recebidas depois da habilitação.',
      NotificationObservationReadiness.unavailable =>
        'Indisponível enquanto o listener estiver inativo ou sem suporte.',
    };

    return _SettingsCard(
      title: 'Coleta de notificações',
      icon: Icons.notifications_active_outlined,
      children: [
        _ValueRow(label: 'Estado do listener', value: statusLabel),
        _ValueRow(label: 'Última leitura', value: observationLabel),
        const Text(
          'A contagem usa apenas notificações futuras recebidas pelo Notification '
          'Listener depois da habilitação. Contar notificações não exige '
          'armazenar título ou texto.',
        ),
        if (viewModel.notificationActionMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            viewModel.notificationActionMessage!,
            key: const ValueKey('notification-listener-action-status'),
            style: TextStyle(
              color: viewModel.notificationActionFailed
                  ? Theme.of(context).colorScheme.error
                  : null,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              key: const ValueKey('notification-listener-open-settings'),
              onPressed: viewModel.notificationActionInProgress
                  ? null
                  : viewModel.openNotificationSettings,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Abrir acesso a notificações'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('notification-listener-recheck'),
              onPressed: viewModel.notificationActionInProgress
                  ? null
                  : viewModel.recheckNotificationListener,
              icon: viewModel.notificationActionInProgress
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: const Text('Verificar novamente'),
            ),
          ],
        ),
      ],
    );
  }

  String _formatLastObservation(NotificationLastObservation observation) {
    final date =
        '${observation.observedAt.day.toString().padLeft(2, '0')}/'
        '${observation.observedAt.month.toString().padLeft(2, '0')}/'
        '${observation.observedAt.year}';
    final time =
        '${observation.observedAt.hour.toString().padLeft(2, '0')}:'
        '${observation.observedAt.minute.toString().padLeft(2, '0')}';
    final unit = observation.count == 1 ? 'notificação' : 'notificações';
    return '${observation.packageName} · $date $time · '
        '${observation.count} $unit observadas no dia';
  }
}

class _NotificationContentSettingsCard extends StatelessWidget {
  const _NotificationContentSettingsCard({
    required this.snapshot,
    required this.viewModel,
  });

  final PrivacySettingsSnapshot snapshot;
  final SettingsPrivacyViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final settings = snapshot.notificationContentSettings;
    final authorizedCount = settings.authorizedPackageNames.length;
    final appLabel = authorizedCount == 1
        ? 'app autorizado'
        : 'apps autorizados';
    final statusLabel = settings.enabled
        ? 'Ativado por escolha explícita'
        : 'Desativado por padrão';
    final retentionDays = settings.retention.inDays;
    final observedCount = snapshot.observedPackageNames.length;
    final observedLabel = observedCount == 1
        ? 'app observado'
        : 'apps observados';

    return _SettingsCard(
      key: const ValueKey('notification-content-settings-card'),
      title: 'Conteúdo textual de notificações',
      icon: Icons.mark_chat_unread_outlined,
      children: [
        _ValueRow(label: 'Estado', value: statusLabel),
        _ValueRow(
          label: 'Autorização granular',
          value: '$authorizedCount $appLabel',
        ),
        _ValueRow(label: 'Retenção textual', value: 'até $retentionDays dias'),
        _ValueRow(
          label: 'Apps observados',
          value: '$observedCount $observedLabel',
        ),
        _ValueRow(
          label: 'Visualização',
          value: settings.requiresDeviceAuthenticationForViewing
              ? 'exige autenticação do dispositivo'
              : 'sem autenticação local configurada',
        ),
        Text(
          settings.protectedAtRest && settings.excludedFromBackup
              ? 'Título e texto autorizados ficam em armazenamento separado, protegido localmente e excluído de backup.'
              : 'Título e texto autorizados ficam em armazenamento separado conforme suporte da plataforma.',
        ),
        const SizedBox(height: 8),
        const Text(
          'Esse modo é visual e operacionalmente separado da coleta de notificações: '
          'contar notificações não armazena mensagens, e conteúdo textual não '
          'alimenta métricas, sinais, scores ou classificações.',
        ),
        if (viewModel.contentActionMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            viewModel.contentActionMessage!,
            key: const ValueKey('notification-content-action-status'),
            style: TextStyle(
              color: viewModel.contentActionFailed
                  ? Theme.of(context).colorScheme.error
                  : null,
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('notification-content-authorize-observed'),
          onPressed: viewModel.contentActionInProgress || observedCount == 0
              ? null
              : viewModel.authorizeObservedNotificationContent,
          icon: viewModel.contentActionInProgress
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.playlist_add_check_outlined),
          label: const Text('Autorizar apps observados'),
        ),
      ],
    );
  }
}

class _HeuristicInformationCard extends StatelessWidget {
  const _HeuristicInformationCard({required this.snapshot});

  final PrivacySettingsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      title: 'Heurística e score-sinais',
      icon: Icons.psychology_alt_outlined,
      children: [
        _ValueRow(label: 'Versão', value: snapshot.calibration.version),
        const Text(
          'A configuração é informativa nesta UI. Pesos, limiares, faixas e '
          'matriz permanecem versionados no repositório e não são editáveis no app.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              key: const ValueKey('settings-open-score-signals'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ScoreSignalsExplanationPage(
                    calibration: snapshot.calibration,
                  ),
                ),
              ),
              icon: const Icon(Icons.info_outline),
              label: const Text('Como os sinais são calculados'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('settings-open-heuristic'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => HeuristicConfigurationPage(
                    calibration: snapshot.calibration,
                  ),
                ),
              ),
              icon: const Icon(Icons.rule_outlined),
              label: const Text('Configuração heurística'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ArtifactVersionsCard extends StatelessWidget {
  const _ArtifactVersionsCard({required this.snapshot});

  final PrivacySettingsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      title: 'Versões e contrato semântico',
      icon: Icons.rule_folder_outlined,
      children: [
        _ValueRow(label: 'Catálogo local', value: snapshot.catalogVersion),
        _ValueRow(
          label: 'Configuração heurística',
          value: snapshot.heuristicVersion,
        ),
        _ValueRow(
          label: 'Contrato OWL',
          value:
              '${snapshot.owxVersion} · ${snapshot.owxHash} · '
              '${snapshot.owxCommit}\n${snapshot.owxIri}',
        ),
        const Text(
          'A OWL é uma referência semântica rastreável. A configuração '
          'heurística tem versão própria e é aplicada de forma determinística.',
        ),
      ],
    );
  }
}

class _PrivacyPolicyCard extends StatelessWidget {
  const _PrivacyPolicyCard();

  @override
  Widget build(BuildContext context) {
    return const _SettingsCard(
      title: 'Armazenamento local',
      icon: Icons.phonelink_lock_outlined,
      children: [
        Text(
          'O Foco Tela mantém neste dispositivo apenas histórico derivado: '
          'episódios detalhados por até 30 dias e agregados diários por '
          'aplicativo por até seis meses. Eventos de uso permanecem efêmeros '
          'e não são gravados no banco.',
        ),
        SizedBox(height: 8),
        Text(
          'Conteúdo textual de notificações, quando ativado, é separado, '
          'autorizado por aplicativo e expira em até sete dias. Não há conta, '
          'nuvem, backup remoto ou sincronização. Catálogo e configuração são '
          'artefatos locais estáticos.',
        ),
      ],
    );
  }
}

class ScoreSignalsExplanationPage extends StatelessWidget {
  const ScoreSignalsExplanationPage({super.key, required this.calibration});

  final BehavioralSignalCalibration calibration;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Como os sinais são calculados')),
      body: _SettingsPageBody(
        children: [
          _SettingsCard(
            title: 'score_sinais',
            icon: Icons.analytics_outlined,
            children: [
              const Text(
                'score_sinais resume a intensidade dos sinais observados em um '
                'episódio ou resumo analítico. Ele não é diagnóstico, não mede '
                'uso problemático confirmado e não classifica a pessoa.',
              ),
              const SizedBox(height: 8),
              const Text(
                'A UI principal mostra faixas de intensidade e sinais ativos; o '
                'valor numérico fica na rastreabilidade científica.',
              ),
              const SizedBox(height: 8),
              const Text(
                'NotificationCount continua como métrica observacional separada '
                'na V3 e não altera score_sinais, HighNotificationExposure ou '
                'estado de episódio sem revisão versionada futura.',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            title: 'Sinais ativos',
            icon: Icons.checklist_outlined,
            children: [
              for (final entry in calibration.signalWeights.entries)
                _ValueRow(
                  label: _signalLabel(entry.key),
                  value: 'peso ${entry.value}',
                ),
              const Text(
                'Os pesos são somados apenas quando o sinal correspondente está '
                'ativo. A leitura continua cautelosa e observacional.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HeuristicConfigurationPage extends StatelessWidget {
  const HeuristicConfigurationPage({super.key, required this.calibration});

  final BehavioralSignalCalibration calibration;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuração heurística')),
      body: _SettingsPageBody(
        children: [
          _SettingsCard(
            title: 'Versão e cautelas',
            icon: Icons.verified_outlined,
            children: [
              _ValueRow(label: 'Versão', value: calibration.version),
              _ValueRow(
                label: 'Perfil técnico',
                value: calibration.deviceProfile,
              ),
              Text(calibration.calibrationNotes),
              const SizedBox(height: 8),
              const Text(
                'Esta página não permite editar pesos, limiares, faixas ou matriz. '
                'Alterações exigem configuração versionada, justificativa e registro '
                'de impacto fora da UI.',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            title: 'Pesos dos sinais',
            icon: Icons.scale_outlined,
            children: [
              for (final entry in calibration.signalWeights.entries)
                _ValueRow(
                  label: _signalLabel(entry.key),
                  value: entry.value.toString(),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            title: 'Limiar e unidade',
            icon: Icons.tune_outlined,
            children: [
              for (final threshold in calibration.allThresholds)
                _ValueRow(
                  label: _thresholdLabel(threshold.id),
                  value:
                      '${threshold.value} ${threshold.unit}\n'
                      '${_thresholdKindLabel(threshold.kind)} · ${threshold.justification}',
                ),
              _ValueRow(
                label: 'Teto contextual',
                value:
                    '${calibration.contextualStrengthCap}\n'
                    'Limita a força contextual de retenção separada do score_sinais.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsPageBody extends StatelessWidget {
  const _SettingsPageBody({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth >= 600 ? 32.0 : 16.0;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: padding, vertical: 24),
              children: children,
            ),
          ),
        );
      },
    );
  }
}

class _HistoryDeletionCard extends StatelessWidget {
  const _HistoryDeletionCard({required this.viewModel});

  final SettingsPrivacyViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final (busy, statusMessage, isError) = switch (viewModel.deletionState) {
      HistoryDeletionIdle() => (false, null, false),
      HistoryDeletionInProgress() => (true, 'Apagando histórico local…', false),
      HistoryDeletionSucceeded() => (
        false,
        'Histórico derivado apagado. Catálogo e configuração foram preservados.',
        false,
      ),
      HistoryDeletionFailed(:final message) => (false, message, true),
    };

    return _SettingsCard(
      title: 'Controle do histórico',
      icon: Icons.delete_outline,
      children: [
        const Text(
          'A exclusão remove episódios, agregados, coberturas e análises '
          'derivadas. O catálogo e a configuração permanecem no aplicativo.',
        ),
        if (statusMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            statusMessage,
            key: const ValueKey('privacy-delete-status'),
            style: TextStyle(
              color: isError ? Theme.of(context).colorScheme.error : null,
            ),
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          key: const ValueKey('privacy-delete-history'),
          onPressed: busy ? null : () => _confirmDeletion(context),
          icon: busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_forever_outlined),
          label: const Text('Apagar histórico local'),
        ),
      ],
    );
  }

  Future<void> _confirmDeletion(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apagar histórico local?'),
        content: const Text(
          'Episódios, agregados, coberturas e análises derivadas serão '
          'removidos deste dispositivo conforme a retenção local vigente. '
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('privacy-delete-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('privacy-delete-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await viewModel.clearDerivedHistory();
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

String _signalLabel(BehavioralSignalKind signal) => switch (signal) {
  BehavioralSignalKind.longSessionDuration => 'LongSessionDuration',
  BehavioralSignalKind.highScreenTime => 'HighScreenTime',
  BehavioralSignalKind.frequentUnlocking => 'FrequentUnlocking',
};

String _thresholdLabel(String id) => switch (id) {
  'long_session_duration_minutes' => 'LongSessionDuration',
  'high_screen_time_hours_per_day' => 'HighScreenTime',
  'frequent_unlocks_per_day' => 'FrequentUnlocking',
  'session_merge_gap_seconds' => 'session_merge_gap_seconds',
  _ => id,
};

String _thresholdKindLabel(ThresholdKind kind) => switch (kind) {
  ThresholdKind.behavioral => 'limiar comportamental',
  ThresholdKind.technical => 'parâmetro técnico',
};

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelWidget = Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          );
          if (constraints.maxWidth < 460) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                labelWidget,
                const SizedBox(height: 4),
                SelectableText(value),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 190, child: labelWidget),
              Expanded(child: SelectableText(value)),
            ],
          );
        },
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 56),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
