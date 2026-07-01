enum UsageEventKind {
  foreground,
  background,
  unlock,
  screenInteractive,
  screenNonInteractive,
}

class UsageEvent {
  const UsageEvent({
    required this.timestamp,
    required this.kind,
    this.packageName,
    this.appName,
  });

  final DateTime timestamp;
  final UsageEventKind kind;
  final String? packageName;
  final String? appName;

  factory UsageEvent.fromContract(Map<Object?, Object?> raw) {
    final map = Map<String, Object?>.from(raw);
    return switch (map) {
      {
        'timestampMillis': final int timestampMillis,
        'kind': final String kind,
      } =>
        UsageEvent(
          timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMillis),
          kind: _kindFromWire(kind),
          packageName: map['packageName'] as String?,
          appName: map['appName'] as String?,
        ),
      _ => throw const FormatException('Resposta inválida para evento de uso.'),
    };
  }
}

UsageEventKind _kindFromWire(String value) => switch (value) {
  'foreground' => UsageEventKind.foreground,
  'background' => UsageEventKind.background,
  'unlock' => UsageEventKind.unlock,
  'screenInteractive' => UsageEventKind.screenInteractive,
  'screenNonInteractive' => UsageEventKind.screenNonInteractive,
  _ => throw FormatException('Tipo de evento desconhecido: $value'),
};
