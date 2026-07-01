import 'package:flutter/foundation.dart';

import '../../catalog/data/app_catalog_repository.dart';
import '../../dashboard/domain/behavioral_signal_calibration.dart';
import '../../dashboard/domain/derived_analysis_repository.dart';
import '../../notifications/domain/notification_observation.dart';
import '../../usage_access/domain/usage_access.dart';
import '../domain/privacy_settings_snapshot.dart';

sealed class SettingsPrivacyUiState {
  const SettingsPrivacyUiState();
}

final class SettingsPrivacyLoading extends SettingsPrivacyUiState {
  const SettingsPrivacyLoading();
}

final class SettingsPrivacyReady extends SettingsPrivacyUiState {
  const SettingsPrivacyReady(this.snapshot);

  final PrivacySettingsSnapshot snapshot;
}

final class SettingsPrivacyLoadError extends SettingsPrivacyUiState {
  const SettingsPrivacyLoadError(this.message);

  final String message;
}

sealed class HistoryDeletionUiState {
  const HistoryDeletionUiState();
}

final class HistoryDeletionIdle extends HistoryDeletionUiState {
  const HistoryDeletionIdle();
}

final class HistoryDeletionInProgress extends HistoryDeletionUiState {
  const HistoryDeletionInProgress();
}

final class HistoryDeletionSucceeded extends HistoryDeletionUiState {
  const HistoryDeletionSucceeded();
}

final class HistoryDeletionFailed extends HistoryDeletionUiState {
  const HistoryDeletionFailed(this.message);

  final String message;
}

class SettingsPrivacyViewModel extends ChangeNotifier {
  SettingsPrivacyViewModel({
    required UsageAccessRepository usageAccessRepository,
    required AppCatalogRepository catalogRepository,
    required DerivedAnalysisRepository derivedRepository,
    required NotificationRepository notificationRepository,
    required VoidCallback onHistoryCleared,
    BehavioralSignalCalibration? calibration,
    DateTime Function()? now,
  }) : _usageAccessRepository = usageAccessRepository,
       _catalogRepository = catalogRepository,
       _derivedRepository = derivedRepository,
       _notificationRepository = notificationRepository,
       _onHistoryCleared = onHistoryCleared,
       _calibration = calibration ?? BehavioralSignalCalibration.v1(),
       _now = now ?? DateTime.now {
    load();
  }

  final UsageAccessRepository _usageAccessRepository;
  final AppCatalogRepository _catalogRepository;
  final DerivedAnalysisRepository _derivedRepository;
  final NotificationRepository _notificationRepository;
  final VoidCallback _onHistoryCleared;
  final BehavioralSignalCalibration _calibration;
  final DateTime Function() _now;

  SettingsPrivacyUiState _state = const SettingsPrivacyLoading();
  SettingsPrivacyUiState get state => _state;

  bool _notificationActionInProgress = false;
  bool get notificationActionInProgress => _notificationActionInProgress;

  String? _notificationActionMessage;
  String? get notificationActionMessage => _notificationActionMessage;

  bool _notificationActionFailed = false;
  bool get notificationActionFailed => _notificationActionFailed;

  bool _contentActionInProgress = false;
  bool get contentActionInProgress => _contentActionInProgress;

  String? _contentActionMessage;
  String? get contentActionMessage => _contentActionMessage;

  bool _contentActionFailed = false;
  bool get contentActionFailed => _contentActionFailed;

  HistoryDeletionUiState _deletionState = const HistoryDeletionIdle();
  HistoryDeletionUiState get deletionState => _deletionState;

  Future<void> load() async {
    _state = const SettingsPrivacyLoading();
    notifyListeners();
    try {
      final checkedAt = _now();
      final (
        access,
        catalog,
        notificationDiagnostic,
        contentSettings,
        observedPackageNames,
      ) = await (
        _usageAccessRepository.checkAccess(),
        _catalogRepository.loadSnapshot(),
        _loadNotificationDiagnostic(checkedAt),
        _notificationRepository.loadContentSettings(),
        _loadObservedPackageNames(checkedAt),
      ).wait;
      final header = catalog.header;
      _state = SettingsPrivacyReady(
        PrivacySettingsSnapshot(
          usageAccessStatus: access.status,
          notificationDiagnostic: notificationDiagnostic,
          notificationContentSettings: contentSettings,
          observedPackageNames: observedPackageNames,
          calibration: _calibration,
          catalogVersion: header.version,
          heuristicVersion: _calibration.version,
          owxIri: header.owxIri,
          owxVersion: header.owxVersion,
          owxCommit: header.owxCommit,
          owxHash: header.owxHash,
        ),
      );
    } catch (_) {
      _state = const SettingsPrivacyLoadError(
        'Não foi possível consultar a permissão e as versões locais.',
      );
    }
    notifyListeners();
  }

