import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../catalog/data/app_catalog_repository.dart';
import '../../catalog/data/app_identity_repository.dart';
import '../../catalog/domain/app_catalog.dart';
import '../../catalog/domain/app_identity.dart';
import '../../catalog/presentation/catalog_context_status_chip.dart';
import '../../dashboard/domain/app_daily_aggregate.dart';
import '../../dashboard/domain/behavioral_signal_calibration.dart';
import '../../dashboard/domain/daily_usage_summary.dart';
import '../../dashboard/domain/episode_analysis.dart';
import '../../dashboard/domain/score_total.dart';

enum TodayGrouping { category, app }

extension TodayGroupingLabel on TodayGrouping {
  String get label => switch (this) {
    TodayGrouping.category => 'Tipo',
    TodayGrouping.app => 'App',
  };

  String get shortLabel => switch (this) {
    TodayGrouping.category => 'categoria',
    TodayGrouping.app => 'app',
  };
}

class HojeOverview extends StatefulWidget {
  const HojeOverview({super.key, required this.dashboard, this.onOpenAnalises});

  final WeeklyUsageDashboard dashboard;
  final VoidCallback? onOpenAnalises;

  @override
  State<HojeOverview> createState() => _HojeOverviewState();
}

class _HojeOverviewState extends State<HojeOverview> {
  late Future<_HojeOverviewResources> _resourcesFuture;
  TodayGrouping _grouping = TodayGrouping.category;
  String? _selectedSliceId;

  @override
  void initState() {
    super.initState();
    _resourcesFuture = _loadResources();
  }

