import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foco_tela/features/usage_access/data/android_usage_access_repository.dart';
import 'package:foco_tela/features/usage_access/domain/usage_access.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.foco_tela/usage_access_test');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('informa permissão negada pelo contrato versionado do canal', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getUsageAccessState');
          return <String, Object>{
            'contractVersion': usageAccessContractVersion,
            'status': 'denied',
          };
        });

    final repository = AndroidUsageAccessRepository(channel: channel);

    final snapshot = await repository.checkAccess();

    expect(snapshot.contractVersion, usageAccessContractVersion);
    expect(snapshot.status, UsageAccessStatus.denied);
  });

  test(
    'informa permissão concedida pelo contrato versionado do canal',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            return <String, Object>{
              'contractVersion': usageAccessContractVersion,
              'status': 'granted',
            };
          });

      final snapshot = await AndroidUsageAccessRepository(
        channel: channel,
      ).checkAccess();

      expect(snapshot.status, UsageAccessStatus.granted);
    },
  );

  test('confirma que a configuração nativa foi aberta', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'openUsageAccessSettings');
          return <String, Object>{
            'contractVersion': usageAccessContractVersion,
            'opened': true,
          };
        });

    await AndroidUsageAccessRepository(channel: channel).openSettings();
  });

  test('rejeita versão desconhecida do contrato', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          return <String, Object>{
            'contractVersion': usageAccessContractVersion + 1,
            'status': 'granted',
          };
        });

    expect(
      AndroidUsageAccessRepository(channel: channel).checkAccess(),
      throwsA(isA<UsageAccessContractException>()),
    );
  });

  test('traduz falha nativa ao abrir configurações', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(
            code: 'SETTINGS_UNAVAILABLE',
            message: 'Settings unavailable',
          );
        });

    expect(
      AndroidUsageAccessRepository(channel: channel).openSettings(),
      throwsA(isA<UsageSettingsOpenException>()),
    );
  });
}
