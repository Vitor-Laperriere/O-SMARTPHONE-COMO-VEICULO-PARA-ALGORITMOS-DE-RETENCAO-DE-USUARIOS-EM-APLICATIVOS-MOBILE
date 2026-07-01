import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foco_tela/features/assistive_action/data/android_assistive_settings_repository.dart';
import 'package:foco_tela/features/assistive_action/domain/assistive_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.foco_tela/assistive_settings_test');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('abre configurações de uso para o packageName confirmado', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'openAppUsageSettings');
          expect(call.arguments, <String, Object>{
            'packageName': 'com.example.social',
          });
          return <String, Object>{
            'contractVersion': assistiveSettingsContractVersion,
            'opened': true,
            'destination': 'appUsageSettings',
          };
        });

    final result = await AndroidAssistiveSettingsRepository(
      channel: channel,
    ).openForPackage('com.example.social');

    expect(result.destination, AssistiveSettingsDestination.appUsageSettings);
  });

  test('informa quando o adaptador usou detalhes do aplicativo', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          return <String, Object>{
            'contractVersion': assistiveSettingsContractVersion,
            'opened': true,
            'destination': 'applicationDetails',
          };
        });

    final result = await AndroidAssistiveSettingsRepository(
      channel: channel,
    ).openForPackage('com.example.social');

    expect(result.destination, AssistiveSettingsDestination.applicationDetails);
  });

  test('rejeita packageName vazio antes de chamar a plataforma', () async {
    var called = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          called = true;
          return null;
        });

    expect(
      AndroidAssistiveSettingsRepository(channel: channel).openForPackage('  '),
      throwsA(isA<AssistiveSettingsException>()),
    );
    expect(called, isFalse);
  });

  test('traduz falha nativa sem expor PlatformException', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(
            code: 'SETTINGS_UNAVAILABLE',
            message: 'Settings unavailable',
          );
        });

    expect(
      AndroidAssistiveSettingsRepository(
        channel: channel,
      ).openForPackage('com.example.social'),
      throwsA(isA<AssistiveSettingsException>()),
    );
  });
}