  @override
  void didUpdateWidget(covariant HojeOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_observedPackages(oldWidget.dashboard) !=
        _observedPackages(widget.dashboard)) {
      _resourcesFuture = _loadResources();
      _selectedSliceId = null;
    }
  }

  Future<_HojeOverviewResources> _loadResources() async {
    final catalogRepository = context.read<AppCatalogRepository>();
    final identityRepository = context.read<AppIdentityRepository>();
    final catalog = await catalogRepository.loadSnapshot();
    final packageNames = _observedPackages(widget.dashboard);
    final identities = await identityRepository.resolveMany(packageNames);
    final identitiesByPackageName = {
      for (final identity in identities) identity.packageName: identity,
    };
    return _HojeOverviewResources(
      catalog: catalog,
      identitiesByPackageName: identitiesByPackageName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = widget.dashboard.days.first;
    final notificationLabel = switch (today.notificationCount) {
      final int value => '$value notificações observadas',
      null => widget.dashboard.notificationAvailability.label,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 600 ? 32.0 : 16.0;

        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: FutureBuilder<_HojeOverviewResources>(
                future: _resourcesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const _TodayLoadingState();
                  }

                  if (snapshot.hasError) {
                    return _TodayErrorState(
                      title: 'Não foi possível montar Hoje',
                      message:
                          'O catálogo ou os metadados locais não puderam ser '
                          'carregados para compor a leitura observacional.',
                      actionLabel: 'Tentar novamente',
                      onPressed: () => setState(() {
                        _resourcesFuture = _loadResources();
                      }),
                    );
                  }

                  final resources = snapshot.data;
                  if (resources == null) {
                    return _TodayErrorState(
                      title: 'Não foi possível montar Hoje',
                      message:
                          'A leitura inicial do dia não pôde ser montada a '
                          'partir dos dados disponíveis.',
                      actionLabel: 'Tentar novamente',
                      onPressed: () => setState(() {
                        _resourcesFuture = _loadResources();
                      }),
                    );
                  }

                  final presenter = const TodayOverviewPresenter();
                  final model = presenter.present(
                    dashboard: widget.dashboard,
                    catalog: resources.catalog,
                    identitiesByPackageName: resources.identitiesByPackageName,
                    grouping: _grouping,
                  );
                  final selectedSliceId =
                      _selectedSliceId ??
                      (model.slices.isEmpty ? null : model.slices.first.id);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TodayHeroCard(
                        model: model,
                        today: today,
                        notificationLabel: notificationLabel,
                      ),
                      const SizedBox(height: 16),
                      _TodayRingCard(
                        grouping: _grouping,
                        model: model,
                        selectedSliceId: selectedSliceId,
                        onGroupingChanged: (grouping) {
                          setState(() {
                            _grouping = grouping;
                            _selectedSliceId = null;
                          });
                        },
                        onSliceSelected: (sliceId) {
                          setState(() {
                            _selectedSliceId = sliceId;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      _TodaySignalsCard(signals: model.signals),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            key: const ValueKey('open-analises-from-hoje'),
                            onPressed: widget.onOpenAnalises,
                            icon: const Icon(Icons.analytics_outlined),
                            label: const Text('Ver análises longitudinais'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (!widget.dashboard.days.any(
                        (day) => (day.episodeCount ?? 0) > 0,
                      )) ...[
                        const _TodayEmptyDashboardNotice(),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class TodayOverviewPresenter {
  const TodayOverviewPresenter();

  TodayOverviewData present({
    required WeeklyUsageDashboard dashboard,
    required CatalogSnapshot catalog,
    required Map<String, AppIdentity> identitiesByPackageName,
    required TodayGrouping grouping,
  }) {
    final today = dashboard.days.first;
    final apps = _observedAppsForDay(
      day: today,
      catalog: catalog,
      identitiesByPackageName: identitiesByPackageName,
    );
    final totalUsage = today.totalUsage ?? _sumDuration(apps);
    final slices = switch (grouping) {
      TodayGrouping.category => _categorySlices(apps),
      TodayGrouping.app => _appSlices(apps),
    };
    final approvedDuration = apps.fold<Duration>(
      Duration.zero,
      (total, app) => app.hasApprovedContext ? total + app.duration : total,
    );
    final evaluatedTypeDuration = apps.fold<Duration>(
      Duration.zero,
      (total, app) => app.hasEvaluatedType ? total + app.duration : total,
    );
    final screenTimeAvailable =
        today.totalUsage != null || today.analysis != null;
    final approvedContextShare = today.analysis == null
        ? null
        : totalUsage == Duration.zero
        ? 0.0
        : approvedDuration.inMilliseconds / totalUsage.inMilliseconds;
    final evaluatedTypeShare = today.analysis == null
        ? null
        : totalUsage == Duration.zero
        ? 0.0
        : evaluatedTypeDuration.inMilliseconds / totalUsage.inMilliseconds;
    final signals = _buildSignals(
      today,
      approvedContextShare: approvedContextShare,
      evaluatedTypeShare: evaluatedTypeShare,
    );
    final retentionIndications = _buildRetentionIndications(
      signals: signals,
      evaluatedTypeShare: evaluatedTypeShare,
      screenTimeAvailable: screenTimeAvailable,
    );

    return TodayOverviewData(
      coverageStatus: today.coverageStatus,
      screenTimeAvailable: screenTimeAvailable,
      screenTime: totalUsage,
      unlockCount: today.analysis?.unlockCount,
      notificationCount: today.notificationCount,
      approvedContextShare: approvedContextShare,
      evaluatedTypeShare: evaluatedTypeShare,
      retentionIndications: retentionIndications,
      slices: slices,
      signals: signals,
    );
  }

  List<TodayObservedApp> _observedAppsForDay({
    required DailyUsageSummary day,
    required CatalogSnapshot catalog,
    required Map<String, AppIdentity> identitiesByPackageName,
  }) {
    final aggregates = day.appAggregates.isNotEmpty
        ? day.appAggregates
        : _fallbackAggregates(day);
    final ordered = [...aggregates]
      ..sort((left, right) {
        final durationOrder = right.duration.compareTo(left.duration);
        if (durationOrder != 0) return durationOrder;
        final episodeOrder = right.episodeCount.compareTo(left.episodeCount);
        if (episodeOrder != 0) return episodeOrder;
        return left.packageName.compareTo(right.packageName);
      });

    return [
      for (final aggregate in ordered)
        _observedAppForAggregate(
          aggregate: aggregate,
          catalog: catalog,
          identitiesByPackageName: identitiesByPackageName,
        ),
    ];
  }

  List<AppDailyAggregate> _fallbackAggregates(DailyUsageSummary day) {
    if (day.episodes.isEmpty) {
      return const [];
    }
    final byPackage = <String, ({Duration duration, int episodeCount})>{};
    for (final episode in day.episodes) {
      final current =
          byPackage[episode.packageName] ??
          (duration: Duration.zero, episodeCount: 0);
      byPackage[episode.packageName] = (
        duration: current.duration + episode.duration,
        episodeCount: current.episodeCount + 1,
      );
    }
    return [
      for (final entry in byPackage.entries)
        AppDailyAggregate(
          dayStart: day.dayStart,
          packageName: entry.key,
          appName: entry.key,
          duration: entry.value.duration,
          episodeCount: entry.value.episodeCount,
          stateCounts: const <AnalysisState, int>{},
          coverageStatus: day.coverageStatus,
          generatedAt: day.lastUpdatedAt,
          versions: day.episodeAnalyses.isEmpty
              ? const AnalysisArtifactVersions(
                  calibrationVersion: 'indisponível',
                  catalogVersion: 'indisponível',
                  owxIri: 'urn:foco-tela:owl:indisponivel',
                  owxVersion: 'indisponível',
                  owxCommit: 'indisponível',
                  owxHash: 'indisponível',
                )
              : day.episodeAnalyses.first.versions,
        ),
    ];
  }

  TodayObservedApp _observedAppForAggregate({
    required AppDailyAggregate aggregate,
    required CatalogSnapshot catalog,
    required Map<String, AppIdentity> identitiesByPackageName,
  }) {
    final catalogApp = catalog.appForPackageName(aggregate.packageName);
    final identity =
        identitiesByPackageName[aggregate.packageName] ??
        AppIdentity(packageName: aggregate.packageName);
    final displayName = _resolveDisplayName(
      identity: identity,
      catalogApp: catalogApp,
    );
    return TodayObservedApp(
      packageName: aggregate.packageName,
      displayName: displayName,
      identity: identity,
      catalogApp: catalogApp,
      duration: aggregate.duration,
      episodeCount: aggregate.episodeCount,
    );
  }

  List<TodayRingSlice> _categorySlices(List<TodayObservedApp> apps) {
    final approvedByGroup = <CatalogSampleGroup, List<TodayObservedApp>>{};
    final suggestedByGroup = <CatalogSampleGroup, List<TodayObservedApp>>{};
    final insufficientApps = <TodayObservedApp>[];

    for (final app in apps) {
      final catalogApp = app.catalogApp;
      if (catalogApp != null && catalogApp.hasApprovedContext) {
        approvedByGroup.putIfAbsent(catalogApp.sampleGroup, () => []).add(app);
      } else if (catalogApp != null && app.hasSuggestedType) {
        suggestedByGroup.putIfAbsent(catalogApp.sampleGroup, () => []).add(app);
      } else {
        insufficientApps.add(app);
      }
    }

    final approvedSlices =
        approvedByGroup.entries
            .map((entry) {
              final sliceApps = [...entry.value]
                ..sort((left, right) {
                  final durationOrder = right.duration.compareTo(left.duration);
                  if (durationOrder != 0) return durationOrder;
                  return left.displayName.compareTo(right.displayName);
                });
              return _sliceFromApps(
                id: 'category-${entry.key.value}',
                label: entry.key.label,
                subtitle: '${sliceApps.length} apps',
                status: CatalogContextStatus.approved,
                tone: _toneForSampleGroup(entry.key),
                apps: sliceApps,
              );
            })
            .toList(growable: false)
          ..sort((left, right) {
            final durationOrder = right.duration.compareTo(left.duration);
            if (durationOrder != 0) return durationOrder;
            return left.label.compareTo(right.label);
          });

    final slices = [...approvedSlices];
    final suggestedSlices =
        suggestedByGroup.entries
            .map((entry) {
              final sliceApps = [...entry.value]
                ..sort((left, right) {
                  final durationOrder = right.duration.compareTo(left.duration);
                  if (durationOrder != 0) return durationOrder;
                  return left.displayName.compareTo(right.displayName);
                });
              return _sliceFromApps(
                id: 'category-suggested-${entry.key.value}',
                label: entry.key.label,
                subtitle: '${sliceApps.length} apps',
                status: CatalogContextStatus.candidateAutomatic,
                tone: _toneForSampleGroup(entry.key),
                apps: sliceApps,
              );
            })
            .toList(growable: false)
          ..sort((left, right) {
            final durationOrder = right.duration.compareTo(left.duration);
            if (durationOrder != 0) return durationOrder;
            return left.label.compareTo(right.label);
          });
    slices.addAll(suggestedSlices);
    if (insufficientApps.isNotEmpty) {
      final sliceApps = [...insufficientApps]
        ..sort((left, right) {
          final durationOrder = right.duration.compareTo(left.duration);
          if (durationOrder != 0) return durationOrder;
          return left.displayName.compareTo(right.displayName);
        });
      slices.add(
        _sliceFromApps(
          id: 'category-insufficient',
          label: 'Tipo não avaliado',
          subtitle: '${sliceApps.length} apps sem tipo definido',
          status: CatalogContextStatus.insufficient,
          tone: TodayRingTone.neutral,
          apps: sliceApps,
        ),
      );
    }
    return slices;
  }

  List<TodayRingSlice> _appSlices(List<TodayObservedApp> apps) {
    return [
      for (final app in apps)
        _sliceFromApps(
          id: 'app-${app.packageName}',
          label: app.displayName,
          subtitle: app.statusLabel,
          status: app.contextStatus,
          tone: _toneForApp(app),
          apps: [app],
        ),
    ];
  }

  TodayRingSlice _sliceFromApps({
    required String id,
    required String label,
    required String subtitle,
    required CatalogContextStatus status,
    required TodayRingTone tone,
    required List<TodayObservedApp> apps,
  }) {
    return TodayRingSlice(
      id: id,
      label: label,
      subtitle: subtitle,
      status: status,
      tone: tone,
      duration: apps.fold(Duration.zero, (total, app) => total + app.duration),
      episodeCount: apps.fold(0, (total, app) => total + app.episodeCount),
      apps: apps,
    );
  }

  TodaySignalsSummary _buildSignals(
    DailyUsageSummary today, {
    required double? approvedContextShare,
    required double? evaluatedTypeShare,
  }) {
    if (today.analysis == null) {
      return TodaySignalsSummary(
        isAvailable: false,
        episodesWithSignals: 0,
        maxIntensityRange: null,
        maxRetentionBand: null,
        curatedContributionCount: 0,
        distinctActiveSignals: 0,
        coverageStatus: today.coverageStatus,
        approvedContextShare: approvedContextShare,
        evaluatedTypeShare: evaluatedTypeShare,
      );
    }

    final classified = today.episodeAnalyses
        .whereType<ClassifiedEpisodeAnalysis>();
    final activeAnalyses = classified
        .where((analysis) => analysis.signalObservations.any(_isActiveSignal))
        .toList(growable: false);
    final activeKinds = <BehavioralSignalKind>{};
    var curatedContributionCount = 0;
    for (final analysis in classified) {
      for (final signal in analysis.signalObservations) {
        if (signal.isActive == true) {
          activeKinds.add(signal.kind);
        }
      }
      if (analysis.scoreTotal.hasCuratedTechniqueOrIntention) {
        curatedContributionCount++;
      }
    }

    return TodaySignalsSummary(
      isAvailable: true,
      episodesWithSignals: activeAnalyses.length,
      maxIntensityRange: classified.isEmpty
          ? null
          : classified
                .map((analysis) => analysis.behavioralScore.range)
                .reduce(_maxRange),
      maxRetentionBand: classified.isEmpty
          ? null
          : classified
                .map((analysis) => analysis.scoreTotal.band)
                .reduce(
                  (left, right) => left.index >= right.index ? left : right,
                ),
      curatedContributionCount: curatedContributionCount,
      distinctActiveSignals: activeKinds.length,
      coverageStatus: today.coverageStatus,
      approvedContextShare: approvedContextShare,
      evaluatedTypeShare: evaluatedTypeShare,
    );
  }

  TodayRetentionIndications _buildRetentionIndications({
    required TodaySignalsSummary signals,
    required double? evaluatedTypeShare,
    required bool screenTimeAvailable,
  }) {
    if (!screenTimeAvailable || !signals.isAvailable) {
      return const TodayRetentionIndications(
        level: TodayRetentionIndicationLevel.unavailable,
        explanation: 'Indícios indisponíveis com os dados atuais.',
      );
    }

    var evidence = 0;
    evidence += switch (signals.maxRetentionBand) {
      ScoreTotalBand.high => 2,
      ScoreTotalBand.moderate => 1,
      ScoreTotalBand.low || null => 0,
    };
    if (signals.episodesWithSignals >= 3) evidence += 1;
    if (signals.distinctActiveSignals >= 2) evidence += 1;
    if ((evaluatedTypeShare ?? 0) >= 0.5) evidence += 1;
    if (signals.curatedContributionCount > 0) evidence += 1;

    if (evidence >= 4) {
      return TodayRetentionIndications(
        level: TodayRetentionIndicationLevel.high,
        explanation: signals.curatedContributionCount > 0
            ? 'Indícios altos combinam uso observado e evidência catalogada curada hoje.'
            : 'Sinais intensos e tipos avaliados apareceram juntos hoje.',
      );
    }
    if (evidence >= 2) {
      return const TodayRetentionIndications(
        level: TodayRetentionIndicationLevel.moderate,
        explanation: 'Há sinais observados, mas a leitura continua descritiva.',
      );
    }
    return const TodayRetentionIndications(
      level: TodayRetentionIndicationLevel.low,
      explanation: 'Poucos sinais foram observados no uso carregado hoje.',
    );
  }

  TodayRingTone _toneForSampleGroup(CatalogSampleGroup group) =>
      switch (group) {
        CatalogSampleGroup.retentionSocial => TodayRingTone.primary,
        CatalogSampleGroup.mixed => TodayRingTone.secondary,
        CatalogSampleGroup.utility => TodayRingTone.tertiary,
      };

  TodayRingTone _toneForApp(TodayObservedApp app) {
    final catalogApp = app.catalogApp;
    if (catalogApp == null) {
      return _toneForPackageName(app.packageName);
    }
    return switch (catalogApp.contextStatus) {
      CatalogContextStatus.approved => _toneForSampleGroup(
        catalogApp.sampleGroup,
      ),
      CatalogContextStatus.candidateAutomatic => _toneForPackageName(
        app.packageName,
      ),
      CatalogContextStatus.insufficient => _toneForPackageName(app.packageName),
    };
  }

  TodayRingTone _toneForPackageName(String packageName) {
    final tones = [
      TodayRingTone.primary,
      TodayRingTone.secondary,
      TodayRingTone.tertiary,
      TodayRingTone.neutral,
    ];
    return tones[packageName.hashCode.abs() % tones.length];
  }
}

class TodayOverviewData {
  const TodayOverviewData({
    required this.coverageStatus,
    required this.screenTimeAvailable,
    required this.screenTime,
    required this.unlockCount,
    required this.notificationCount,
    required this.approvedContextShare,
    required this.evaluatedTypeShare,
    required this.retentionIndications,
    required this.slices,
    required this.signals,
  });

  final CoverageStatus coverageStatus;
  final bool screenTimeAvailable;
  final Duration screenTime;
  final int? unlockCount;
  final int? notificationCount;
  final double? approvedContextShare;
  final double? evaluatedTypeShare;
  final TodayRetentionIndications retentionIndications;
  final List<TodayRingSlice> slices;
  final TodaySignalsSummary signals;

  TodayRingSlice? sliceById(String id) {
    for (final slice in slices) {
      if (slice.id == id) return slice;
    }
    return null;
  }
}

class TodayRingSlice {
  const TodayRingSlice({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.status,
    required this.tone,
    required this.duration,
    required this.episodeCount,
    required this.apps,
  });

  final String id;
  final String label;
  final String subtitle;
  final CatalogContextStatus status;
  final TodayRingTone tone;
  final Duration duration;
  final int episodeCount;
  final List<TodayObservedApp> apps;

  bool get isInsufficient => status == CatalogContextStatus.insufficient;

  bool get isSuggested => status == CatalogContextStatus.candidateAutomatic;

  bool get hasCandidateSuggestions =>
      apps.any((app) => app.candidateAssociations.isNotEmpty);

  List<CatalogAssociation> get candidateAssociations =>
      apps.expand((app) => app.candidateAssociations).toList(growable: false);

  List<CatalogAssociation> get approvedAssociations =>
      apps.expand((app) => app.approvedAssociations).toList(growable: false);
}

class TodayObservedApp {
  const TodayObservedApp({
    required this.packageName,
    required this.displayName,
    required this.identity,
    required this.catalogApp,
    required this.duration,
    required this.episodeCount,
  });

  final String packageName;
  final String displayName;
  final AppIdentity identity;
  final CatalogApp? catalogApp;
  final Duration duration;
  final int episodeCount;

  CatalogContextStatus get contextStatus =>
      catalogApp?.contextStatus ?? CatalogContextStatus.insufficient;

  CatalogSampleGroup? get sampleGroup => catalogApp?.sampleGroup;

  bool get hasApprovedContext => catalogApp?.hasApprovedContext == true;

  bool get hasSuggestedType =>
      catalogApp?.contextStatus == CatalogContextStatus.candidateAutomatic;

  bool get hasEvaluatedType => hasApprovedContext || hasSuggestedType;

  List<CatalogAssociation> get approvedAssociations =>
      catalogApp?.contextProfile.approvedAssociations ?? const [];

  List<CatalogAssociation> get candidateAssociations =>
      catalogApp?.contextProfile.candidateAssociations ?? const [];

  String get statusLabel => contextStatus.label;
}

class TodaySignalsSummary {
  const TodaySignalsSummary({
    required this.isAvailable,
    required this.episodesWithSignals,
    required this.maxIntensityRange,
    required this.maxRetentionBand,
    required this.curatedContributionCount,
    required this.distinctActiveSignals,
    required this.coverageStatus,
    required this.approvedContextShare,
    required this.evaluatedTypeShare,
  });

  final bool isAvailable;
  final int episodesWithSignals;
  final BehavioralScoreRange? maxIntensityRange;
  final ScoreTotalBand? maxRetentionBand;
  final int curatedContributionCount;
  final int distinctActiveSignals;
  final CoverageStatus coverageStatus;
  final double? approvedContextShare;
  final double? evaluatedTypeShare;
}

class TodayRetentionIndications {
  const TodayRetentionIndications({
    required this.level,
    required this.explanation,
  });

  final TodayRetentionIndicationLevel level;
  final String explanation;
}

enum TodayRetentionIndicationLevel { low, moderate, high, unavailable }

extension TodayRetentionIndicationLevelLabel on TodayRetentionIndicationLevel {
  String get label => switch (this) {
    TodayRetentionIndicationLevel.low => 'Baixos',
    TodayRetentionIndicationLevel.moderate => 'Moderados',
    TodayRetentionIndicationLevel.high => 'Altos',
    TodayRetentionIndicationLevel.unavailable => 'Indisponíveis',
  };
}

enum TodayRingTone { primary, secondary, tertiary, neutral }

class _HojeOverviewResources {
  const _HojeOverviewResources({
    required this.catalog,
    required this.identitiesByPackageName,
  });

  final CatalogSnapshot catalog;
  final Map<String, AppIdentity> identitiesByPackageName;
}

class _TodayHeroCard extends StatelessWidget {
  const _TodayHeroCard({
    required this.model,
    required this.today,
    required this.notificationLabel,
  });

  final TodayOverviewData model;
  final DailyUsageSummary today;
  final String notificationLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenTimeLabel = model.screenTimeAvailable
        ? _formatDuration(model.screenTime)
        : 'Indisponível';
    final metrics = [
      (label: 'Tempo de tela', value: screenTimeLabel),
      (label: 'Desbloqueios', value: _formatCount(model.unlockCount)),
      (label: 'Notificações', value: notificationLabel),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resumo do dia', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text('Dados parciais do uso observado no smartphone.'),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth >= 520
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final metric in metrics)
                      SizedBox(
                        width: itemWidth,
                        child: _TodaySummaryMetric(
                          label: metric.label,
                          value: metric.value,
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            _RetentionIndicationsPanel(indications: model.retentionIndications),
          ],
        ),
      ),
    );
  }
}

class _RetentionIndicationsPanel extends StatelessWidget {
  const _RetentionIndicationsPanel({required this.indications});

  final TodayRetentionIndications indications;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.insights_outlined,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Indícios de retenção hoje',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    indications.level.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${indications.explanation} Não é diagnóstico.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayRingCard extends StatelessWidget {
  const _TodayRingCard({
    required this.grouping,
    required this.model,
    required this.selectedSliceId,
    required this.onGroupingChanged,
    required this.onSliceSelected,
  });

  final TodayGrouping grouping;
  final TodayOverviewData model;
  final String? selectedSliceId;
  final ValueChanged<TodayGrouping> onGroupingChanged;
  final ValueChanged<String> onSliceSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Como o smartphone foi usado',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            const Text('Distribuição do tempo de tela por tipo ou app.'),
            const SizedBox(height: 16),
            SegmentedButton<TodayGrouping>(
              key: const ValueKey('today-grouping-selector'),
              segments: [
                for (final value in TodayGrouping.values)
                  ButtonSegment(value: value, label: Text(value.label)),
              ],
              selected: {grouping},
              onSelectionChanged: (selected) =>
                  onGroupingChanged(selected.single),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 720;
                final ring = SizedBox.square(
                  dimension: 220,
                  child: _TodayDonutChart(
                    slices: model.slices,
                    centerLabel: grouping == TodayGrouping.category
                        ? 'Tipos'
                        : 'Apps',
                    centerValue: _formatDuration(model.screenTime),
                  ),
                );
                final sliceList = Column(
                  children: [
                    for (final slice in model.slices)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _TodaySliceTile(
                              slice: slice,
                              totalDuration: model.screenTime,
                              selected: slice.id == selectedSliceId,
                              onTap: () => onSliceSelected(slice.id),
                            ),
                            if (slice.id == selectedSliceId) ...[
                              const SizedBox(height: 8),
                              _TodaySliceDetail(
                                slice: slice,
                                totalDuration: model.screenTime,
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ring,
                      const SizedBox(width: 20),
                      Expanded(child: sliceList),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(alignment: Alignment.center, child: ring),
                    const SizedBox(height: 16),
                    sliceList,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TodaySignalsCard extends StatelessWidget {
  const _TodaySignalsCard({required this.signals});

  final TodaySignalsSummary signals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final intensityLabel = _intensityLabel(signals.maxIntensityRange);

    return Card(
      key: const ValueKey('today-signals-summary'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sinais observados hoje', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text(
              'Detalhe científico dos indícios, sem score global ou diagnóstico.',
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              key: const ValueKey('understand-score-signals'),
              onPressed: () => _showScoreSignalsExplanation(context),
              icon: const Icon(Icons.help_outline),
              label: const Text('Entender score-sinais'),
            ),
            const SizedBox(height: 16),
            if (!signals.isAvailable)
              const Text('Sinais observados indisponíveis para este dia.')
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 720;
                  final tiles = [
                    _TodayMetricTile(
                      label: 'Episódios com sinais',
                      value: _formatCount(signals.episodesWithSignals),
                    ),
                    _TodayMetricTile(
                      label: 'Maior intensidade',
                      value: intensityLabel,
                    ),
                    _TodayMetricTile(
                      label: 'Sinais ativos distintos',
                      value: _formatCount(signals.distinctActiveSignals),
                    ),
                    _TodayMetricTile(
                      label: 'Qualidade da leitura',
                      value: _coverageQualityLabel(signals.coverageStatus),
                    ),
                    _TodayMetricTile(
                      label: 'Tempo em tipos avaliados',
                      value: signals.evaluatedTypeShare == null
                          ? 'Indisponível'
                          : _formatPercent(signals.evaluatedTypeShare),
                    ),
                  ];

                  if (isWide) {
                    return Wrap(spacing: 12, runSpacing: 12, children: tiles);
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final tile in tiles) ...[
                        tile,
                        const SizedBox(height: 12),
                      ],
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showScoreSignalsExplanation(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Como os sinais são calculados',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'score_sinais resume a intensidade dos sinais observados em '
                    'episódios, combinando duração longa, tempo de tela alto e '
                    'desbloqueios frequentes. Ele não é diagnóstico e não define '
                    'um estado do dia.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'O valor numérico fica na rastreabilidade científica, junto '
                    'de pesos, limiares, versões e IRIs. O card principal mostra '
                    'apenas faixas e contagens para evitar uma classificação '
                    'global do usuário.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Retenção intensificada só aparece quando há tipo aprovado '
                    'pelo TCC/OWL e cautelas visíveis; sinais isolados indicam apenas '
                    'padrões observados para revisão.',
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

class _TodaySliceDetail extends StatelessWidget {
  const _TodaySliceDetail({required this.slice, required this.totalDuration});

  final TodayRingSlice slice;
  final Duration totalDuration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final candidateLabels = slice.candidateAssociations
        .map((association) => association.label)
        .toSet()
        .toList(growable: false);
    final approvedLabels = slice.approvedAssociations
        .map((association) => association.label)
        .toSet()
        .toList(growable: false);

    return Card(
      key: const ValueKey('today-slice-detail'),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(slice.label, style: theme.textTheme.titleMedium),
                CatalogContextStatusChip(status: slice.status, compact: true),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_formatDuration(slice.duration)} · ${slice.episodeCount} episódio'
              '${slice.episodeCount == 1 ? '' : 's'} · ${slice.apps.length} app'
              '${slice.apps.length == 1 ? '' : 's'} · '
              '${_formatPercent(_durationShare(slice.duration, totalDuration))}',
            ),
            const SizedBox(height: 12),
            Text(_sliceStatusExplanation(slice)),
            const SizedBox(height: 12),
            Text('Aplicativos neste grupo', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final app in slice.apps.take(6))
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(app.displayName),
                  ),
              ],
            ),
            if (slice.apps.length > 6) ...[
              const SizedBox(height: 8),
              Text(
                '+${slice.apps.length - 6} apps',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (approvedLabels.isNotEmpty || candidateLabels.isNotEmpty) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text('Ver detalhes'),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final label in approvedLabels)
                          Chip(label: Text(label)),
                        for (final label in candidateLabels)
                          Chip(label: Text(label)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _sliceStatusExplanation(TodayRingSlice slice) {
    if (slice.isInsufficient) {
      return 'Apps observados sem tipo suficiente continuam na análise, mas sem mecanismo contextual definido.';
    }
    if (slice.isSuggested) {
      return 'Este tipo foi sugerido por regra local versionada e entra na análise com selo próprio.';
    }
    return 'Este tipo foi aprovado no catálogo do TCC e entra na análise com rastreabilidade.';
  }
}

class _TodaySliceTile extends StatelessWidget {
  const _TodaySliceTile({
    required this.slice,
    required this.totalDuration,
    required this.selected,
    required this.onTap,
  });

  final TodayRingSlice slice;
  final Duration totalDuration;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      key: ValueKey('today-slice-chip-${slice.id}'),
      elevation: selected ? 2 : 0,
      color: selected
          ? theme.colorScheme.surfaceContainerHighest
          : theme.colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SliceColorDot(tone: slice.tone),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          slice.label,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        CatalogContextStatusChip(
                          status: slice.status,
                          compact: true,
                        ),
                        if (selected)
                          Icon(
                            Icons.radio_button_checked,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(slice.subtitle, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatDuration(slice.duration)} · '
                      '${_formatPercent(_durationShare(slice.duration, totalDuration))} · '
                      '${slice.episodeCount} episódio'
                      '${slice.episodeCount == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall,
                    ),
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

class _SliceColorDot extends StatelessWidget {
  const _SliceColorDot({required this.tone});

  final TodayRingTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = switch (tone) {
      TodayRingTone.primary => (
        background: theme.colorScheme.primaryContainer,
        foreground: theme.colorScheme.onPrimaryContainer,
      ),
      TodayRingTone.secondary => (
        background: theme.colorScheme.secondaryContainer,
        foreground: theme.colorScheme.onSecondaryContainer,
      ),
      TodayRingTone.tertiary => (
        background: theme.colorScheme.tertiaryContainer,
        foreground: theme.colorScheme.onTertiaryContainer,
      ),
      TodayRingTone.neutral => (
        background: theme.colorScheme.surfaceContainerHighest,
        foreground: theme.colorScheme.onSurfaceVariant,
      ),
    };

    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.foreground, width: 1),
      ),
    );
  }
}

class _TodaySummaryMetric extends StatelessWidget {
  const _TodaySummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
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
                fontWeight: FontWeight.w700,
              ),
              softWrap: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayMetricTile extends StatelessWidget {
  const _TodayMetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 240),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayDonutChart extends StatelessWidget {
  const _TodayDonutChart({
    required this.slices,
    required this.centerLabel,
    required this.centerValue,
  });

  final List<TodayRingSlice> slices;
  final String centerLabel;
  final String centerValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.surface,
      ),
      child: CustomPaint(
        painter: _TodayDonutPainter(slices: slices, theme: theme),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(centerLabel, style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  centerValue,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayDonutPainter extends CustomPainter {
  const _TodayDonutPainter({required this.slices, required this.theme});

  final List<TodayRingSlice> slices;
  final ThemeData theme;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = math.min(size.width, size.height) / 2;
    final ringWidth = radius * 0.22;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..strokeCap = StrokeCap.butt;

    final backgroundPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = theme.colorScheme.surface;
    canvas.drawCircle(center, radius - ringWidth, backgroundPaint);

    final total = slices.fold<double>(
      0,
      (sum, slice) => sum + slice.duration.inMilliseconds,
    );
    if (total <= 0) {
      final emptyPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..color = theme.colorScheme.surfaceContainerHighest;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - ringWidth / 2),
        0,
        math.pi * 2,
        false,
        emptyPaint,
      );
      return;
    }

    var startAngle = -math.pi / 2;
    for (final slice in slices) {
      final sweep = (slice.duration.inMilliseconds / total) * math.pi * 2;
      paint.color = _colorForTone(theme, slice.tone);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - ringWidth / 2),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _TodayDonutPainter oldDelegate) =>
      oldDelegate.slices != slices || oldDelegate.theme != theme;

  Color _colorForTone(ThemeData theme, TodayRingTone tone) => switch (tone) {
    TodayRingTone.primary => theme.colorScheme.primary,
    TodayRingTone.secondary => theme.colorScheme.secondary,
    TodayRingTone.tertiary => theme.colorScheme.tertiary,
    TodayRingTone.neutral => theme.colorScheme.outline,
  };
}

class _TodayLoadingState extends StatelessWidget {
  const _TodayLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Carregando leitura observacional…'),
          ],
        ),
      ),
    );
  }
}

class _TodayErrorState extends StatelessWidget {
  const _TodayErrorState({
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: onPressed, child: Text(actionLabel)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayEmptyDashboardNotice extends StatelessWidget {
  const _TodayEmptyDashboardNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('dashboard-empty-state'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Nenhum episódio observado ainda. A leitura observacional fica '
          'disponível assim que houver dados locais suficientes.',
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}

String _resolveDisplayName({
  required AppIdentity identity,
  required CatalogApp? catalogApp,
}) {
  final friendlyName = identity.friendlyName?.trim();
  if (friendlyName != null && friendlyName.isNotEmpty) {
    return friendlyName;
  }
  if (catalogApp != null && catalogApp.displayName.trim().isNotEmpty) {
    return catalogApp.displayName;
  }
  return identity.packageName;
}

List<String> _observedPackages(WeeklyUsageDashboard dashboard) {
  final today = dashboard.days.first;
  final packages = <String>{};
  if (today.appAggregates.isNotEmpty) {
    for (final aggregate in today.appAggregates) {
      packages.add(aggregate.packageName);
    }
  } else {
    for (final episode in today.episodes) {
      packages.add(episode.packageName);
    }
  }
  return packages.toList(growable: false)..sort();
}

Duration _sumDuration(List<TodayObservedApp> apps) =>
    apps.fold(Duration.zero, (total, app) => total + app.duration);

bool _isActiveSignal(BehavioralSignalObservation signal) =>
    signal.isActive == true;

BehavioralScoreRange _maxRange(
  BehavioralScoreRange left,
  BehavioralScoreRange right,
) {
  final leftRank = _rangeRank(left);
  final rightRank = _rangeRank(right);
  return leftRank >= rightRank ? left : right;
}

int _rangeRank(BehavioralScoreRange range) => switch (range) {
  BehavioralScoreRange.low => 0,
  BehavioralScoreRange.medium => 1,
  BehavioralScoreRange.high => 2,
};

String _formatDuration(Duration duration) {
  if (duration.inHours >= 1) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (minutes == 0) return '$hours h';
    return '$hours h ${minutes.toString().padLeft(2, '0')} min';
  }
  if (duration.inMinutes >= 1) {
    return '${duration.inMinutes} min';
  }
  return '${duration.inSeconds} s';
}

String _formatCount(int? value) => switch (value) {
  final int count => '$count',
  null => 'Indisponível',
};

String _formatPercent(double? value) {
  if (value == null) return 'Indisponível';
  final percent = value * 100;
  final rounded = percent.toStringAsFixed(percent % 1 == 0 ? 0 : 1);
  return '$rounded%';
}

String _intensityLabel(BehavioralScoreRange? range) => switch (range) {
  BehavioralScoreRange.low => 'Baixa',
  BehavioralScoreRange.medium => 'Média',
  BehavioralScoreRange.high => 'Alta',
  null => 'Indisponível',
};

String _coverageQualityLabel(CoverageStatus status) => switch (status) {
  CoverageStatus.sufficient => 'Leitura suficiente',
  CoverageStatus.partial => 'Leitura parcial',
  CoverageStatus.unavailable => 'Leitura indisponível',
};

double _durationShare(Duration duration, Duration totalDuration) {
  if (totalDuration.inMilliseconds <= 0) return 0;
  return duration.inMilliseconds / totalDuration.inMilliseconds;
}
