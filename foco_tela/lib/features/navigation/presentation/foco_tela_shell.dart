import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../apps/presentation/apps_page.dart';
import '../../catalog/data/app_catalog_repository.dart';
import '../../dashboard/domain/daily_usage_summary.dart';
import '../../dashboard/domain/derived_analysis_repository.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../dashboard/presentation/dashboard_view_model.dart';
import 'hoje_overview.dart';
import '../../settings/presentation/settings_privacy_page.dart';
import '../../settings/presentation/settings_privacy_view_model.dart';
import '../../notifications/domain/notification_observation.dart';
import '../../usage_access/domain/usage_access.dart';
import '../../usage_access/presentation/usage_access_ui_state.dart';

enum _FocoTelaArea { hoje, analises, apps, configuracoes }

extension on _FocoTelaArea {
  String get label => switch (this) {
    _FocoTelaArea.hoje => 'Hoje',
    _FocoTelaArea.analises => 'Análises',
    _FocoTelaArea.apps => 'Apps',
    _FocoTelaArea.configuracoes => 'Ajustes',
  };

  IconData get icon => switch (this) {
    _FocoTelaArea.hoje => Icons.today_outlined,
    _FocoTelaArea.analises => Icons.analytics_outlined,
    _FocoTelaArea.apps => Icons.apps_outlined,
    _FocoTelaArea.configuracoes => Icons.settings_outlined,
  };

  Key get key => ValueKey<String>('nav-$name');
}

class FocoTelaShell extends StatefulWidget {
  const FocoTelaShell({super.key, this.now});

  final DateTime Function()? now;

  @override
  State<FocoTelaShell> createState() => _FocoTelaShellState();
}

class _FocoTelaShellState extends State<FocoTelaShell> {
  int _selectedIndex = 0;
  late final List<Widget?> _pageCache = List<Widget?>.filled(
    _FocoTelaArea.values.length,
    null,
  );

  void _selectIndex(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _pageForIndex(int index) {
    final cachedPage = _pageCache[index];
    if (cachedPage != null) {
      return cachedPage;
    }
    if (index != _selectedIndex) {
      return const SizedBox.shrink();
    }

    final area = _FocoTelaArea.values[index];
    final page = switch (area) {
      _FocoTelaArea.hoje => HojePage(
        key: const ValueKey('hoje-page'),
        onOpenAnalises: () => _selectIndex(_FocoTelaArea.analises.index),
      ),
      _FocoTelaArea.analises => const DashboardPage(
        key: ValueKey('analises-page'),
      ),
      _FocoTelaArea.apps => const AppsPage(key: ValueKey('apps-page')),
      _FocoTelaArea.configuracoes => SettingsAreaPage(
        key: ValueKey('configuracoes-page'),
        now: widget.now,
      ),
    };
    _pageCache[index] = page;
    return page;
  }

  @override
  Widget build(BuildContext context) {
    final pages = List<Widget>.generate(
      _FocoTelaArea.values.length,
      _pageForIndex,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 900;
        final navigationAreas = _FocoTelaArea.values;

        if (useRail) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: _selectIndex,
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      for (final area in navigationAreas)
                        NavigationRailDestination(
                          icon: Icon(area.icon, key: area.key),
                          selectedIcon: Icon(area.icon),
                          label: Text(area.label),
                        ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: IndexedStack(index: _selectedIndex, children: pages),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: IndexedStack(index: _selectedIndex, children: pages),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _selectIndex,
            destinations: [
              for (final area in navigationAreas)
                NavigationDestination(
                  icon: Icon(area.icon, key: area.key),
                  selectedIcon: Icon(area.icon),
                  label: area.label,
                ),
            ],
          ),
        );
      },
    );
  }
}

class HojePage extends StatelessWidget {
  const HojePage({super.key, this.onOpenAnalises});

