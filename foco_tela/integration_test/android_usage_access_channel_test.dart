import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:foco_tela/features/usage_access/data/android_usage_access_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'canal Android informa o estado real configurado no dispositivo',
    (_) async {
      const expectedStatus = String.fromEnvironment('EXPECTED_USAGE_ACCESS');
      expect(
        expectedStatus,
        isNotEmpty,
        reason: 'Informe EXPECTED_USAGE_ACCESS ao executar o teste.',
      );

      final snapshot = await AndroidUsageAccessRepository().checkAccess();

      expect(snapshot.status.name, expectedStatus);
    },
  );
}
