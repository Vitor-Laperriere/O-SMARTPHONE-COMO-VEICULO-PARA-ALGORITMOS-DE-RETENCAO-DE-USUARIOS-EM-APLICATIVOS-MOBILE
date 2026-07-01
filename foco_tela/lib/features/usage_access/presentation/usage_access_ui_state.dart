sealed class UsageAccessUiState {
  const UsageAccessUiState();
}

final class UsageAccessChecking extends UsageAccessUiState {
  const UsageAccessChecking();
}

final class UsageAccessDenied extends UsageAccessUiState {
  const UsageAccessDenied();
}

final class UsageSettingsOpening extends UsageAccessUiState {
  const UsageSettingsOpening();
}

final class UsageSettingsOpened extends UsageAccessUiState {
  const UsageSettingsOpened();
}

final class UsageSettingsOpenError extends UsageAccessUiState {
  const UsageSettingsOpenError(this.message);

  final String message;
}

final class UsageAccessGranted extends UsageAccessUiState {
  const UsageAccessGranted();
}

final class UsageAccessCheckError extends UsageAccessUiState {
  const UsageAccessCheckError(this.message);

  final String message;
}
