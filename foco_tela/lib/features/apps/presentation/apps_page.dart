import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../catalog/data/app_catalog_repository.dart';
import '../../catalog/data/app_identity_repository.dart';
import '../../catalog/domain/app_catalog.dart';
import '../../catalog/presentation/catalog_context_status_chip.dart';
import '../../dashboard/domain/daily_usage_summary.dart';
import '../../dashboard/presentation/dashboard_view_model.dart';
import '../../usage_access/presentation/usage_access_ui_state.dart';
import 'apps_presenter.dart';

enum AppsStatusFilter { all, approved, candidateAutomatic, insufficient }

extension AppsStatusFilterLabel on AppsStatusFilter {
  String get label => switch (this) {
    AppsStatusFilter.all => 'Todos',
    AppsStatusFilter.approved => 'Aprovado',
    AppsStatusFilter.candidateAutomatic => 'Sugerido',
    AppsStatusFilter.insufficient => 'Não avaliado',
  };

  CatalogContextStatus? get status => switch (this) {
    AppsStatusFilter.all => null,
    AppsStatusFilter.approved => CatalogContextStatus.approved,
    AppsStatusFilter.candidateAutomatic =>
      CatalogContextStatus.candidateAutomatic,
    AppsStatusFilter.insufficient => CatalogContextStatus.insufficient,
  };
}

class AppsPage extends StatelessWidget {
  const AppsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardViewModel>(
      builder: (context, viewModel, _) {
        final dashboard = viewModel.dashboard;
        return Scaffold(
          appBar: AppBar(title: const Text('Apps')),
          body: switch (viewModel.usageAccessState) {
            UsageAccessChecking() => const _AppsLoadingState(),
            UsageAccessDenied() => const _AppsMessageState(
              title: 'Acesso ao uso ausente',
              message:
                  'Sem a permissão, a área Apps não lista métricas, fixtures '
                  'ou zeros. Conceda acesso ao uso e volte para verificar.',
            ),
            UsageSettingsOpening() ||
            UsageSettingsOpened() => const _AppsMessageState(
              title: 'Verifique o acesso novamente',
              message:
                  'Depois de retornar das configurações do Android, use a '
                  'aba Hoje para reverificar o acesso e carregar os dados.',
            ),
            UsageSettingsOpenError(:final message) ||
            UsageAccessCheckError(:final message) => _AppsMessageState(
              title: 'Não foi possível verificar o acesso',
              message: message,
            ),
            UsageAccessGranted() => switch ((
              viewModel.isLoading,
              viewModel.historyWasCleared,
              dashboard,
              viewModel.errorMessage,
            )) {
              (true, _, _, _) => const _AppsLoadingState(),
              (_, true, _, _) => const _AppsMessageState(
                title: 'Histórico derivado apagado',
                message:
                    'A área Apps será reconstruída quando houver nova leitura '
                    'observável do Android.',
              ),
              (_, false, final loadedDashboard?, _) => _AppsPageBody(
                dashboard: loadedDashboard,
              ),
              (_, false, null, final message) when message != null =>
                _AppsMessageState(
                  title: 'Não foi possível carregar Apps',
                  message: message,
                ),
              _ => const _AppsMessageState(
                title: 'Sem apps observados',
                message:
                    'Ainda não há leitura observável para montar o inventário '
                    'de aplicativos.',
              ),
            },
          },
        );
      },
    );
  }
}

class _AppsPageBody extends StatefulWidget {
  const _AppsPageBody({required this.dashboard});

  final WeeklyUsageDashboard dashboard;

  @override
  State<_AppsPageBody> createState() => _AppsPageBodyState();
}

class _AppsPageBodyState extends State<_AppsPageBody> {
  late Future<AppsOverviewModel> _modelFuture;
  AppsStatusFilter _filter = AppsStatusFilter.all;

  @override
  void initState() {
    super.initState();
    _modelFuture = _loadModel();
  }

