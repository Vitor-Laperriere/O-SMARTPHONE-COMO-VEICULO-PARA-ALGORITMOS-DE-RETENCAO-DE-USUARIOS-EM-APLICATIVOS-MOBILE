import 'package:flutter/services.dart';

import '../domain/usage_access.dart';
import 'usage_access_platform_service.dart';

class AndroidUsageAccessRepository implements UsageAccessRepository {
  AndroidUsageAccessRepository({
    MethodChannel channel = const MethodChannel('com.foco_tela/usage_access'),
  }) : _service = UsageAccessPlatformService(channel: channel);

  final UsageAccessPlatformService _service;

  @override
  Future<UsageAccessSnapshot> checkAccess() async {
    final response = await _service.getUsageAccessState();
    return _parseSnapshot(response);
  }

  @override
  Future<void> openSettings() async {
    try {
      final response = await _service.openUsageAccessSettings();
      switch (response) {
        case {'contractVersion': usageAccessContractVersion, 'opened': true}:
          return;
        case {'contractVersion': int version}:
          throw UsageAccessContractException(
            'Versão do contrato não suportada: $version.',
          );
        default:
          throw const UsageAccessContractException(
            'Resposta inválida ao abrir as configurações.',
          );
      }
    } on PlatformException catch (error) {
      throw UsageSettingsOpenException(
        error.message ?? 'A configuração nativa não está disponível.',
      );
    }
  }

  UsageAccessSnapshot _parseSnapshot(Object? response) {
    switch (response) {
      case {
        'contractVersion': usageAccessContractVersion,
        'status': final String status,
      }:
        return UsageAccessSnapshot(
          contractVersion: usageAccessContractVersion,
          status: switch (status) {
            'granted' => UsageAccessStatus.granted,
            'denied' => UsageAccessStatus.denied,
            _ => throw UsageAccessContractException(
              'Estado de permissão desconhecido: $status.',
            ),
          },
        );
      case {'contractVersion': int version}:
        throw UsageAccessContractException(
          'Versão do contrato não suportada: $version.',
        );
      default:
        throw const UsageAccessContractException(
          'Resposta inválida ao consultar a permissão.',
        );
    }
  }
}

class UnsupportedUsageAccessRepository implements UsageAccessRepository {
  const UnsupportedUsageAccessRepository();

  @override
  Future<UsageAccessSnapshot> checkAccess() async => const UsageAccessSnapshot(
    contractVersion: usageAccessContractVersion,
    status: UsageAccessStatus.denied,
  );

  @override
  Future<void> openSettings() async {
    throw const UsageSettingsOpenException(
      'O acesso aos dados de uso está disponível apenas no Android.',
    );
  }
}
