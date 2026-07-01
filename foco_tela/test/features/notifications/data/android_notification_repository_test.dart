import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foco_tela/features/notifications/data/android_notification_repository.dart';
import 'package:foco_tela/features/notifications/domain/notification_observation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.foco_tela/notifications_test');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('consulta listener ativo pelo contrato versionado do canal', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getNotificationAccessState');
          return <String, Object>{
            'contractVersion': notificationContractVersion,
            'status': 'granted',
          };
        });

    final status = await AndroidNotificationRepository(
      channel: channel,
    ).checkAccess();

    expect(status, NotificationAccessStatus.granted);
  });

  test('parseia última leitura observada pelo Notification Listener', () async {
    final observedAt = DateTime(2026, 6, 21, 14, 27);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getLastNotificationObservation');
          return <String, Object?>{
            'contractVersion': notificationContractVersion,
            'observation': <String, Object>{
              'observedAtMillis': observedAt.millisecondsSinceEpoch,
              'packageName': 'com.example.social',
              'count': 4,
            },
          };
        });

    final observation = await AndroidNotificationRepository(
      channel: channel,
    ).loadLastObservation();

    expect(observation, isNotNull);
    expect(observation!.observedAt, observedAt);
    expect(observation.packageName, 'com.example.social');
    expect(observation.count, 4);
  });

  test('aceita ausência de última leitura sem fabricar zero', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          return <String, Object?>{
            'contractVersion': notificationContractVersion,
            'observation': null,
          };
        });

    final observation = await AndroidNotificationRepository(
      channel: channel,
    ).loadLastObservation();

    expect(observation, isNull);
  });

  test('autoriza conteúdo textual de múltiplos pacotes pelo canal', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'authorizeContentPackages');
          expect(call.arguments, {
            'packageNames': ['com.example.run', 'com.example.social'],
          });
          return <String, Object>{
            'contractVersion': notificationContractVersion,
            'ok': true,
          };
        });

    await AndroidNotificationRepository(
      channel: channel,
    ).authorizeContentPackages({'com.example.social', 'com.example.run'});
  });
}
