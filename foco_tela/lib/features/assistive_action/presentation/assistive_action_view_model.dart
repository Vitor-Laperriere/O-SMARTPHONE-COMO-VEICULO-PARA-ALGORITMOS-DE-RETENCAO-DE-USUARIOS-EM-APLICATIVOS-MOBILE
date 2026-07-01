import 'package:flutter/foundation.dart';

import '../domain/assistive_settings.dart';

sealed class AssistiveActionUiState {
  const AssistiveActionUiState();
}

final class AssistiveActionIdle extends AssistiveActionUiState {
  const AssistiveActionIdle();
}

final class AssistiveActionOpening extends AssistiveActionUiState {
  const AssistiveActionOpening();
}

final class AssistiveActionOpened extends AssistiveActionUiState {
  const AssistiveActionOpened(this.destination);

  final AssistiveSettingsDestination destination;
}

final class AssistiveActionOpenError extends AssistiveActionUiState {
  const AssistiveActionOpenError(this.message);

  final String message;
}

class AssistiveActionViewModel extends ChangeNotifier {
  AssistiveActionViewModel({
    required AssistiveSettingsRepository repository,
    required this.packageName,
  }) : _repository = repository;

  final AssistiveSettingsRepository _repository;
  final String packageName;

  AssistiveActionUiState _state = const AssistiveActionIdle();
  AssistiveActionUiState get state => _state;

  Future<void> openSettings() async {
    if (_state is AssistiveActionOpening) return;
    _state = const AssistiveActionOpening();
    notifyListeners();
    try {
      final result = await _repository.openForPackage(packageName);
      _state = AssistiveActionOpened(result.destination);
    } on AssistiveSettingsException catch (error) {
      _state = AssistiveActionOpenError(error.message);
    }
    notifyListeners();
  }
}
