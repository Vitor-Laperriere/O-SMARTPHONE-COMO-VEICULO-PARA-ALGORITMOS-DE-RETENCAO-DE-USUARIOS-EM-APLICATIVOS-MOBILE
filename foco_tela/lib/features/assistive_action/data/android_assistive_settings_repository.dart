import 'package:flutter/services.dart';

import '../domain/assistive_settings.dart';
import 'assistive_settings_platform_service.dart';

class AndroidAssistiveSettingsRepository
    implements AssistiveSettingsRepository {
  AndroidAssistiveSettingsRepository({
    MethodChannel channel = const MethodChannel(
      'com.foco_tela/assistive_settings',
    ),
  }) : _service = AssistiveSettingsPlatformService(channel: channel);

  final AssistiveSettingsPlatformService _service;

  @override
  Future<AssistiveSettingsOpenResult> openForPackage(String packageName) async {
    final normalizedPackageName = packageName.trim();
    if (normalizedPackageName.isEmpty) {
      throw const AssistiveSettingsException(
        'O identificador do aplicativo está vazio.',
      );
    }

    try {
      final response = await _service.openAppUsageSettings(
        normalizedPackageName,
      );
      return switch (response) {
        {
          'contractVersion': assistiveSettingsContractVersion,
          'opened': true,
          'destination': final String destination,
        } =>
          AssistiveSettingsOpenResult(
            destination: switch (destination) {
              'appUsageSettings' =>
                AssistiveSettingsDestination.appUsageSettings,
              'applicationDetails' =>
                AssistiveSettingsDestination.applicationDetails,
              _ => throw AssistiveSettingsException(
                'Destino de configuração desconhecido: $destination.',
              ),
            },
          ),
        {'contractVersion': final int version} =>
          throw AssistiveSettingsException(
            'Versão do contrato não suportada: $version.',
          ),
        _ => throw const AssistiveSettingsException(
          'Resposta inválida ao abrir as configurações.',
        ),
      };
    } on PlatformException catch (error) {
      throw AssistiveSettingsException(
        error.message ??
            'Não foi possível abrir as configurações deste aplicativo.',
      );
    }
  }
}

class UnsupportedAssistiveSettingsRepository
    implements AssistiveSettingsRepository {
  const UnsupportedAssistiveSettingsRepository();

  @override
  Future<AssistiveSettingsOpenResult> openForPackage(String packageName) {
    throw const AssistiveSettingsException(
      'A revisão de configurações está disponível apenas no Android.',
    );
  }
}