  @override
  void didUpdateWidget(covariant _AppsPageBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dashboard.generatedAt != widget.dashboard.generatedAt ||
        oldWidget.dashboard.window != widget.dashboard.window) {
      _modelFuture = _loadModel();
    }
  }

  Future<AppsOverviewModel> _loadModel({bool refreshIdentities = false}) async {
    final catalogRepository = context.read<AppCatalogRepository>();
    final identityRepository = context.read<AppIdentityRepository>();
    final catalog = await catalogRepository.loadSnapshot();
    final packageNames = _observedPackageNames(widget.dashboard);
    final identities = await identityRepository.resolveMany(
      packageNames,
      refresh: refreshIdentities,
    );
    return const AppsPresenter().present(
      dashboard: widget.dashboard,
      catalog: catalog,
      identitiesByPackageName: {
        for (final identity in identities) identity.packageName: identity,
      },
    );
  }

  Set<String> _observedPackageNames(WeeklyUsageDashboard dashboard) {
    final packageNames = <String>{};
    for (final day in dashboard.days) {
      for (final aggregate in day.appAggregates) {
        packageNames.add(aggregate.packageName);
      }
      for (final episode in day.episodes) {
        packageNames.add(episode.packageName);
      }
    }
    if (dashboard.notificationAvailability.isAvailable) {
      for (final count in dashboard.notificationCounts) {
        packageNames.add(count.packageName);
      }
    }
    return packageNames;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppsOverviewModel>(
      future: _modelFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _AppsLoadingState();
        }
        if (snapshot.hasError) {
          return _AppsErrorState(
            onRetry: () => setState(() {
              _modelFuture = _loadModel();
            }),
          );
        }
        final model = snapshot.data;
        if (model == null || model.apps.isEmpty) {
          return const _AppsMessageState(
            title: 'Nenhum app observado',
            message:
                'A área Apps lista apenas aplicativos observados no histórico '
                'local carregado; ela não fabrica exemplos sem dados.',
          );
        }

        final status = _filter.status;
        final visibleApps = status == null
            ? model.apps
            : model.appsForStatus(status);

        return LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 600 ? 32.0 : 16.0;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    24,
                    horizontalPadding,
                    24,
                  ),
                  children: [
                    _AppsHeader(
                      model: model,
                      onRefresh: () => setState(() {
                        _modelFuture = _loadModel(refreshIdentities: true);
                      }),
                    ),
                    const SizedBox(height: 16),
                    _AppsFilterBar(
                      filter: _filter,
                      onChanged: (filter) => setState(() {
                        _filter = filter;
                      }),
                    ),
                    const SizedBox(height: 16),
                    if (visibleApps.isEmpty)
                      _FilterEmptyState(filter: _filter)
                    else
                      for (final app in visibleApps) ...[
                        _ObservedAppCard(app: app),
                        const SizedBox(height: 12),
                      ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AppsHeader extends StatelessWidget {
  const _AppsHeader({required this.model, required this.onRefresh});

  final AppsOverviewModel model;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Apps observados', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                '${model.apps.length} aplicativos observados no histórico '
                'local carregado.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Tipos sugeridos entram na análise com selo próprio; tipos '
                'aprovados vêm do catálogo curado do TCC.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        IconButton(
          key: const ValueKey('refresh-app-identities'),
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
          tooltip: 'Recarregar metadados locais',
        ),
      ],
    );
  }
}

class _AppsFilterBar extends StatelessWidget {
  const _AppsFilterBar({required this.filter, required this.onChanged});

  final AppsStatusFilter filter;
  final ValueChanged<AppsStatusFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<AppsStatusFilter>(
        key: const ValueKey('apps-status-filter'),
        selected: {filter},
        onSelectionChanged: (selection) => onChanged(selection.single),
        segments: [
          for (final item in AppsStatusFilter.values)
            ButtonSegment(value: item, label: Text(item.label)),
        ],
      ),
    );
  }
}

class _ObservedAppCard extends StatelessWidget {
  const _ObservedAppCard({required this.app});

  final AppsObservedApp app;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catalogApp = app.catalogApp;
    final candidateLabels = catalogApp?.contextProfile.candidateLabels ?? [];
    final approvedLabels = catalogApp?.contextProfile.approvedLabels ?? [];

