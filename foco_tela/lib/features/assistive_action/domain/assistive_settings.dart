const int assistiveSettingsContractVersion = 1;

enum AssistiveSettingsDestination { appUsageSettings, applicationDetails }

class AssistiveSettingsOpenResult {
  const AssistiveSettingsOpenResult({required this.destination});

  final AssistiveSettingsDestination destination;
}

abstract interface class AssistiveSettingsRepository {
  Future<AssistiveSettingsOpenResult> openForPackage(String packageName);
}

class AssistiveSettingsException implements Exception {
  const AssistiveSettingsException([
    this.message = 'Não foi possível abrir as configurações deste aplicativo.',
  ]);

  final String message;

  @override
  String toString() => 'AssistiveSettingsException: $message';
}
