import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:provider/provider.dart';

import '../../catalog/presentation/catalog_context_section.dart';
import '../../catalog/data/app_catalog_repository.dart';
import '../../notifications/domain/notification_observation.dart';
import '../../settings/presentation/settings_privacy_page.dart';
import '../../settings/presentation/settings_privacy_view_model.dart';
import '../../usage_access/presentation/usage_access_ui_state.dart';
import '../../usage_access/domain/usage_access.dart';
import '../domain/derived_analysis_repository.dart';
import '../domain/analysis_window.dart';
import '../domain/behavioral_signal_calibration.dart';
import '../domain/daily_usage_summary.dart';
import '../domain/episode_analysis.dart';
import '../domain/smartphone_usage_episode.dart';
import '../domain/scientific_traceability.dart';
import '../domain/score_total.dart';
import 'analysis_presenter.dart';
import 'dashboard_view_model.dart';
import 'episode_analysis_section.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardViewModel>(
      builder: (context, viewModel, _) => switch (viewModel.usageAccessState) {
        UsageAccessChecking() => _buildLoading(),
        UsageAccessDenied() => _buildUsageAccess(
          context,
          viewModel,
          statusMessage: null,
          isOpeningSettings: false,
        ),
        UsageSettingsOpening() => _buildUsageAccess(
          context,
          viewModel,
          statusMessage: 'Abrindo as configurações do Android…',
          isOpeningSettings: true,
        ),
        UsageSettingsOpened() => _buildUsageAccess(
          context,
          viewModel,
          statusMessage:
              'Configurações abertas. Ao retornar, verifique novamente o acesso.',
          isOpeningSettings: false,
        ),
        UsageSettingsOpenError(:final message) => _buildUsageAccess(
          context,
          viewModel,
          statusMessage: message,
          isOpeningSettings: false,
          isError: true,
        ),
        UsageAccessCheckError(:final message) => _buildAccessCheckError(
          context,
          viewModel,
          message,
        ),
        UsageAccessGranted() => _buildDashboard(context, viewModel),
      },
    );
  }

  Widget _buildLoading() {
    return Scaffold(
      appBar: AppBar(title: const Text('Análises')),
      body: const Center(
        child: Column(
          key: ValueKey('dashboard-loading-state'),
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Carregando análise retrospectiva…'),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageAccess(
    BuildContext context,
    DashboardViewModel viewModel, {
    required String? statusMessage,
    required bool isOpeningSettings,
    bool isError = false,
  }) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Análises')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth >= 600 ? 32.0 : 16.0;
          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_clock,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Precisamos de acesso ao uso do dispositivo',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Esse acesso permite ler localmente o tempo de uso dos '
                      'aplicativos e construir a análise retrospectiva. O Foco '
                      'Tela não lê conteúdo e não envia esses dados para a nuvem.',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sem a permissão, nenhuma métrica é exibida e a ausência '
                      'de acesso não é tratada como uso zero.',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    if (statusMessage != null) ...[
                      const SizedBox(height: 16),
                      _StatusMessage(message: statusMessage, isError: isError),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        key: const ValueKey('usage-access-open-settings'),
                        onPressed: isOpeningSettings
                            ? null
                            : viewModel.requestPermission,
                        child: isOpeningSettings
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Abrir configurações de acesso ao uso',
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      key: const ValueKey('usage-access-recheck'),
                      onPressed: isOpeningSettings ? null : viewModel.refresh,
                      child: const Text('Verificar acesso novamente'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAccessCheckError(
    BuildContext context,
    DashboardViewModel viewModel,
    String message,
  ) {
    return _buildError(
      context,
      title: 'Não foi possível verificar o acesso',
      message: message,
      actionLabel: 'Tentar novamente',
      onPressed: viewModel.refresh,
    );
  }

  Widget _buildDashboard(BuildContext context, DashboardViewModel viewModel) {
    if (viewModel.isLoading) return _buildLoading();

    final errorMessage = viewModel.errorMessage;
    if (errorMessage != null) {
      return _buildError(
        context,
        title: 'Erro ao carregar dados',
        message: errorMessage,
        actionLabel: 'Tentar novamente',
        onPressed: viewModel.refresh,
      );
    }

    final dashboard = viewModel.dashboard;
    if (dashboard == null) {
      if (viewModel.historyWasCleared) {
        return _buildClearedHistory(context, viewModel);
      }
      return _buildError(
        context,
        title: 'Nenhum dia disponível',
        message: 'Não foi possível montar o dashboard semanal.',
        actionLabel: 'Tentar novamente',
        onPressed: viewModel.refresh,
      );
    }

    final theme = Theme.of(context);
    final analysisPage = const AnalysisPagePresenter().present(dashboard);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Análises'),
        actions: [
          IconButton(
            key: const ValueKey('open-settings-privacy'),
            tooltip: 'Configurações e privacidade',
            onPressed: () => _openSettingsPrivacy(context, viewModel),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: 'Atualizar sete dias',
            onPressed: viewModel.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth >= 600 ? 32.0 : 16.0;
          final maxWidth = constraints.maxWidth >= 900 ? 1100.0 : 800.0;
          final useGrid = constraints.maxWidth >= 900;

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  16,
                  horizontalPadding,
                  16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dashboard.window == AnalysisWindow.sevenDays
                            ? 'Últimos 7 dias'
                            : 'Janela de ${dashboard.window.label}',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Análises longitudinais · Atualizado em ${_formatDateTime(dashboard.generatedAt)}',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      _WindowSelector(
                        selectedWindow: viewModel.selectedWindow,
                        onSelected: viewModel.selectWindow,
                      ),
                      const SizedBox(height: 16),
                      _WeeklySummaryCard(
                        cardKey: ValueKey(
                          'day-summary-${_dayKey(dashboard.days.first.dayStart)}',
                        ),
                        data: analysisPage.summary,
                        onTodayTap: dashboard.days.first.canOpenDetail
                            ? () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => DayDetailPage(
                                    summary: dashboard.days.first,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _ObservedConceptsCard(
                        concepts: analysisPage.observedConcepts,
                      ),
                      const SizedBox(height: 12),
                      _PeriodChangeCard(summary: analysisPage.periodChange),
                      if (!dashboard.days.any(
                        (day) => (day.episodeCount ?? 0) > 0,
                      )) ...[
                        const SizedBox(height: 12),
                        const _EmptyDashboardNotice(),
                      ],
                      if (Platform.isIOS &&
                          viewModel.iosScreenTimeAvailable) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: viewModel.openIosScreenTimeReport,
                            child: const Text('Ver relatório detalhado do iOS'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          key: const ValueKey('open-episode-explorer'),
                          onPressed:
                              dashboard.days.any(
                                (day) => day.episodes.isNotEmpty,
                              )
                              ? () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => EpisodeExplorerPage(
                                      dashboard: dashboard,
                                    ),
                                  ),
                                )
                              : null,
                          icon: const Icon(Icons.filter_list),
                          label: const Text('Episódios relevantes'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (dashboard.window.usesMonthlyOverview)
                        _MonthlyOverview(days: dashboard.days)
                      else if (dashboard.window.usesCompactCalendar)
                        _CompactDayGrid(
                          days: dashboard.days,
                          onTap: (summary) => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => DayDetailPage(summary: summary),
                            ),
                          ),
                        )
                      else if (useGrid)
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: dashboard.days.length,
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 340,
                                mainAxisExtent: 340,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemBuilder: (context, index) {
                            final summary = dashboard.days[index];
                            return _DaySummaryCard(
                              key: ValueKey(
                                'day-summary-${_dayKey(summary.dayStart)}',
                              ),
                              summary: summary,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      DayDetailPage(summary: summary),
                                ),
                              ),
                            );
                          },
                        )
                      else
                        Column(
                          children: [
                            for (
                              var index = 0;
                              index < dashboard.days.length;
                              index++
                            ) ...[
                              _DaySummaryCard(
                                key: ValueKey(
                                  index == 0
                                      ? 'day-summary-list-${_dayKey(dashboard.days[index].dayStart)}'
                                      : 'day-summary-${_dayKey(dashboard.days[index].dayStart)}',
                                ),
                                summary: dashboard.days[index],
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => DayDetailPage(
                                      summary: dashboard.days[index],
                                    ),
                                  ),
                                ),
                              ),
                              if (index < dashboard.days.length - 1)
                                const SizedBox(height: 12),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildClearedHistory(
    BuildContext context,
    DashboardViewModel viewModel,
  ) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Análises'),
        actions: [
          IconButton(
            key: const ValueKey('open-settings-privacy'),
            tooltip: 'Configurações e privacidade',
            onPressed: () => _openSettingsPrivacy(context, viewModel),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final padding = constraints.maxWidth >= 600 ? 32.0 : 16.0;
          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(padding),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.delete_sweep_outlined,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Histórico derivado local vazio',
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Episódios, agregados, coberturas e análises foram '
                      'removidos. Uma atualização explícita poderá reconstruir '
                      'novos resultados a partir dos dados de uso disponíveis.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      key: const ValueKey('refresh-after-history-clear'),
                      onPressed: viewModel.refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Atualizar agora'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openSettingsPrivacy(
    BuildContext context,
    DashboardViewModel viewModel,
  ) {
    final usageAccessRepository = context.read<UsageAccessRepository>();
    final catalogRepository = context.read<AppCatalogRepository>();
    final derivedRepository = context.read<DerivedAnalysisRepository>();
    final notificationRepository = context.read<NotificationRepository>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => SettingsPrivacyViewModel(
            usageAccessRepository: usageAccessRepository,
            catalogRepository: catalogRepository,
            derivedRepository: derivedRepository,
            notificationRepository: notificationRepository,
            onHistoryCleared: viewModel.forgetDerivedHistoryFromUi,
          ),
          child: const SettingsPrivacyPage(),
        ),
      ),
    );
  }

  Widget _buildError(
    BuildContext context, {
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Análises')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: onPressed, child: Text(actionLabel)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyDashboardNotice extends StatelessWidget {
  const _EmptyDashboardNotice();

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('dashboard-empty-state'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.inbox_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Nenhum episódio foi reconstruído nos dias com dados '
                'disponíveis. Dias sem cobertura continuam identificados '
                'separadamente.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklySummaryCard extends StatelessWidget {
  const _WeeklySummaryCard({
    required this.cardKey,
    required this.data,
    required this.onTodayTap,
  });

  final Key cardKey;
  final AnalysisWindowSummary data;
  final VoidCallback? onTodayTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      key: cardKey,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTodayTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.calendar_view_week,
                size: 40,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.title),
                    const SizedBox(height: 4),
                    Text(
                      data.headline,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth >= 560
                            ? (constraints.maxWidth - 16) / 3
                            : constraints.maxWidth;
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final metric in data.metrics)
                              _SummaryMetricTile(
                                width: width,
                                label: metric.label,
                                value: metric.value,
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(data.coverageLabel, style: theme.textTheme.bodySmall),
                    if (data.notificationLabel != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        data.notificationLabel!,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryMetricTile extends StatelessWidget {
  const _SummaryMetricTile({
    required this.width,
    required this.label,
    required this.value,
  });

  final double width;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WindowSelector extends StatelessWidget {
  const _WindowSelector({
    required this.selectedWindow,
    required this.onSelected,
  });

  final AnalysisWindow selectedWindow;
  final ValueChanged<AnalysisWindow> onSelected;

  @override
  Widget build(BuildContext context) {
    const primaryWindows = [
      AnalysisWindow.threeDays,
      AnalysisWindow.sevenDays,
      AnalysisWindow.thirtyDays,
    ];
    const secondaryWindows = [
      AnalysisWindow.fifteenDays,
      AnalysisWindow.semester,
    ];
    return Wrap(
      key: const ValueKey('analysis-window-selector'),
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final window in primaryWindows)
          ChoiceChip(
            label: Text(window.label),
            selected: selectedWindow == window,
            onSelected: (_) => onSelected(window),
          ),
        PopupMenuButton<AnalysisWindow>(
          key: const ValueKey('analysis-window-more'),
          tooltip: 'Mais janelas',
          onSelected: onSelected,
          itemBuilder: (context) => [
            for (final window in secondaryWindows)
              PopupMenuItem(value: window, child: Text(window.label)),
          ],
          child: Chip(
            avatar: const Icon(Icons.more_horiz, size: 18),
            label: Text(
              secondaryWindows.contains(selectedWindow)
                  ? selectedWindow.label
                  : 'Mais',
            ),
          ),
        ),
      ],
    );
  }
}

class _ObservedConceptsCard extends StatelessWidget {
  const _ObservedConceptsCard({required this.concepts});

  final List<ObservedConcept> concepts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('observed-signals-mechanisms'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sinais e mecanismos observados',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (concepts.isEmpty)
              const Text(
                'Nenhum conceito com aplicação rastreável apareceu nesta janela.',
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final concept in concepts)
                    ActionChip(
                      label: Text('${concept.category}: ${concept.label}'),
                      onPressed: () => _showObservedConcept(context, concept),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showObservedConcept(BuildContext context, ObservedConcept concept) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                concept.label,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _DetailRow(label: 'Categoria', value: concept.category),
              _DetailRow(label: 'IRI', value: concept.iri),
              _DetailRow(label: 'Evidência', value: concept.evidence),
              _DetailRow(label: 'Escopo', value: concept.scope),
              _DetailRow(label: 'Versão', value: concept.version),
              _DetailRow(label: 'Cautela', value: concept.caution),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodChangeCard extends StatelessWidget {
  const _PeriodChangeCard({required this.summary});

  final PeriodChangeSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('period-change-summary'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(summary.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              summary.headline,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              key: const ValueKey('period-change-details'),
              tilePadding: EdgeInsets.zero,
              title: const Text('Ver dados e cautela'),
              childrenPadding: EdgeInsets.zero,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(summary.detail),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Cautela: ${summary.caution}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DaySummaryCard extends StatelessWidget {
  const _DaySummaryCard({
    super.key,
    required this.summary,
    required this.onTap,
  });

  final DailyUsageSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canOpenDetail = summary.canOpenDetail;

    return Card(
      elevation: 1,
      child: InkWell(
        onTap: canOpenDetail ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _dayLabel(summary.dayStart, summary.lastUpdatedAt),
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(summary.dayStart),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  _CoverageBadge(status: summary.coverageStatus),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                summary.totalUsage == null
                    ? 'Sem métricas disponíveis'
                    : _formatDuration(summary.totalUsage!),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                summary.episodeCount == null
                    ? 'Lista de episódios indisponível'
                    : '${summary.episodeCount} episódio${summary.episodeCount == 1 ? '' : 's'}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Estados: ${_formatStateDistribution(summary.stateDistribution)}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'App de maior duração: ${_topAppLabel(summary)}',
                style: theme.textTheme.bodySmall,
              ),
              if (summary.notificationCount != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${summary.notificationCount} notificações observadas',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Atualizado em ${_formatDateTime(summary.lastUpdatedAt)}',
                style: theme.textTheme.bodySmall,
              ),
              if (summary.analyzedThrough != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Analisado até ${_formatDateTime(summary.analyzedThrough!)} · provisório',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (summary.issueMessage != null) ...[
                const SizedBox(height: 4),
                Text(
                  summary.issueMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (!canOpenDetail) ...[
                const SizedBox(height: 4),
                Text(
                  'Detalhe indisponível por falta de cobertura.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverageBadge extends StatelessWidget {
  const _CoverageBadge({required this.status});

  final CoverageStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = switch (status) {
      CoverageStatus.sufficient => (
        background: Colors.green.shade100,
        foreground: Colors.green.shade900,
      ),
      CoverageStatus.partial => (
        background: Colors.orange.shade100,
        foreground: Colors.orange.shade900,
      ),
      CoverageStatus.unavailable => (
        background: Colors.grey.shade300,
        foreground: Colors.grey.shade800,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.shortLabel,
        style: TextStyle(
          color: colors.foreground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CompactDayGrid extends StatelessWidget {
  const _CompactDayGrid({required this.days, required this.onTap});

  final List<DailyUsageSummary> days;
  final ValueChanged<DailyUsageSummary> onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      key: const ValueKey('compact-day-calendar'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: days.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 124,
        mainAxisExtent: 124,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final summary = days[index];
        return Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            onTap: summary.canOpenDetail ? () => onTap(summary) : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(summary.dayStart),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Text(
                    summary.totalUsage == null
                        ? 'Sem dados'
                        : _formatDuration(summary.totalUsage!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: _CoverageBadge(status: summary.coverageStatus),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MonthlyOverview extends StatelessWidget {
  const _MonthlyOverview({required this.days});

  final List<DailyUsageSummary> days;

  @override
  Widget build(BuildContext context) {
    final byMonth = <String, List<DailyUsageSummary>>{};
    for (final day in days) {
      final key =
          '${day.dayStart.month.toString().padLeft(2, '0')}/${day.dayStart.year}';
      byMonth.putIfAbsent(key, () => []).add(day);
    }
    return ListView.separated(
      key: const ValueKey('semester-monthly-overview'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: byMonth.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final entry = byMonth.entries.elementAt(index);
        final usage = entry.value.fold<Duration>(
          Duration.zero,
          (total, day) => total + (day.totalUsage ?? Duration.zero),
        );
        final covered = entry.value
            .where((day) => day.coverageStatus.isAvailable)
            .length;
        return Card(
          child: ListTile(
            title: Text(entry.key),
            subtitle: Text(
              '$covered dias com cobertura observada · '
              '${_formatDuration(usage)}',
            ),
            trailing: const Icon(Icons.calendar_month_outlined),
          ),
        );
      },
    );
  }
}

enum _EpisodeSortMode { longest, newest, oldest, intensity, app }

enum _EpisodeGroupMode { day, app, state, none }

enum _EpisodeDurationFilter { any, short, medium, long }

enum _EpisodeContextFilter { any, available, unavailable }

enum _EpisodeTimeFilter { any, dawn, morning, afternoon, night }

class EpisodeExplorerPage extends StatefulWidget {
  const EpisodeExplorerPage({super.key, required this.dashboard});

  final WeeklyUsageDashboard dashboard;

  @override
  State<EpisodeExplorerPage> createState() => _EpisodeExplorerPageState();
}

class _EpisodeExplorerPageState extends State<EpisodeExplorerPage> {
  _EpisodeSortMode _sortMode = _EpisodeSortMode.longest;
  _EpisodeGroupMode _groupMode = _EpisodeGroupMode.day;
  String? _appFilter;
  ScoreTotalBand? _retentionFilter;
  AnalysisState? _stateFilter;
  _EpisodeDurationFilter _durationFilter = _EpisodeDurationFilter.any;
  BehavioralScoreRange? _intensityFilter;
  BehavioralSignalKind? _activeSignalFilter;
  CoverageStatus? _coverageFilter;
  _EpisodeContextFilter _contextFilter = _EpisodeContextFilter.any;
  _EpisodeTimeFilter _timeFilter = _EpisodeTimeFilter.any;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _filteredEntries();
    final grouped = _group(entries);
    final appNames =
        widget.dashboard.days
            .expand((day) => day.episodes)
            .map((episode) => episode.displayName)
            .toSet()
            .toList()
          ..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('Episódios relevantes')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final padding = constraints.maxWidth >= 600 ? 32.0 : 16.0;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                key: const ValueKey('episode-explorer-list'),
                padding: EdgeInsets.all(padding),
                children: [
                  Text(
                    'Episódios relevantes',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Exploração longitudinal na janela ${widget.dashboard.window.label}. '
                    'A lista prioriza episódios que merecem revisão sem criar diagnóstico.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lista longitudinal',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      DropdownButton<String?>(
                        key: const ValueKey('episode-app-filter'),
                        value: _appFilter,
                        hint: const Text('Filtrar app'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Todos os apps'),
                          ),
                          for (final appName in appNames)
                            DropdownMenuItem<String?>(
                              value: appName,
                              child: Text(appName),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _appFilter = value),
                      ),
                      DropdownButton<ScoreTotalBand?>(
                        key: const ValueKey('episode-retention-filter'),
                        value: _retentionFilter,
                        hint: const Text('Indícios de retenção'),
                        items: [
                          const DropdownMenuItem<ScoreTotalBand?>(
                            value: null,
                            child: Text('Todos os indícios'),
                          ),
                          for (final band in ScoreTotalBand.values)
                            DropdownMenuItem<ScoreTotalBand?>(
                              value: band,
                              child: Text(band.label),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _retentionFilter = value),
                      ),
                      DropdownButton<_EpisodeDurationFilter>(
                        key: const ValueKey('episode-duration-filter'),
                        value: _durationFilter,
                        items: const [
                          DropdownMenuItem(
                            value: _EpisodeDurationFilter.any,
                            child: Text('Qualquer duração'),
                          ),
                          DropdownMenuItem(
                            value: _EpisodeDurationFilter.short,
                            child: Text('Até 5 min'),
                          ),
                          DropdownMenuItem(
                            value: _EpisodeDurationFilter.medium,
                            child: Text('5 a 30 min'),
                          ),
                          DropdownMenuItem(
                            value: _EpisodeDurationFilter.long,
                            child: Text('30 min ou mais'),
                          ),
                        ],
                        onChanged: (value) => setState(
                          () => _durationFilter =
                              value ?? _EpisodeDurationFilter.any,
                        ),
                      ),
                    ],
                  ),
                  ExpansionTile(
                    key: const ValueKey('episode-more-filters'),
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      _activeAdvancedFilterCount() == 0
                          ? 'Mais filtros'
                          : 'Mais filtros (${_activeAdvancedFilterCount()})',
                    ),
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          DropdownButton<_EpisodeSortMode>(
                            key: const ValueKey('episode-sort-selector'),
                            value: _sortMode,
                            items: const [
                              DropdownMenuItem(
                                value: _EpisodeSortMode.longest,
                                child: Text('Maior duração'),
                              ),
                              DropdownMenuItem(
                                value: _EpisodeSortMode.newest,
                                child: Text('Mais recentes'),
                              ),
                              DropdownMenuItem(
                                value: _EpisodeSortMode.oldest,
                                child: Text('Mais antigos'),
                              ),
                              DropdownMenuItem(
                                value: _EpisodeSortMode.intensity,
                                child: Text('Maior intensidade'),
                              ),
                              DropdownMenuItem(
                                value: _EpisodeSortMode.app,
                                child: Text('Aplicativo'),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _sortMode = value ?? _sortMode),
                          ),
                          DropdownButton<_EpisodeGroupMode>(
                            key: const ValueKey('episode-group-selector'),
                            value: _groupMode,
                            items: const [
                              DropdownMenuItem(
                                value: _EpisodeGroupMode.day,
                                child: Text('Agrupar por dia'),
                              ),
                              DropdownMenuItem(
                                value: _EpisodeGroupMode.app,
                                child: Text('Agrupar por app'),
                              ),
                              DropdownMenuItem(
                                value: _EpisodeGroupMode.state,
                                child: Text('Agrupar por estado técnico'),
                              ),
                              DropdownMenuItem(
                                value: _EpisodeGroupMode.none,
                                child: Text('Sem agrupamento'),
                              ),
                            ],
                            onChanged: (value) => setState(
                              () => _groupMode = value ?? _groupMode,
                            ),
                          ),
                          DropdownButton<AnalysisState?>(
                            key: const ValueKey('episode-state-filter'),
                            value: _stateFilter,
                            hint: const Text('Estado técnico'),
                            items: [
                              const DropdownMenuItem<AnalysisState?>(
                                value: null,
                                child: Text('Todos os estados'),
                              ),
                              for (final state in AnalysisState.values)
                                DropdownMenuItem<AnalysisState?>(
                                  value: state,
                                  child: Text(_analysisStateLabel(state)),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _stateFilter = value),
                          ),
                          DropdownButton<BehavioralScoreRange?>(
                            key: const ValueKey('episode-intensity-filter'),
                            value: _intensityFilter,
                            hint: const Text('Intensidade'),
                            items: [
                              const DropdownMenuItem<BehavioralScoreRange?>(
                                value: null,
                                child: Text('Todas intensidades'),
                              ),
                              for (final range in BehavioralScoreRange.values)
                                DropdownMenuItem<BehavioralScoreRange?>(
                                  value: range,
                                  child: Text(range.label),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _intensityFilter = value),
                          ),
                          DropdownButton<BehavioralSignalKind?>(
                            key: const ValueKey('episode-signal-filter'),
                            value: _activeSignalFilter,
                            hint: const Text('Sinal ativo'),
                            items: [
                              const DropdownMenuItem<BehavioralSignalKind?>(
                                value: null,
                                child: Text('Todos os sinais'),
                              ),
                              for (final signal in BehavioralSignalKind.values)
                                DropdownMenuItem<BehavioralSignalKind?>(
                                  value: signal,
                                  child: Text(signal.label),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _activeSignalFilter = value),
                          ),
                          DropdownButton<CoverageStatus?>(
                            key: const ValueKey('episode-coverage-filter'),
                            value: _coverageFilter,
                            hint: const Text('Cobertura'),
                            items: [
                              const DropdownMenuItem<CoverageStatus?>(
                                value: null,
                                child: Text('Todas coberturas'),
                              ),
                              for (final coverage in CoverageStatus.values)
                                DropdownMenuItem<CoverageStatus?>(
                                  value: coverage,
                                  child: Text(coverage.shortLabel),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _coverageFilter = value),
                          ),
                          DropdownButton<_EpisodeContextFilter>(
                            key: const ValueKey('episode-context-filter'),
                            value: _contextFilter,
                            items: const [
                              DropdownMenuItem(
                                value: _EpisodeContextFilter.any,
                                child: Text('Qualquer contexto'),
                              ),
                              DropdownMenuItem(
                                value: _EpisodeContextFilter.available,
                                child: Text('Contexto disponível'),
                              ),
                              DropdownMenuItem(
                                value: _EpisodeContextFilter.unavailable,
                                child: Text('Contexto indisponível'),
                              ),
                            ],
                            onChanged: (value) => setState(
                              () => _contextFilter =
                                  value ?? _EpisodeContextFilter.any,
                            ),
                          ),
                          DropdownButton<_EpisodeTimeFilter>(
                            key: const ValueKey('episode-time-filter'),
                            value: _timeFilter,
                            items: const [
                              DropdownMenuItem(
                                value: _EpisodeTimeFilter.any,
                                child: Text('Qualquer horário'),
                              ),
                              DropdownMenuItem(
                                value: _EpisodeTimeFilter.dawn,
                                child: Text('Madrugada'),
                              ),
                              DropdownMenuItem(
                                value: _EpisodeTimeFilter.morning,
                                child: Text('Manhã'),
                              ),
                              DropdownMenuItem(
                                value: _EpisodeTimeFilter.afternoon,
                                child: Text('Tarde'),
                              ),
                              DropdownMenuItem(
                                value: _EpisodeTimeFilter.night,
                                child: Text('Noite'),
                              ),
                            ],
                            onChanged: (value) => setState(
                              () =>
                                  _timeFilter = value ?? _EpisodeTimeFilter.any,
                            ),
                          ),
                          TextButton.icon(
                            key: const ValueKey('episode-clear-filters'),
                            onPressed: () => setState(() {
                              _appFilter = null;
                              _retentionFilter = null;
                              _stateFilter = null;
                              _durationFilter = _EpisodeDurationFilter.any;
                              _intensityFilter = null;
                              _activeSignalFilter = null;
                              _coverageFilter = null;
                              _contextFilter = _EpisodeContextFilter.any;
                              _timeFilter = _EpisodeTimeFilter.any;
                            }),
                            icon: const Icon(Icons.clear),
                            label: const Text('Limpar filtros'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_activeFilterCount()} filtro(s) ativo(s) · '
                    '${entries.length} episódio(s)',
                    key: const ValueKey('episode-active-filter-count'),
                  ),
                  const SizedBox(height: 16),
                  if (entries.isEmpty)
                    const Card(
                      key: ValueKey('episode-filter-empty-state'),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Nenhum episódio corresponde aos critérios ativos nesta janela. '
                          'Revise aplicativo, estado, período ou limpe os filtros.',
                        ),
                      ),
                    )
                  else
                    for (final group in grouped.entries) ...[
                      if (_groupMode != _EpisodeGroupMode.none) ...[
                        Text(group.key, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                      ],
                      for (final entry in group.value)
                        _EpisodeExplorerTile(entry: entry),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<_EpisodeEntry> _filteredEntries() {
    final entries = <_EpisodeEntry>[];
    for (final day in widget.dashboard.days) {
      for (final episode in day.episodes) {
        entries.add(
          _EpisodeEntry(
            day: day,
            episode: episode,
            analysis: day.analysisForEpisode(episode),
          ),
        );
      }
    }
    final filtered = entries.where((entry) {
      final state = switch (entry.analysis) {
        ClassifiedEpisodeAnalysis(:final state) => state,
        _ => null,
      };
      final intensity = switch (entry.analysis) {
        ClassifiedEpisodeAnalysis(:final behavioralScore) =>
          behavioralScore.range,
        _ => null,
      };
      final retentionBand = switch (entry.analysis) {
        ClassifiedEpisodeAnalysis(:final scoreTotal) => scoreTotal.band,
        _ => null,
      };
      return (_appFilter == null || entry.episode.displayName == _appFilter) &&
          (_retentionFilter == null || retentionBand == _retentionFilter) &&
          (_stateFilter == null || state == _stateFilter) &&
          _matchesDuration(entry) &&
          (_intensityFilter == null || intensity == _intensityFilter) &&
          _matchesActiveSignal(entry) &&
          (_coverageFilter == null ||
              entry.day.coverageStatus == _coverageFilter) &&
          _matchesContext(entry) &&
          _matchesTime(entry);
    }).toList();
    filtered.sort(_compareEntries);
    return filtered;
  }

  int _compareEntries(_EpisodeEntry left, _EpisodeEntry right) =>
      _groupMode == _EpisodeGroupMode.day &&
          _sortMode == _EpisodeSortMode.longest
      ? _compareByRecentDayThenDuration(left, right)
      : switch (_sortMode) {
          _EpisodeSortMode.longest => right.episode.duration.compareTo(
            left.episode.duration,
          ),
          _EpisodeSortMode.newest => right.episode.startedAt.compareTo(
            left.episode.startedAt,
          ),
          _EpisodeSortMode.oldest => left.episode.startedAt.compareTo(
            right.episode.startedAt,
          ),
          _EpisodeSortMode.intensity => _score(right).compareTo(_score(left)),
          _EpisodeSortMode.app => left.episode.displayName.compareTo(
            right.episode.displayName,
          ),
        };

  int _compareByRecentDayThenDuration(_EpisodeEntry left, _EpisodeEntry right) {
    final dayOrder = right.day.dayStart.compareTo(left.day.dayStart);
    if (dayOrder != 0) return dayOrder;
    return right.episode.duration.compareTo(left.episode.duration);
  }

  Map<String, List<_EpisodeEntry>> _group(List<_EpisodeEntry> entries) {
    final grouped = <String, List<_EpisodeEntry>>{};
    for (final entry in entries) {
      final key = switch (_groupMode) {
        _EpisodeGroupMode.day => _formatDate(entry.day.dayStart),
        _EpisodeGroupMode.app => entry.episode.displayName,
        _EpisodeGroupMode.state => switch (entry.analysis) {
          ClassifiedEpisodeAnalysis(:final state) => _analysisStateLabel(state),
          UnclassifiedEpisodeAnalysis() => 'Sem classificação',
          null => 'Sem análise',
        },
        _EpisodeGroupMode.none => 'Todos',
      };
      grouped.putIfAbsent(key, () => []).add(entry);
    }
    return grouped;
  }

  bool _matchesDuration(_EpisodeEntry entry) {
    final minutes = entry.episode.duration.inMinutes;
    return switch (_durationFilter) {
      _EpisodeDurationFilter.any => true,
      _EpisodeDurationFilter.short => minutes < 5,
      _EpisodeDurationFilter.medium => minutes >= 5 && minutes < 30,
      _EpisodeDurationFilter.long => minutes >= 30,
    };
  }

  bool _matchesActiveSignal(_EpisodeEntry entry) {
    final signal = _activeSignalFilter;
    if (signal == null) return true;
    return entry.analysis?.signalObservations.any(
          (observation) =>
              observation.kind == signal && observation.isActive == true,
        ) ==
        true;
  }

  bool _matchesContext(_EpisodeEntry entry) {
    final contextAvailable = switch (entry.analysis) {
      ClassifiedEpisodeAnalysis(:final context) => context.isAvailable,
      _ => false,
    };
    return switch (_contextFilter) {
      _EpisodeContextFilter.any => true,
      _EpisodeContextFilter.available => contextAvailable,
      _EpisodeContextFilter.unavailable => !contextAvailable,
    };
  }

  bool _matchesTime(_EpisodeEntry entry) {
    final hour = entry.episode.startedAt.hour;
    return switch (_timeFilter) {
      _EpisodeTimeFilter.any => true,
      _EpisodeTimeFilter.dawn => hour < 6,
      _EpisodeTimeFilter.morning => hour >= 6 && hour < 12,
      _EpisodeTimeFilter.afternoon => hour >= 12 && hour < 18,
      _EpisodeTimeFilter.night => hour >= 18,
    };
  }

  int _activeFilterCount() => [
    _appFilter,
    _retentionFilter,
    _stateFilter,
    if (_durationFilter != _EpisodeDurationFilter.any) _durationFilter,
    _intensityFilter,
    _activeSignalFilter,
    _coverageFilter,
    if (_contextFilter != _EpisodeContextFilter.any) _contextFilter,
    if (_timeFilter != _EpisodeTimeFilter.any) _timeFilter,
  ].where((filter) => filter != null).length;

  int _activeAdvancedFilterCount() => [
    _stateFilter,
    _intensityFilter,
    _activeSignalFilter,
    _coverageFilter,
    if (_contextFilter != _EpisodeContextFilter.any) _contextFilter,
    if (_timeFilter != _EpisodeTimeFilter.any) _timeFilter,
  ].where((filter) => filter != null).length;

  double _score(_EpisodeEntry entry) => switch (entry.analysis) {
    ClassifiedEpisodeAnalysis(:final behavioralScore) => behavioralScore.value,
    _ => -1,
  };
}

class _EpisodeEntry {
  const _EpisodeEntry({
    required this.day,
    required this.episode,
    required this.analysis,
  });

  final DailyUsageSummary day;
  final SmartphoneUsageEpisode episode;
  final EpisodeAnalysisResult? analysis;
}

class _EpisodeExplorerTile extends StatelessWidget {
  const _EpisodeExplorerTile({required this.entry});

  final _EpisodeEntry entry;

  @override
  Widget build(BuildContext context) {
    final analysis = entry.analysis;
    final stateLabel = switch (analysis) {
      ClassifiedEpisodeAnalysis(:final state) => _analysisStateLabel(state),
      UnclassifiedEpisodeAnalysis() => 'Sem classificação',
      null => 'Sem análise',
    };
    final intensityLabel = switch (analysis) {
      ClassifiedEpisodeAnalysis(:final behavioralScore) =>
        behavioralScore.range.label,
      _ => 'indisponível',
    };
    final activeSignals =
        analysis?.signalObservations
            .where((signal) => signal.isActive == true)
            .map((signal) => signal.kind.label)
            .join(', ') ??
        'indisponível';

    return Card(
      child: ListTile(
        title: Text(entry.episode.displayName),
        subtitle: Text(
          '${_formatDateTime(entry.episode.startedAt)}–'
          '${_formatTime(entry.episode.endedAt)} · '
          '$stateLabel · intensidade $intensityLabel · '
          'sinais: $activeSignals · ${entry.day.coverageStatus.shortLabel}',
        ),
        trailing: Text(_formatDuration(entry.episode.duration)),
      ),
    );
  }
}

class NotificationContentPage extends StatefulWidget {
  const NotificationContentPage({
    super.key,
    required this.repository,
    required this.start,
    required this.end,
  });

  final NotificationRepository repository;
  final DateTime start;
  final DateTime end;

  @override
  State<NotificationContentPage> createState() =>
      _NotificationContentPageState();
}

class _NotificationContentPageState extends State<NotificationContentPage> {
  final TextEditingController _packageController = TextEditingController();
  NotificationContentSettings? _settings;
  List<NotificationTextRecord> _records = const [];
  bool _isLoading = true;
  bool _isAuthenticating = false;
  String? _message;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _packageController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _message = null;
      _isError = false;
    });
    try {
      final settings = await widget.repository.loadContentSettings();
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _message =
            'Não foi possível carregar as preferências de conteúdo textual.';
        _isError = true;
      });
    }
  }

  Future<void> _setContentEnabled(bool enabled) async {
    await widget.repository.setContentModeEnabled(enabled);
    if (!enabled) {
      setState(() => _records = const []);
    }
    await _loadSettings();
  }

  Future<void> _authorizePackage() async {
    final packageName = _packageController.text.trim();
    if (packageName.isEmpty) return;
    await widget.repository.authorizeContentPackage(packageName);
    _packageController.clear();
    await _loadSettings();
  }

  Future<void> _revokePackage(String packageName) async {
    await widget.repository.revokeContentPackage(packageName);
    setState(
      () => _records = _records
          .where((record) => record.packageName != packageName)
          .toList(growable: false),
    );
    await _loadSettings();
  }

  Future<void> _authenticateAndLoad() async {
    setState(() {
      _isAuthenticating = true;
      _message = null;
      _isError = false;
    });
    try {
      final authenticated = await widget.repository
          .authenticateContentViewing();
      if (!authenticated) {
        setState(() {
          _isAuthenticating = false;
          _message =
              'Consulta cancelada. A visualização exige autenticação do dispositivo.';
          _isError = false;
        });
        return;
      }
      final records = await widget.repository.loadStoredContent(
        start: widget.start,
        end: widget.end,
      );
      setState(() {
        _records = records;
        _isAuthenticating = false;
        _message = records.isEmpty
            ? 'Nenhum título/texto autorizado foi armazenado nesta janela.'
            : null;
      });
    } catch (_) {
      setState(() {
        _isAuthenticating = false;
        _message =
            'Não foi possível autenticar ou consultar o conteúdo armazenado.';
        _isError = true;
      });
    }
  }

  Future<void> _clearContent() async {
    await widget.repository.clearStoredContent();
    setState(() {
      _records = const [];
      _message = 'Conteúdo textual armazenado removido deste dispositivo.';
      _isError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = _settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Conteúdo de notificações')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final padding = constraints.maxWidth >= 600 ? 32.0 : 16.0;
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: padding,
                  vertical: 24,
                ),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Modo opcional e protegido',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Título e texto ficam apenas consultáveis por '
                            'aplicativo e horário. Eles não alimentam métricas, '
                            'sinais, scores, estados ou classificações.',
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            key: const ValueKey('notification-content-toggle'),
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Armazenar conteúdo textual autorizado',
                            ),
                            subtitle: Text(
                              settings?.enabled == true
                                  ? 'Ativo · retenção máxima de 7 dias · backup excluído'
                                  : 'Desativado por padrão',
                            ),
                            value: settings?.enabled == true,
                            onChanged: _setContentEnabled,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            key: const ValueKey(
                              'notification-content-package-input',
                            ),
                            controller: _packageController,
                            decoration: const InputDecoration(
                              labelText: 'Package name autorizado',
                              hintText: 'ex.: com.example.app',
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            key: const ValueKey(
                              'notification-content-authorize-package',
                            ),
                            onPressed: settings?.enabled == true
                                ? _authorizePackage
                                : null,
                            icon: const Icon(Icons.add),
                            label: const Text('Autorizar aplicativo'),
                          ),
                          const SizedBox(height: 12),
                          if (settings == null ||
                              settings.authorizedPackageNames.isEmpty)
                            const Text('Nenhum aplicativo autorizado.')
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final packageName
                                    in settings.authorizedPackageNames)
                                  InputChip(
                                    label: Text(packageName),
                                    onDeleted: () =>
                                        _revokePackage(packageName),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Consulta local',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Janela: ${_formatDate(widget.start)} até '
                            '${_formatDate(widget.end.subtract(const Duration(days: 1)))}. '
                            'A consulta exige autenticação biométrica ou credencial do dispositivo.',
                          ),
                          if (_message != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _message!,
                              style: TextStyle(
                                color: _isError
                                    ? theme.colorScheme.error
                                    : null,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                key: const ValueKey(
                                  'notification-content-authenticate',
                                ),
                                onPressed:
                                    settings?.enabled == true &&
                                        !_isAuthenticating
                                    ? _authenticateAndLoad
                                    : null,
                                icon: _isAuthenticating
                                    ? const SizedBox.square(
                                        dimension: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.lock_open_outlined),
                                label: const Text('Autenticar e consultar'),
                              ),
                              OutlinedButton.icon(
                                key: const ValueKey(
                                  'notification-content-clear',
                                ),
                                onPressed: _records.isEmpty
                                    ? null
                                    : _clearContent,
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Limpar registros'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_records.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Sem registros textuais carregados. Contagens de '
                          'notificações podem continuar disponíveis mesmo com '
                          'conteúdo textual desativado.',
                        ),
                      ),
                    )
                  else
                    for (final record in _records)
                      Card(
                        child: ListTile(
                          title: Text(record.title),
                          subtitle: Text(
                            '${record.packageName} · '
                            '${_formatDateTime(record.postedAt)}\n'
                            '${record.text}',
                          ),
                          isThreeLine: true,
                        ),
                      ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

String _analysisStateLabel(AnalysisState state) => switch (state) {
  AnalysisState.contextUnavailable => 'Contexto indisponível',
  AnalysisState.insufficientSignals => 'Sinais insuficientes',
  AnalysisState.signalsForReview => 'Sinais para revisão',
  AnalysisState.convergentIntensifiedRetentionSignals =>
    'Convergência de sinais',
};

extension _BehavioralScoreRangeLabel on BehavioralScoreRange {
  String get label => switch (this) {
    BehavioralScoreRange.low => 'baixa',
    BehavioralScoreRange.medium => 'média',
    BehavioralScoreRange.high => 'alta',
  };
}

extension _BehavioralSignalKindLabel on BehavioralSignalKind {
  String get label => switch (this) {
    BehavioralSignalKind.longSessionDuration => 'LongSessionDuration',
    BehavioralSignalKind.highScreenTime => 'HighScreenTime',
    BehavioralSignalKind.frequentUnlocking => 'FrequentUnlocking',
  };
}

String _formatStateDistribution(Map<AnalysisState, int> distribution) {
  final active = distribution.entries
      .where((entry) => entry.value > 0)
      .map((entry) => '${_analysisStateLabel(entry.key)} ${entry.value}')
      .join(', ');
  return active.isEmpty ? 'sem estados classificados' : active;
}

String _topAppLabel(DailyUsageSummary summary) {
  if (summary.appAggregates.isNotEmpty) {
    final sorted = [...summary.appAggregates]
      ..sort((left, right) => right.duration.compareTo(left.duration));
    final top = sorted.first;
    return '${top.appName} (${_formatDuration(top.duration)})';
  }
  if (summary.episodes.isEmpty) return 'indisponível';
  final durations = <String, ({String appName, Duration duration})>{};
  for (final episode in summary.episodes) {
    final current =
        durations[episode.packageName] ??
        (appName: episode.displayName, duration: Duration.zero);
    durations[episode.packageName] = (
      appName: current.appName,
      duration: current.duration + episode.duration,
    );
  }
  final sorted = durations.values.toList()
    ..sort((left, right) => right.duration.compareTo(left.duration));
  final top = sorted.first;
  return '${top.appName} (${_formatDuration(top.duration)})';
}

int _episodesWithSignals(DailyUsageSummary summary) => summary.episodeAnalyses
    .where(
      (analysis) =>
          analysis.signalObservations.any((signal) => signal.isActive == true),
    )
    .length;

int _distinctActiveSignals(DailyUsageSummary summary) => summary.episodeAnalyses
    .expand((analysis) => analysis.signalObservations)
    .where((signal) => signal.isActive == true)
    .map((signal) => signal.kind)
    .toSet()
    .length;

String _maxIntensityLabel(DailyUsageSummary summary) {
  final ranges = summary.episodeAnalyses
      .whereType<ClassifiedEpisodeAnalysis>()
      .map((analysis) => analysis.behavioralScore.range)
      .toList(growable: false);
  if (ranges.isEmpty) return 'Indisponível';
  if (ranges.contains(BehavioralScoreRange.high)) return 'Alta';
  if (ranges.contains(BehavioralScoreRange.medium)) return 'Média';
  return 'Baixa';
}

String _approvedContextShareLabel(DailyUsageSummary summary) {
  final denominator = summary.totalUsage ?? _totalEpisodeDuration(summary);
  if (denominator.inSeconds <= 0) return 'Indisponível';
  final approvedSeconds = summary.episodeAnalyses
      .whereType<ClassifiedEpisodeAnalysis>()
      .where((analysis) => analysis.context.isAvailable)
      .fold<int>(
        0,
        (total, analysis) => total + analysis.episode.duration.inSeconds,
      );
  final percent = (approvedSeconds / denominator.inSeconds) * 100;
  return '${percent.clamp(0, 100).toStringAsFixed(0)}%';
}

Duration _totalEpisodeDuration(DailyUsageSummary summary) => summary.episodes
    .fold(Duration.zero, (total, episode) => total + episode.duration);

String _episodePriorityHeadline(
  SmartphoneUsageEpisode episode,
  EpisodeAnalysisResult? analysis,
) {
  final intensity = switch (analysis) {
    ClassifiedEpisodeAnalysis(:final scoreTotal) =>
      scoreTotal.band.label.toLowerCase(),
    UnclassifiedEpisodeAnalysis() => 'não calculada',
    null => 'indisponível',
  };
  return '${_formatDuration(episode.duration)} · Indícios de retenção $intensity';
}

ScientificTraceability _dailyTraceability(DailyUsageSummary summary) {
  final versions = summary.episodeAnalyses.isEmpty
      ? null
      : summary.episodeAnalyses.first.versions;
  return ScientificTraceability(
    metric: 'tempo_ativo_diario',
    value: summary.totalUsage?.inMinutes.toString() ?? 'indisponível',
    unit: 'minutos',
    period: _formatDate(summary.dayStart),
    coverageStatus: summary.coverageStatus,
    signalOrState: _formatStateDistribution(summary.stateDistribution),
    thresholdOrWeight:
        'agregado diário; limiares e pesos permanecem nos episódios quando disponíveis',
    configurationVersion: versions?.calibrationVersion ?? 'indisponível',
    catalogVersion: versions?.catalogVersion ?? 'indisponível',
    owlIri: versions?.owxIri ?? 'urn:foco-tela:owl:indisponivel',
    caution:
        'Agregado diário é descritivo e não constitui score ou estado do dia.',
  );
}

ScientificTraceability _episodeTraceability(
  SmartphoneUsageEpisode episode,
  DailyUsageSummary day,
  EpisodeAnalysisResult? analysis,
) {
  final signal = _firstSignal(analysis);
  final stateOrSignal = switch (analysis) {
    ClassifiedEpisodeAnalysis(:final state, :final scoreTotal) =>
      '${_analysisStateLabel(state)}; score_total ${scoreTotal.value.toStringAsFixed(2)} (${scoreTotal.band.label.toLowerCase()})',
    UnclassifiedEpisodeAnalysis(:final reason) =>
      'Sem classificação: ${reason.name}',
    null => 'Sem análise disponível',
  };
  final scoreDetails = switch (analysis) {
    ClassifiedEpisodeAnalysis(:final scoreTotal) =>
      scoreTotal.dimensions
          .map(
            (dimension) =>
                '${dimension.kind.label}: ${dimension.contribution.toStringAsFixed(2)}/${dimension.maxWeight.toStringAsFixed(2)}; '
                '${dimension.evidenceLabel}; versão ${dimension.version}; '
                'IRI ${dimension.iri ?? 'não aplicável'}; '
                'escopo ${dimension.scope ?? 'não aplicável'}; '
                'cautela ${dimension.caution}',
          )
          .join(' | '),
    _ => null,
  };
  return ScientificTraceability(
    metric: analysis is ClassifiedEpisodeAnalysis
        ? 'score_total'
        : 'duracao_episodio',
    value: analysis is ClassifiedEpisodeAnalysis
        ? analysis.scoreTotal.value.toStringAsFixed(2)
        : episode.duration.inMinutes.toString(),
    unit: analysis is ClassifiedEpisodeAnalysis ? 'escala 0-1' : 'minutos',
    period:
        '${_formatDateTime(episode.startedAt)}–${_formatTime(episode.endedAt)}',
    coverageStatus: day.coverageStatus,
    signalOrState: stateOrSignal,
    thresholdOrWeight: signal == null
        ? 'não aplicável'
        : scoreDetails ??
              '${signal.threshold.id}: ${signal.threshold.value} ${signal.threshold.unit}; peso ${signal.weight}',
    configurationVersion:
        analysis?.versions.calibrationVersion ?? 'indisponível',
    catalogVersion: analysis?.versions.catalogVersion ?? 'indisponível',
    owlIri: analysis?.versions.owxIri ?? 'urn:foco-tela:owl:indisponivel',
    caution:
        'Episódio observado localmente; a classificação é heurística e não diagnóstica.',
  );
}

BehavioralSignalObservation? _firstSignal(EpisodeAnalysisResult? analysis) {
  final signals = analysis?.signalObservations ?? const [];
  for (final signal in signals) {
    if (signal.isActive == true) return signal;
  }
  return signals.isEmpty ? null : signals.first;
}

class _ScientificTraceabilityPanel extends StatelessWidget {
  const _ScientificTraceabilityPanel({required this.traceability});

  final ScientificTraceability traceability;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('scientific-traceability-panel'),
      child: ExpansionTile(
        title: const Text('Rastreabilidade científica mínima'),
        subtitle: const Text(
          'Campos técnicos ficam em divulgação progressiva.',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _DetailRow(label: 'Métrica', value: traceability.metric),
          _DetailRow(label: 'Valor', value: traceability.value),
          _DetailRow(label: 'Unidade', value: traceability.unit),
          _DetailRow(label: 'Período', value: traceability.period),
          _DetailRow(
            label: 'Cobertura',
            value: traceability.coverageStatus.shortLabel,
          ),
          _DetailRow(label: 'Sinal/estado', value: traceability.signalOrState),
          _DetailRow(
            label: 'Limiar/peso',
            value: traceability.thresholdOrWeight,
          ),
          _DetailRow(
            label: 'Configuração',
            value: traceability.configurationVersion,
          ),
          _DetailRow(label: 'Catálogo', value: traceability.catalogVersion),
          _DetailRow(label: 'OWL', value: traceability.owlIri),
          _DetailRow(label: 'Cautela', value: traceability.caution),
        ],
      ),
    );
  }
}

class DayDetailPage extends StatefulWidget {
  const DayDetailPage({super.key, required this.summary});

  final DailyUsageSummary summary;

  @override
  State<DayDetailPage> createState() => _DayDetailPageState();
}

class _DayDetailPageState extends State<DayDetailPage> {
  String? _appFilter;
  BehavioralScoreRange? _intensityFilter;
  BehavioralSignalKind? _activeSignalFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = widget.summary;
    final episodes = _filteredEpisodes(summary);
    final appNames =
        summary.episodes.map((episode) => episode.displayName).toSet().toList()
          ..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text(_dayLabel(summary.dayStart, summary.lastUpdatedAt)),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth >= 600 ? 32.0 : 16.0;
          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _dayLabel(
                                summary.dayStart,
                                summary.lastUpdatedAt,
                              ),
                              style: theme.textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _CoverageBadge(status: summary.coverageStatus),
                                const SizedBox(width: 12),
                                Text(
                                  'Atualizado em ${_formatDateTime(summary.lastUpdatedAt)}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                            if (summary.analyzedThrough != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Analisado até ${_formatDateTime(summary.analyzedThrough!)} · provisório',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                            const SizedBox(height: 16),
                            _DailyAnalyticPriority(summary: summary),
                            const SizedBox(height: 16),
                            Text(
                              'Métricas observadas complementares',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            _ObservedMetricWrap(summary: summary),
                            if (summary.issueMessage != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                summary.issueMessage!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Episódios observados',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Filtrar episódios do dia',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Este filtro está restrito a ${_formatDate(summary.dayStart)}. '
                      'Use Explorar episódios na área Análises para múltiplas datas ou janelas.',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (summary.episodes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          DropdownButton<String?>(
                            key: const ValueKey('day-episode-app-filter'),
                            value: _appFilter,
                            hint: const Text('App do dia'),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Todos os apps do dia'),
                              ),
                              for (final appName in appNames)
                                DropdownMenuItem<String?>(
                                  value: appName,
                                  child: Text(appName),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _appFilter = value),
                          ),
                          DropdownButton<BehavioralScoreRange?>(
                            key: const ValueKey('day-episode-intensity-filter'),
                            value: _intensityFilter,
                            hint: const Text('Intensidade no dia'),
                            items: [
                              const DropdownMenuItem<BehavioralScoreRange?>(
                                value: null,
                                child: Text('Todas intensidades do dia'),
                              ),
                              for (final range in BehavioralScoreRange.values)
                                DropdownMenuItem<BehavioralScoreRange?>(
                                  value: range,
                                  child: Text(range.label),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _intensityFilter = value),
                          ),
                          DropdownButton<BehavioralSignalKind?>(
                            key: const ValueKey('day-episode-signal-filter'),
                            value: _activeSignalFilter,
                            hint: const Text('Sinal ativo no dia'),
                            items: [
                              const DropdownMenuItem<BehavioralSignalKind?>(
                                value: null,
                                child: Text('Todos os sinais do dia'),
                              ),
                              for (final signal in BehavioralSignalKind.values)
                                DropdownMenuItem<BehavioralSignalKind?>(
                                  value: signal,
                                  child: Text(signal.label),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _activeSignalFilter = value),
                          ),
                          TextButton.icon(
                            key: const ValueKey('day-episode-clear-filters'),
                            onPressed: () => setState(() {
                              _appFilter = null;
                              _intensityFilter = null;
                              _activeSignalFilter = null;
                            }),
                            icon: const Icon(Icons.clear),
                            label: const Text('Limpar filtros do dia'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_activeFilterCount()} filtro(s) do dia ativo(s) · '
                        '${episodes.length} episódio(s) neste dia',
                        key: const ValueKey('day-episode-active-filter-count'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (episodes.isEmpty) ...[
                      Text(
                        summary.appAggregates.isNotEmpty
                            ? 'Este dia está disponível apenas como agregado diário por aplicativo.'
                            : summary.episodes.isNotEmpty
                            ? 'Nenhum episódio deste dia corresponde aos filtros ativos.'
                            : summary.canOpenDetail
                            ? 'Nenhum episódio foi reconstruído para este dia.'
                            : 'A cobertura deste dia está indisponível.',
                      ),
                      if (summary.appAggregates.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        for (final aggregate in summary.appAggregates)
                          Card(
                            child: ListTile(
                              title: Text(aggregate.appName),
                              subtitle: Text(
                                '${aggregate.episodeCount} episódio(s) agregados · '
                                '${aggregate.coverageStatus.shortLabel}',
                              ),
                              trailing: Text(
                                _formatDuration(aggregate.duration),
                              ),
                            ),
                          ),
                      ],
                    ] else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: episodes.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final episode = episodes[index];
                          return _EpisodeTile(
                            key: ValueKey('episode-$index'),
                            episode: episode,
                            formatDateTime: _formatDateTime,
                            formatDuration: _formatDuration,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => EpisodeDetailPage(
                                    episode: episode,
                                    day: summary,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    const SizedBox(height: 16),
                    _ScientificTraceabilityPanel(
                      traceability: _dailyTraceability(summary),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<SmartphoneUsageEpisode> _filteredEpisodes(DailyUsageSummary summary) {
    final filtered = summary.episodes.where((episode) {
      final analysis = summary.analysisForEpisode(episode);
      final intensity = switch (analysis) {
        ClassifiedEpisodeAnalysis(:final behavioralScore) =>
          behavioralScore.range,
        _ => null,
      };
      return (_appFilter == null || episode.displayName == _appFilter) &&
          (_intensityFilter == null || intensity == _intensityFilter) &&
          _matchesDaySignal(analysis);
    }).toList();
    filtered.sort((left, right) => right.duration.compareTo(left.duration));
    return filtered;
  }

  bool _matchesDaySignal(EpisodeAnalysisResult? analysis) {
    final signal = _activeSignalFilter;
    if (signal == null) return true;
    return analysis?.signalObservations.any(
          (observation) =>
              observation.kind == signal && observation.isActive == true,
        ) ==
        true;
  }

  int _activeFilterCount() => [
    _appFilter,
    _intensityFilter,
    _activeSignalFilter,
  ].where((filter) => filter != null).length;
}

class _DailyAnalyticPriority extends StatelessWidget {
  const _DailyAnalyticPriority({required this.summary});

  final DailyUsageSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Números analíticos TCC/OWL', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth >= 560
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _AnalyticMetricTile(
                  width: itemWidth,
                  label: 'Episódios com sinais',
                  value: '${_episodesWithSignals(summary)}',
                ),
                _AnalyticMetricTile(
                  width: itemWidth,
                  label: 'Maior intensidade',
                  value: _maxIntensityLabel(summary),
                ),
                _AnalyticMetricTile(
                  width: itemWidth,
                  label: 'Sinais ativos distintos',
                  value: '${_distinctActiveSignals(summary)}',
                ),
                _AnalyticMetricTile(
                  width: itemWidth,
                  label: 'Tempo em contexto OWL aprovado',
                  value: _approvedContextShareLabel(summary),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ObservedMetricWrap extends StatelessWidget {
  const _ObservedMetricWrap({required this.summary});

  final DailyUsageSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DetailRow(
          label: 'Tempo ativo total',
          value: summary.totalUsage == null
              ? 'Sem métricas disponíveis'
              : _formatDuration(summary.totalUsage!),
        ),
        _DetailRow(
          label: 'Notificações',
          value: summary.notificationCount == null
              ? 'Indisponíveis'
              : '${summary.notificationCount} observadas',
        ),
        _DetailRow(
          label: 'Desbloqueios',
          value: summary.analysis == null
              ? 'Indisponíveis'
              : '${summary.analysis!.unlockCount}',
        ),
        _DetailRow(
          label: 'Estados',
          value: _formatStateDistribution(summary.stateDistribution),
        ),
        _DetailRow(label: 'App principal', value: _topAppLabel(summary)),
      ],
    );
  }
}

class _AnalyticMetricTile extends StatelessWidget {
  const _AnalyticMetricTile({
    required this.width,
    required this.label,
    required this.value,
  });

  final double width;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month';
}

String _formatTime(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatDateTime(DateTime dateTime) =>
    '${_formatDate(dateTime)} ${_formatTime(dateTime)}';

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    if (minutes == 0 && seconds == 0) {
      return '$hours h';
    }
    return '$hours h ${minutes.toString().padLeft(2, '0')} min';
  }
  if (minutes > 0) {
    if (seconds == 0) {
      return '$minutes min';
    }
    return '$minutes min ${seconds.toString().padLeft(2, '0')} s';
  }
  return '$seconds s';
}

String _dayLabel(DateTime dayStart, [DateTime? referenceDay]) {
  final today = referenceDay ?? DateTime.now();
  if (_isSameCivilDay(dayStart, today)) {
    return 'Hoje · ${_formatDate(dayStart)}';
  }
  final yesterday = today.subtract(const Duration(days: 1));
  if (_isSameCivilDay(dayStart, yesterday)) {
    return 'Ontem · ${_formatDate(dayStart)}';
  }
  return _formatDate(dayStart);
}

bool _isSameCivilDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

String _dayKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isError
              ? theme.colorScheme.onErrorContainer
              : theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    super.key,
    required this.episode,
    required this.formatDateTime,
    required this.formatDuration,
    required this.onTap,
  });

  final SmartphoneUsageEpisode episode;
  final String Function(DateTime) formatDateTime;
  final String Function(Duration) formatDuration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(episode.displayName),
        subtitle: Text(
          'Início ${formatDateTime(episode.startedAt)} · '
          'Fim ${formatDateTime(episode.endedAt)}',
        ),
        trailing: Text(formatDuration(episode.duration)),
      ),
    );
  }
}

class EpisodeDetailPage extends StatelessWidget {
  const EpisodeDetailPage({
    super.key,
    required this.episode,
    required this.day,
  });

  final SmartphoneUsageEpisode episode;
  final DailyUsageSummary day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final analysis = day.analysisForEpisode(episode);
    return Scaffold(
      appBar: AppBar(title: Text(episode.displayName)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth >= 600 ? 32.0 : 16.0;
          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              episode.displayName,
                              style: theme.textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _episodePriorityHeadline(episode, analysis),
                              key: const ValueKey(
                                'episode-detail-priority-headline',
                              ),
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _EpisodeContextChips(analysis: analysis),
                            const SizedBox(height: 16),
                            _DetailRow(
                              label: 'Aplicativo',
                              value: episode.displayName,
                            ),
                            _DetailRow(
                              label: 'Pacote',
                              value: episode.packageName,
                            ),
                            _DetailRow(
                              label: 'Início',
                              value: _formatDateTime(episode.startedAt),
                            ),
                            _DetailRow(
                              label: 'Fim',
                              value: _formatDateTime(episode.endedAt),
                            ),
                            _DetailRow(
                              label: 'Duração ativa',
                              value: _formatDuration(episode.duration),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    EpisodeAnalysisSection(result: analysis),
                    const SizedBox(height: 16),
                    _ScientificTraceabilityPanel(
                      traceability: _episodeTraceability(
                        episode,
                        day,
                        analysis,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CatalogContextSection(episode: episode),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EpisodeContextChips extends StatelessWidget {
  const _EpisodeContextChips({required this.analysis});

  final EpisodeAnalysisResult? analysis;

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (final BehavioralSignalObservation signal
          in analysis?.signalObservations ??
              const <BehavioralSignalObservation>[])
        if (signal.isActive == true) 'Sinal: ${signal.kind.label}',
      if (analysis case ClassifiedEpisodeAnalysis(:final context))
        for (final contribution in context.contributions) contribution.label,
    ];
    if (chips.isEmpty) {
      return const Text('Sem sinais ativos ou contexto OWL aplicável no topo.');
    }
    return Wrap(
      key: const ValueKey('episode-detail-signal-context-chips'),
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in chips.toSet())
          Chip(visualDensity: VisualDensity.compact, label: Text(label)),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
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

@Preview(
  name: 'Analises resumo estreito',
  group: 'Analises',
  size: Size(390, 640),
)
Widget analysisSummaryPreview() => _PreviewShell(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _WindowSelector(
        selectedWindow: AnalysisWindow.sevenDays,
        onSelected: (_) {},
      ),
      const SizedBox(height: 16),
      _WeeklySummaryCard(
        cardKey: const ValueKey('preview-analysis-window-summary'),
        data: const AnalysisWindowSummary(
          title: 'Resumo da janela',
          headline:
              'O tempo de tela observado reduziu em relação à janela anterior.',
          coverageLabel: 'Cobertura: 6 de 7 dias carregados',
          metrics: [
            AnalysisMetric(label: 'Tempo de tela', value: '9 h 20 min'),
            AnalysisMetric(label: 'Episódios', value: '18'),
            AnalysisMetric(label: 'Notificações', value: '42'),
          ],
          notificationLabel: null,
        ),
        onTodayTap: null,
      ),
    ],
  ),
);

@Preview(
  name: 'Analises sinais e mudancas',
  group: 'Analises',
  size: Size(390, 720),
)
Widget analysisSignalsPreview() => _PreviewShell(
  child: Column(
    children: const [
      _ObservedConceptsCard(
        concepts: [
          ObservedConcept(
            category: 'Sinal comportamental',
            label: 'Sessão longa',
            detail: '1200 seconds; limiar 15 minutes',
            iri: 'longSessionDuration',
            evidence: 'observado localmente',
            scope: 'episode',
            version: '2026-06-21-v1',
            caution: 'Sinal descritivo; não indica diagnóstico.',
          ),
          ObservedConcept(
            category: 'Técnica psicológica',
            label: 'Validação social',
            detail: 'Evidência média',
            iri: 'SocialValidation',
            evidence: 'instagram_play_listing',
            scope: 'app_specific_catalog_association',
            version: 'catalog-preview',
            caution: 'Associação curada exploratória.',
          ),
        ],
      ),
      SizedBox(height: 12),
      _PeriodChangeCard(
        summary: PeriodChangeSummary(
          priority: PeriodChangePriority.retention,
          title: 'Mudanças no período',
          headline:
              'Indícios de retenção aparecem em 2 episódio(s) altos e 3 moderados.',
          detail:
              'A leitura usa episódios da janela e não cria score longitudinal.',
          caution: 'Comparação exploratória.',
        ),
      ),
    ],
  ),
);

@Preview(
  name: 'Analises episodios vazios',
  group: 'Analises',
  size: Size(390, 720),
)
Widget analysisEpisodesPreview() => _PreviewApp(
  child: EpisodeExplorerPage(
    dashboard: WeeklyUsageDashboard(
      generatedAt: DateTime(2026, 6, 26, 10),
      days: [
        DailyUsageSummary(
          dayStart: DateTime(2026, 6, 26),
          coverageStatus: CoverageStatus.sufficient,
          lastUpdatedAt: DateTime(2026, 6, 26, 10),
          totalUsage: Duration.zero,
          analysis: null,
        ),
      ],
    ),
  ),
);

class _PreviewShell extends StatelessWidget {
  const _PreviewShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _PreviewApp(
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(theme: ThemeData(useMaterial3: true), home: child);
  }
}
