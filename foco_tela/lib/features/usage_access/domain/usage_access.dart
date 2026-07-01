const int usageAccessContractVersion = 1;

enum UsageAccessStatus { granted, denied }

class UsageAccessSnapshot {
  const UsageAccessSnapshot({
    required this.contractVersion,
    required this.status,
  });

  final int contractVersion;
  final UsageAccessStatus status;
}

abstract interface class UsageAccessRepository {
  Future<UsageAccessSnapshot> checkAccess();

  Future<void> openSettings();
}

class UsageAccessContractException implements Exception {
  const UsageAccessContractException(this.message);

  final String message;

  @override
  String toString() => 'UsageAccessContractException: $message';
}

class UsageSettingsOpenException implements Exception {
  const UsageSettingsOpenException([
    this.message = 'Não foi possível abrir as configurações de acesso ao uso.',
  ]);

  final String message;

  @override
  String toString() => 'UsageSettingsOpenException: $message';
}
