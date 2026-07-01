import 'daily_usage_analysis.dart';

abstract class UsageRepository {
  Future<DailyUsageAnalysis> getAnalysisForDay(DateTime day);
}

abstract class ScreenTimeCapability {
  /// Indica se o dispositivo suporta Screen Time (iOS 16+ com entitlements).
  Future<bool> isScreenTimeAvailable();

  /// Abre uma tela nativa do iOS com relatório de Screen Time.
  Future<void> openNativeScreenTimeReport();
}
