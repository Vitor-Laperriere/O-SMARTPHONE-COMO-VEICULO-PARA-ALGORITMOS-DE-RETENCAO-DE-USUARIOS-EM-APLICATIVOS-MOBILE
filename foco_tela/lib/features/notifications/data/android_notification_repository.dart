import 'package:flutter/services.dart';

import '../domain/notification_observation.dart';

class AndroidNotificationRepository implements NotificationRepository {
  AndroidNotificationRepository({
    MethodChannel channel = const MethodChannel('com.foco_tela/notifications'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<NotificationAccessStatus> checkAccess() async {
    final response = await _channel.invokeMethod<Object?>(
      'getNotificationAccessState',
    );
    return switch (response) {
      {
        'contractVersion': notificationContractVersion,
        'status': final String status,
      } =>
        switch (status) {
          'granted' => NotificationAccessStatus.granted,
          'denied' => NotificationAccessStatus.denied,
          'unsupported' => NotificationAccessStatus.unsupported,
          _ => throw NotificationRepositoryException(
            'Estado de notificações desconhecido: $status.',
          ),
        },
      {'contractVersion': final int version} =>
        throw NotificationRepositoryException(
          'Versão do contrato de notificações não suportada: $version.',
        ),
      _ => throw const NotificationRepositoryException(
        'Resposta inválida ao consultar notificações.',
      ),
    };
  }

  @override
  Future<void> openSettings() async {
    await _channel.invokeMethod<Object?>('openNotificationListenerSettings');
  }

  @override
  Future<List<DailyNotificationCount>> loadDailyCounts({
    required DateTime start,
    required DateTime end,
  }) async {
    final response = await _channel
        .invokeMethod<Object?>('getDailyNotificationCounts', {
          'startTimeMillis': start.millisecondsSinceEpoch,
          'endTimeMillis': end.millisecondsSinceEpoch,
        });
    return switch (response) {
      {
        'contractVersion': notificationContractVersion,
        'counts': final List<Object?> rows,
      } =>
        rows
            .map((row) => _countFromMap(Map<Object?, Object?>.from(row as Map)))
            .toList(growable: false),
      {'contractVersion': final int version} =>
        throw NotificationRepositoryException(
          'Versão do contrato de notificações não suportada: $version.',
        ),
      _ => throw const NotificationRepositoryException(
        'Resposta inválida ao consultar contagens de notificações.',
      ),
    };
  }

  @override
  Future<NotificationLastObservation?> loadLastObservation() async {
    final response = await _channel.invokeMethod<Object?>(
      'getLastNotificationObservation',
    );
    return switch (response) {
      {
        'contractVersion': notificationContractVersion,
        'observation': final Map<Object?, Object?> observation,
      } =>
        _lastObservationFromMap(observation),
      {'contractVersion': notificationContractVersion, 'observation': null} =>
        null,
      {'contractVersion': final int version} =>
        throw NotificationRepositoryException(
          'Versão do contrato de notificações não suportada: $version.',
        ),
      _ => throw const NotificationRepositoryException(
        'Resposta inválida ao consultar última notificação.',
      ),
    };
  }

  @override
  Future<NotificationContentSettings> loadContentSettings() async {
    final response = await _channel.invokeMethod<Object?>('getContentSettings');
    return switch (response) {
      {
        'contractVersion': notificationContractVersion,
        'enabled': final bool enabled,
        'authorizedPackages': final List<Object?> packages,
      } =>
        NotificationContentSettings(
          enabled: enabled,
          authorizedPackageNames: packages.cast<String>().toSet(),
        ),
      _ => throw const NotificationRepositoryException(
        'Resposta inválida ao consultar conteúdo de notificações.',
      ),
    };
  }

  @override
  Future<void> setContentModeEnabled(bool enabled) async {
    await _channel.invokeMethod<Object?>('setContentModeEnabled', {
      'enabled': enabled,
    });
  }

  @override
  Future<void> authorizeContentPackage(String packageName) async {
    await _channel.invokeMethod<Object?>('authorizeContentPackage', {
      'packageName': packageName,
    });
  }

  @override
  Future<void> authorizeContentPackages(Set<String> packageNames) async {
    await _channel.invokeMethod<Object?>('authorizeContentPackages', {
      'packageNames': packageNames.toList(growable: false)..sort(),
    });
  }

  @override
  Future<void> revokeContentPackage(String packageName) async {
    await _channel.invokeMethod<Object?>('revokeContentPackage', {
      'packageName': packageName,
    });
  }

  @override
  Future<bool> authenticateContentViewing() async {
    final response = await _channel.invokeMethod<Object?>(
      'authenticateContentViewing',
    );
    return switch (response) {
      {
        'contractVersion': notificationContractVersion,
        'authenticated': final bool authenticated,
      } =>
        authenticated,
      _ => throw const NotificationRepositoryException(
        'Resposta inválida ao autenticar consulta de conteúdo.',
      ),
    };
  }

  @override
  Future<List<NotificationTextRecord>> loadStoredContent({
    required DateTime start,
    required DateTime end,
    String? packageName,
  }) async {
    final response = await _channel.invokeMethod<Object?>('getStoredContent', {
      'startTimeMillis': start.millisecondsSinceEpoch,
      'endTimeMillis': end.millisecondsSinceEpoch,
      if (packageName != null) 'packageName': packageName,
    });
    return switch (response) {
      {
        'contractVersion': notificationContractVersion,
        'records': final List<Object?> rows,
      } =>
        rows
            .map(
              (row) => _recordFromMap(Map<Object?, Object?>.from(row as Map)),
            )
            .toList(growable: false),
      _ => throw const NotificationRepositoryException(
        'Resposta inválida ao consultar conteúdo armazenado.',
      ),
    };
  }

  @override
  Future<void> clearStoredContent() async {
    await _channel.invokeMethod<Object?>('clearStoredContent');
  }

  DailyNotificationCount _countFromMap(Map<Object?, Object?> map) =>
      switch (map) {
        {
          'dayStartMillis': final int dayStartMillis,
          'packageName': final String packageName,
          'count': final int count,
        } =>
          DailyNotificationCount(
            dayStart: DateTime.fromMillisecondsSinceEpoch(dayStartMillis),
            packageName: packageName,
            count: count,
          ),
        _ => throw const NotificationRepositoryException(
          'Registro de contagem de notificações inválido.',
        ),
      };

  NotificationLastObservation _lastObservationFromMap(
    Map<Object?, Object?> map,
  ) => switch (map) {
    {
      'observedAtMillis': final int observedAtMillis,
      'packageName': final String packageName,
      'count': final int count,
    } =>
      NotificationLastObservation(
        observedAt: DateTime.fromMillisecondsSinceEpoch(observedAtMillis),
        packageName: packageName,
        count: count,
      ),
    _ => throw const NotificationRepositoryException(
      'Registro de última notificação inválido.',
    ),
  };

  NotificationTextRecord _recordFromMap(Map<Object?, Object?> map) =>
      switch (map) {
        {
          'packageName': final String packageName,
          'postedAtMillis': final int postedAtMillis,
          'title': final String title,
          'text': final String text,
          'expiresAtMillis': final int expiresAtMillis,
        } =>
          NotificationTextRecord(
            packageName: packageName,
            postedAt: DateTime.fromMillisecondsSinceEpoch(postedAtMillis),
            title: title,
            text: text,
            expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAtMillis),
          ),
        _ => throw const NotificationRepositoryException(
          'Registro textual de notificação inválido.',
        ),
      };
}

class UnsupportedNotificationRepository implements NotificationRepository {
  const UnsupportedNotificationRepository();

  @override
  Future<NotificationAccessStatus> checkAccess() async =>
      NotificationAccessStatus.unsupported;

  @override
  Future<void> openSettings() async {
    throw const NotificationRepositoryException(
      'Notificações observáveis estão disponíveis apenas no Android.',
    );
  }

  @override
  Future<List<DailyNotificationCount>> loadDailyCounts({
    required DateTime start,
    required DateTime end,
  }) async => const [];

  @override
  Future<NotificationLastObservation?> loadLastObservation() async => null;

  @override
  Future<NotificationContentSettings> loadContentSettings() async =>
      NotificationContentSettings.defaults();

  @override
  Future<void> setContentModeEnabled(bool enabled) async {}

  @override
  Future<void> authorizeContentPackage(String packageName) async {}

  @override
  Future<void> authorizeContentPackages(Set<String> packageNames) async {}

  @override
  Future<void> revokeContentPackage(String packageName) async {}

  @override
  Future<bool> authenticateContentViewing() async => false;

  @override
  Future<List<NotificationTextRecord>> loadStoredContent({
    required DateTime start,
    required DateTime end,
    String? packageName,
  }) async => const [];

  @override
  Future<void> clearStoredContent() async {}
}