    return Card(
      key: ValueKey('observed-app-card-${app.packageName}'),
      child: ExpansionTile(
        key: ValueKey('observed-app-detail-${app.packageName}'),
        leading: _AppAvatar(app: app),
        title: Text(app.displayName),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CatalogContextStatusChip(status: app.status, compact: true),
              Text('${_formatDuration(app.weekDuration)} na semana'),
              Text('${app.episodeCount} episódios'),
            ],
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          if (app.hasApprovedContext && approvedLabels.isNotEmpty)
            _DetailLine(
              label: 'Tipo aprovado',
              value: approvedLabels.join(' · '),
            ),
          if (app.hasCandidateSuggestion && candidateLabels.isNotEmpty)
            _DetailLine(
              label: 'Tipo sugerido',
              value:
                  '${candidateLabels.join(' · ')}. Entra na análise com selo '
                  'próprio.',
            ),
          if (app.status == CatalogContextStatus.insufficient)
            const _DetailLine(
              label: 'Tipo de aplicativo',
              value:
                  'Tipo não avaliado. As métricas observadas '
                  'continuam visíveis sem inferir mecanismo de retenção.',
            ),
          _DetailLine(
            label: 'Tempo de tela hoje',
            value: _formatDuration(app.todayDuration),
          ),
          _DetailLine(
            label: 'Tempo de tela na semana',
            value: _formatDuration(app.weekDuration),
          ),
          _DetailLine(
            label: 'Episódios do app',
            value:
                '${app.episodeCount} em ${app.coveredDayCount} '
                '${app.coveredDayCount == 1 ? 'dia' : 'dias'} observados',
          ),
          _DetailLine(
            label: 'Notificações observadas',
            value: switch (app.weekNotificationCount) {
              final int count => '$count na semana',
              null => 'indisponíveis para este app',
            },
          ),
          const _DetailLine(
            label: 'Desbloqueios',
            value:
                'Métrica diária contextual; não é atribuída causalmente a '
                'aplicativos específicos.',
          ),
          _DetailLine(label: 'Identificador técnico', value: app.packageName),
          _DetailLine(
            label: 'Categoria nativa Android',
            value: switch (app.identity.nativeCategoryLabel?.trim()) {
              final String label when label.isNotEmpty => label,
              _ => 'indisponível',
            },
          ),
          if (catalogApp != null) ...[
            _DetailLine(
              label: 'Técnica psicológica',
              value: catalogApp.psychologicalTechniqueLabel,
            ),
            _DetailLine(
              label: 'Intenção institucional',
              value: catalogApp.institutionalIntentionLabel,
            ),
          ],
          Text(
            '`NotificationCount` permanece separado de `score_sinais` na V3.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _AppAvatar extends StatelessWidget {
  const _AppAvatar({required this.app});

  final AppsObservedApp app;

  @override
  Widget build(BuildContext context) {
    if (app.identity.hasIcon) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          app.identity.iconPngBytes!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
        ),
      );
    }

    return CircleAvatar(
      radius: 20,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      child: Text(_initials(app.displayName)),
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1);
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}';
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

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
            width: 172,
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

class _FilterEmptyState extends StatelessWidget {
  const _FilterEmptyState({required this.filter});

  final AppsStatusFilter filter;

  @override
  Widget build(BuildContext context) => _AppsMessageState(
    title: 'Nenhum app neste filtro',
    message:
        'Não há aplicativos observados com status ${filter.label.toLowerCase()} '
        'no histórico local carregado.',
  );
}

class _AppsLoadingState extends StatelessWidget {
  const _AppsLoadingState();

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(key: ValueKey('apps-loading-state')),
  );
}

class _AppsErrorState extends StatelessWidget {
  const _AppsErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Não foi possível carregar Apps',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'O catálogo, as métricas observadas ou os metadados locais não '
            'puderam ser combinados neste momento.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );
}

class _AppsMessageState extends StatelessWidget {
  const _AppsMessageState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.apps_outlined,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0 && minutes > 0) {
    return '${hours}h ${minutes}min';
  }
  if (hours > 0) {
    return '${hours}h';
  }
  return '${minutes}min';
}
