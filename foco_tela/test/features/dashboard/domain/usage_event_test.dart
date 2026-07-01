import 'package:flutter_test/flutter_test.dart';

import 'package:foco_tela/features/dashboard/domain/usage_event.dart';

void main() {
  test('contrato representa todos os eventos observáveis da V1-03', () {
    final expectedKinds = <String, UsageEventKind>{
      'foreground': UsageEventKind.foreground,
      'background': UsageEventKind.background,
      'unlock': UsageEventKind.unlock,
      'screenInteractive': UsageEventKind.screenInteractive,
      'screenNonInteractive': UsageEventKind.screenNonInteractive,
    };

    for (final MapEntry(key: wireKind, value: expectedKind)
        in expectedKinds.entries) {
      final event = UsageEvent.fromContract({
        'timestampMillis': DateTime(2026, 6, 21, 8).millisecondsSinceEpoch,
        'kind': wireKind,
      });

      expect(event.kind, expectedKind);
    }
  });
}