  final VoidCallback? onOpenAnalises;

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardViewModel>(
      builder: (context, viewModel, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Hoje')),
          body: switch (viewModel.usageAccessState) {
            UsageAccessChecking() => const _AreaLoadingState(
              key: ValueKey('today-loading-state'),
              loadingKey: ValueKey('dashboard-loading-state'),
              loadingLabel: 'Carregando análise retrospectiva…',
            ),
            UsageAccessDenied() => _UsageAccessPrompt(
              onOpenSettings: viewModel.requestPermission,
              onRecheck: viewModel.refresh,
            ),
            UsageSettingsOpening() => _UsageAccessPrompt(
              onOpenSettings: viewModel.requestPermission,
              onRecheck: viewModel.refresh,
              statusMessage: 'Abrindo as configurações do Android…',
              isOpeningSettings: true,
            ),
            UsageSettingsOpened() => _UsageAccessPrompt(
              onOpenSettings: viewModel.requestPermission,
              onRecheck: viewModel.refresh,
              statusMessage:
                  'Configurações abertas. Ao retornar, verifique novamente o acesso.',
            ),
            UsageSettingsOpenError(:final message) => _UsageAccessPrompt(
              onOpenSettings: viewModel.requestPermission,
              onRecheck: viewModel.refresh,
              statusMessage: message,
              isError: true,
            ),
            UsageAccessCheckError(:final message) => _AreaErrorState(
              title: 'Não foi possível carregar Hoje',
              message: message,
              actionLabel: 'Tentar novamente',
              onPressed: viewModel.refresh,
            ),
            UsageAccessGranted() => switch ((
              viewModel.isLoading,
              viewModel.historyWasCleared,
              viewModel.dashboard,
              viewModel.errorMessage,
            )) {
              (true, _, _, _) => const _AreaLoadingState(
                loadingKey: ValueKey('dashboard-loading-state'),
                loadingLabel: 'Carregando análise retrospectiva…',
              ),
              (_, true, _, _) => const _ClearedHistoryState(
                key: ValueKey('history-cleared-state'),
              ),
              (_, false, final dashboard?, _) => _TodayOverview(
                dashboard: dashboard,
                onOpenAnalises: onOpenAnalises,
              ),
              (_, false, null, final message) when message != null =>
                _AreaErrorState(
                  title: 'Não foi possível carregar Hoje',
                  message: message,
                  actionLabel: 'Tentar novamente',
                  onPressed: viewModel.refresh,
                ),
              _ => _AreaErrorState(
                title: 'Não foi possível montar Hoje',
                message:
                    'A leitura inicial do dia não pôde ser montada a partir '
                    'dos dados disponíveis.',
                actionLabel: 'Tentar novamente',
                onPressed: viewModel.refresh,
              ),
            },
          },
        );
      },
    );
  }
}

class _TodayOverview extends StatelessWidget {
  const _TodayOverview({required this.dashboard, required this.onOpenAnalises});

  final WeeklyUsageDashboard dashboard;
  final VoidCallback? onOpenAnalises;

  @override
  Widget build(BuildContext context) =>
      HojeOverview(dashboard: dashboard, onOpenAnalises: onOpenAnalises);
}

class SettingsAreaPage extends StatefulWidget {
  const SettingsAreaPage({super.key, this.now});

  final DateTime Function()? now;

  @override
  State<SettingsAreaPage> createState() => _SettingsAreaPageState();
}

class _SettingsAreaPageState extends State<SettingsAreaPage> {
  late final SettingsPrivacyViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = SettingsPrivacyViewModel(
      usageAccessRepository: context.read<UsageAccessRepository>(),
      catalogRepository: context.read<AppCatalogRepository>(),
      derivedRepository: context.read<DerivedAnalysisRepository>(),
      notificationRepository: context.read<NotificationRepository>(),
      now: widget.now,
      onHistoryCleared: () =>
          context.read<DashboardViewModel>().forgetDerivedHistoryFromUi(),
    );
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: const SettingsPrivacyPage(),
    );
  }
}

class _UsageAccessPrompt extends StatelessWidget {
  const _UsageAccessPrompt({
    required this.onOpenSettings,
    required this.onRecheck,
    this.statusMessage,
    this.isOpeningSettings = false,
    this.isError = false,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onRecheck;
  final String? statusMessage;
  final bool isOpeningSettings;
  final bool isError;

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
              const Text(
                'Esse acesso permite ler localmente o tempo de uso dos '
                'aplicativos e construir a análise retrospectiva. O Foco '
                'Tela não lê conteúdo e não envia esses dados para a nuvem.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Sem a permissão, nenhuma métrica é exibida e a ausência de '
                'acesso não é tratada como uso zero.',
                textAlign: TextAlign.center,
              ),
              if (statusMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  statusMessage!,
                  style: TextStyle(
                    color: isError ? theme.colorScheme.error : null,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const ValueKey('usage-access-open-settings'),
                  onPressed: isOpeningSettings ? null : onOpenSettings,
                  child: isOpeningSettings
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Abrir configurações de acesso ao uso'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const ValueKey('usage-access-recheck'),
                onPressed: isOpeningSettings ? null : onRecheck,
                child: const Text('Verificar acesso novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AreaLoadingState extends StatelessWidget {
  const _AreaLoadingState({
    super.key,
    required this.loadingKey,
    required this.loadingLabel,
  });

  final Key loadingKey;
  final String loadingLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        key: loadingKey,
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(loadingLabel),
        ],
      ),
    );
  }
}

class _AreaErrorState extends StatelessWidget {
  const _AreaErrorState({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

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
    );
  }
}

class _ClearedHistoryState extends StatelessWidget {
  const _ClearedHistoryState({super.key});

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
                'Episódios, agregados, coberturas e análises foram removidos. '
                'Uma atualização explícita poderá reconstruir novos resultados '
                'a partir dos dados de uso disponíveis.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
