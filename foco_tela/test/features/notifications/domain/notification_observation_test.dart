import 'package:flutter_test/flutter_test.dart';

import 'package:foco_tela/features/notifications/data/in_memory_notification_repository.dart';
import 'package:foco_tela/features/notifications/domain/notification_observation.dart';

void main() {
  test('sem acesso a notificações não fabrica zero observado', () async {
    final repository = InMemoryNotificationRepository(
      accessStatus: NotificationAccessStatus.denied,
      counts: [
        DailyNotificationCount(
          dayStart: DateTime(2026, 6, 22),
          packageName: 'com.example.social',
          count: 12,
        ),
      ],
    );

    expect(await repository.checkAccess(), NotificationAccessStatus.denied);
    expect(
      await repository.loadDailyCounts(
        start: DateTime(2026, 6, 22),
        end: DateTime(2026, 6, 23),
      ),
      isEmpty,
    );
  });

  test('zero só é representável quando a contagem está disponível', () async {
    final repository = InMemoryNotificationRepository(
      accessStatus: NotificationAccessStatus.granted,
      counts: [
        DailyNotificationCount(
          dayStart: DateTime(2026, 6, 22),
          packageName: 'com.example.social',
          count: 0,
        ),
      ],
    );

    final counts = await repository.loadDailyCounts(
      start: DateTime(2026, 6, 22),
      end: DateTime(2026, 6, 23),
    );

    expect(counts.single.count, 0);
  });

  test('conteúdo textual começa desligado e sem aplicativo autorizado', () {
    final settings = NotificationContentSettings.defaults();

    expect(settings.enabled, isFalse);
    expect(settings.authorizedPackageNames, isEmpty);
    expect(settings.retention, const Duration(days: 7));
    expect(settings.protectedAtRest, isTrue);
    expect(settings.requiresDeviceAuthenticationForViewing, isTrue);
    expect(settings.excludedFromBackup, isTrue);
    expect(settings.canPersistContentFor('com.example.social'), isFalse);
  });

  test(
    'desativar conteúdo remove registros armazenados e autorizações',
    () async {
      final expiresAt = DateTime.now().add(const Duration(days: 1));
      final repository = InMemoryNotificationRepository(
        accessStatus: NotificationAccessStatus.granted,
        initialSettings: NotificationContentSettings(
          enabled: true,
          authorizedPackageNames: {'com.example.social'},
        ),
        content: [
          NotificationTextRecord(
            packageName: 'com.example.social',
            postedAt: DateTime(2026, 6, 22, 10),
            title: 'Título',
            text: 'Texto',
            expiresAt: expiresAt,
          ),
        ],
      );

      await repository.setContentModeEnabled(false);

      expect((await repository.loadContentSettings()).enabled, isFalse);
      expect(
        (await repository.loadContentSettings()).authorizedPackageNames,
        isEmpty,
      );
      expect(
        await repository.loadStoredContent(
          start: DateTime(2026, 6, 22),
          end: DateTime(2026, 6, 23),
        ),
        isEmpty,
      );
    },
  );

  test(
    'conteúdo só é consultável após autenticação e autorização do app',
    () async {
      final expiresAt = DateTime.now().add(const Duration(days: 1));
      final repository = InMemoryNotificationRepository(
        accessStatus: NotificationAccessStatus.granted,
        initialSettings: NotificationContentSettings(
          enabled: true,
          authorizedPackageNames: {'com.example.social'},
        ),
        content: [
          NotificationTextRecord(
            packageName: 'com.example.social',
            postedAt: DateTime(2026, 6, 22, 10),
            title: 'Permitida',
            text: 'Texto permitido',
            expiresAt: expiresAt,
          ),
          NotificationTextRecord(
            packageName: 'com.example.other',
            postedAt: DateTime(2026, 6, 22, 11),
            title: 'Descartada',
            text: 'Texto não autorizado',
            expiresAt: expiresAt,
          ),
        ],
      );

      expect(await repository.authenticateContentViewing(), isTrue);
      final records = await repository.loadStoredContent(
        start: DateTime(2026, 6, 22),
        end: DateTime(2026, 6, 23),
      );

      expect(records, hasLength(1));
      expect(records.single.packageName, 'com.example.social');
    },
  );
}
