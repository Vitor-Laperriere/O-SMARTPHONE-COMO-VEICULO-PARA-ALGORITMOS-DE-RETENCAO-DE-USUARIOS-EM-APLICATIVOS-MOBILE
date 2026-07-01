import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:foco_tela/features/assistive_action/data/android_assistive_settings_repository.dart';
import 'package:foco_tela/features/assistive_action/domain/assistive_settings.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'canal Android abre uma configuração nativa sem alterar o aplicativo',
    (_) async {
      expect(Platform.isAndroid, isTrue);

      final result = await AndroidAssistiveSettingsRepository().openForPackage(
        'com.example.foco_tela',
      );

      expect(
        result.destination,
        anyOf(
          AssistiveSettingsDestination.appUsageSettings,
          AssistiveSettingsDestination.applicationDetails,
        ),
      );
    },
  );
}
