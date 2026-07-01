import 'package:flutter/foundation.dart';

import '../../catalog/data/app_catalog_repository.dart';
import '../../notifications/domain/notification_observation.dart';
import '../domain/analysis_window.dart';
import '../domain/daily_usage_summary.dart';
import '../domain/derived_analysis_coordinator.dart';
import '../domain/derived_analysis_repository.dart';
import '../domain/usage_repository.dart';
import '../../usage_access/domain/usage_access.dart';
import '../../usage_access/presentation/usage_access_ui_state.dart';

class DashboardViewModel extends ChangeNotifier {
  final UsageRepository usageRepository;
  final UsageAccessRepository usageAccessRepository;
  final AppCatalogRepository catalogRepository;
  final DerivedAnalysisRepository derivedRepository;
  final NotificationRepository? notificationRepository;
  final ScreenTimeCapability? screenTimeCapability;
  late final DateTime Function() _now;
  late final DerivedAnalysisCoordinator _analysisCoordinator;

  WeeklyUsageDashboard? _dashboard;
  WeeklyUsageDashboard? get dashboard => _dashboard;

  AnalysisWindow _selectedWindow = AnalysisWindow.sevenDays;
  AnalysisWindow get selectedWindow => _selectedWindow;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _historyWasCleared = false;
  bool get historyWasCleared => _historyWasCleared;

  UsageAccessUiState _usageAccessState = const UsageAccessChecking();
  UsageAccessUiState get usageAccessState => _usageAccessState;
  bool _iosScreenTimeAvailable = false;
  bool get iosScreenTimeAvailable => _iosScreenTimeAvailable;

  DashboardViewModel({
    required this.usageRepository,
    required this.usageAccessRepository,
    required this.catalogRepository,
    required this.derivedRepository,
    this.notificationRepository,
    this.screenTimeCapability,
    DateTime Function()? now,
  }) {
    _now = now ?? DateTime.now;
    _analysisCoordinator = DerivedAnalysisCoordinator(
      usageRepository: usageRepository,
      catalogRepository: catalogRepository,
      derivedRepository: derivedRepository,
      notificationRepository: notificationRepository,
      now: _now,
    );
    loadDashboard();
    _checkScreenTimeCapability();
  }

  Future<void> _checkScreenTimeCapability() async {
    if (screenTimeCapability == null) return;
    try {
      final available = await screenTimeCapability!.isScreenTimeAvailable();
      _iosScreenTimeAvailable = available;
      notifyListeners();
    } catch (_) {
      _iosScreenTimeAvailable = false;
      notifyListeners();
    }
  }

  Future<void> loadDashboard() async {
    _isLoading = true;
    _errorMessage = null;
    _dashboard = null;
    _historyWasCleared = false;
    _usageAccessState = const UsageAccessChecking();
    notifyListeners();

    try {
      final snapshot = await usageAccessRepository.checkAccess();
      switch (snapshot.status) {
        case UsageAccessStatus.denied:
          _usageAccessState = const UsageAccessDenied();
          _isLoading = false;
          notifyListeners();
          return;
        case UsageAccessStatus.granted:
          _usageAccessState = const UsageAccessGranted();
      }

      _dashboard = await _analysisCoordinator.load(window: _selectedWindow);
      _isLoading = false;
      notifyListeners();
    } on UsageAccessContractException catch (error) {
      _usageAccessState = UsageAccessCheckError(error.message);
      _isLoading = false;
      notifyListeners();
    } catch (error) {
      _isLoading = false;
      if (_usageAccessState is UsageAccessGranted) {
        _errorMessage = 'Erro ao carregar dados: $error';
      } else {
        _usageAccessState = UsageAccessCheckError(
          'Não foi possível verificar o acesso aos dados de uso.',
        );
      }
      notifyListeners();
    }
  }

  Future<void> requestPermission() async {
    _usageAccessState = const UsageSettingsOpening();
    notifyListeners();

    try {
      await usageAccessRepository.openSettings();
      _usageAccessState = const UsageSettingsOpened();
      notifyListeners();
    } on UsageSettingsOpenException catch (error) {
      _usageAccessState = UsageSettingsOpenError(error.message);
      notifyListeners();
    } catch (_) {
      _usageAccessState = const UsageSettingsOpenError(
        'Não foi possível abrir as configurações de acesso ao uso.',
      );
      notifyListeners();
    }
  }

  Future<void> openIosScreenTimeReport() async {
    if (screenTimeCapability == null) return;
    try {
      await screenTimeCapability!.openNativeScreenTimeReport();
    } catch (e) {
      _errorMessage = 'Não foi possível abrir o relatório do iOS: $e';
      notifyListeners();
    }
  }

  Future<void> refresh() => loadDashboard();

  Future<void> selectWindow(AnalysisWindow window) async {
    if (_selectedWindow == window) return;
    _selectedWindow = window;
    await loadDashboard();
  }

  void forgetDerivedHistoryFromUi() {
    _dashboard = null;
    _errorMessage = null;
    _historyWasCleared = true;
    notifyListeners();
  }
}