  Future<void> openNotificationSettings() async {
    if (_notificationActionInProgress) return;
    _notificationActionInProgress = true;
    _notificationActionMessage =
        'Abrindo as configurações de acesso a notificações do Android…';
    _notificationActionFailed = false;
    notifyListeners();
    try {
      await _notificationRepository.openSettings();
      _notificationActionMessage =
          'Configurações abertas. Ao retornar ao Foco Tela, verifique novamente o listener.';
      _notificationActionFailed = false;
    } catch (_) {
      _notificationActionMessage =
          'Não foi possível abrir as configurações de notificações neste dispositivo.';
      _notificationActionFailed = true;
    } finally {
      _notificationActionInProgress = false;
      notifyListeners();
    }
  }

  Future<void> recheckNotificationListener() async {
    if (_notificationActionInProgress) return;
    final ready = _state;
    if (ready is! SettingsPrivacyReady) return;
    _notificationActionInProgress = true;
    _notificationActionMessage = 'Reverificando o Notification Listener…';
    _notificationActionFailed = false;
    notifyListeners();
    final diagnostic = await _loadNotificationDiagnostic(_now());
    _state = SettingsPrivacyReady(
      ready.snapshot.copyWith(notificationDiagnostic: diagnostic),
    );
    _notificationActionInProgress = false;
    _notificationActionMessage =
        'Estado do Notification Listener reverificado.';
    _notificationActionFailed =
        diagnostic.status == NotificationListenerDiagnosticStatus.readFailure;
    notifyListeners();
  }

  Future<void> authorizeObservedNotificationContent() async {
    if (_contentActionInProgress) return;
    final ready = _state;
    if (ready is! SettingsPrivacyReady) return;
    final packageNames = ready.snapshot.observedPackageNames;
    if (packageNames.isEmpty) {
      _contentActionMessage =
          'Nenhum app observado disponível para autorização em lote.';
      _contentActionFailed = false;
      notifyListeners();
      return;
    }
    _contentActionInProgress = true;
    _contentActionMessage =
        'Autorizando conteúdo textual para apps observados…';
    _contentActionFailed = false;
    notifyListeners();
    try {
      await _notificationRepository.setContentModeEnabled(true);
      await _notificationRepository.authorizeContentPackages(packageNames);
      final settings = await _notificationRepository.loadContentSettings();
      _state = SettingsPrivacyReady(
        ready.snapshot.copyWith(notificationContentSettings: settings),
      );
      final count = packageNames.length;
      _contentActionMessage =
          'Conteúdo textual autorizado para $count ${count == 1 ? 'app observado' : 'apps observados'}.';
      _contentActionFailed = false;
    } catch (_) {
      _contentActionMessage =
          'Não foi possível autorizar conteúdo textual dos apps observados.';
      _contentActionFailed = true;
    } finally {
      _contentActionInProgress = false;
      notifyListeners();
    }
  }

  Future<void> clearDerivedHistory() async {
    if (_deletionState is HistoryDeletionInProgress) return;
    _deletionState = const HistoryDeletionInProgress();
    notifyListeners();
    try {
      await _derivedRepository.clearAllDerived();
      _onHistoryCleared();
      _deletionState = const HistoryDeletionSucceeded();
    } catch (_) {
      _deletionState = const HistoryDeletionFailed(
        'Não foi possível apagar o histórico derivado local.',
      );
    }
    notifyListeners();
  }

  Future<NotificationListenerDiagnostic> _loadNotificationDiagnostic(
    DateTime checkedAt,
  ) async {
    try {
      final access = await _notificationRepository.checkAccess();
      final status = switch (access) {
        NotificationAccessStatus.granted =>
          NotificationListenerDiagnosticStatus.active,
        NotificationAccessStatus.denied =>
          NotificationListenerDiagnosticStatus.inactive,
        NotificationAccessStatus.unsupported =>
          NotificationListenerDiagnosticStatus.apiUnavailable,
      };
      if (status != NotificationListenerDiagnosticStatus.active) {
        return NotificationListenerDiagnostic(
          status: status,
          checkedAt: checkedAt,
        );
      }
      return NotificationListenerDiagnostic(
        status: status,
        checkedAt: checkedAt,
        lastObservation: await _notificationRepository.loadLastObservation(),
      );
    } catch (_) {
      return NotificationListenerDiagnostic(
        status: NotificationListenerDiagnosticStatus.readFailure,
        checkedAt: checkedAt,
      );
    }
  }

  Future<Set<String>> _loadObservedPackageNames(DateTime now) async {
    try {
      final end = DateTime(now.year, now.month, now.day + 1);
      final start = DateTime(now.year, now.month - 6, now.day);
      final aggregates = await _derivedRepository.loadAppDailyAggregates(
        start: start,
        end: end,
      );
      return aggregates
          .map((aggregate) => aggregate.packageName.trim())
          .where((packageName) => packageName.isNotEmpty)
          .toSet();
    } catch (_) {
      return const {};
    }
  }
}
