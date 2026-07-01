import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foco_tela/features/dashboard/presentation/dashboard_page.dart';
import 'package:foco_tela/features/notifications/domain/notification_observation.dart';

void main() {
  testWidgets('consulta conteúdo somente após autenticação', (tester) async {
    final repository = _RecordingNotificationRepository();
    await tester.binding.setSurfaceSize(const Size(900, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationContentPage(
          repository: repository,
          start: DateTime(2026, 6, 22),
          end: DateTime(2026, 6, 23),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final authenticateButton = find.byKey(
      const ValueKey('notification-content-authenticate'),
    );
    await tester.ensureVisible(authenticateButton);
    await tester.tap(authenticateButton);
    await tester.pumpAndSettle();

    expect(repository.authenticatedBeforeLoad, isTrue);
    expect(find.text('Título autorizado'), findsOneWidget);
    expect(find.textContaining('Texto autorizado'), findsOneWidget);
  });
}

class _RecordingNotificationRepository implements NotificationRepository {
  bool _authenticated = false;
  bool authenticatedBeforeLoad = false;

  @override
  Future<bool> authenticateContentViewing() async {
    _authenticated = true;
    return true;
  }

  @override
  Future<NotificationAccessStatus> checkAccess() async =>
      NotificationAccessStatus.granted;

  @override
  Future<void> openSettings() async {}

  @override
  Future<List<DailyNotificationCount>> loadDailyCounts({
    required DateTime start,
    required DateTime end,
  }) async => const [];

  @override
  Future<NotificationLastObservation?> loadLastObservation() async => null;

  @override
  Future<NotificationContentSettings> loadContentSettings() async =>
      NotificationContentSettings(
        enabled: true,
        authorizedPackageNames: {'com.example.social'},
      );

  @override
  Future<void> setContentModeEnabled(bool enabled) async {}

  @override
  Future<void> authorizeContentPackage(String packageName) async {}

  @override
  Future<void> authorizeContentPackages(Set<String> packageNames) async {}

  @override
  Future<void> revokeContentPackage(String packageName) async {}

  @override
  Future<List<NotificationTextRecord>> loadStoredContent({
    required DateTime start,
    required DateTime end,
    String? packageName,
  }) async {
    authenticatedBeforeLoad = _authenticated;
    return [
      NotificationTextRecord(
        packageName: 'com.example.social',
        postedAt: DateTime(2026, 6, 22, 10),
        title: 'Título autorizado',
        text: 'Texto autorizado',
        expiresAt: DateTime(2026, 6, 29),
      ),
    ];
  }

  @override
  Future<void> clearStoredContent() async {}
}
