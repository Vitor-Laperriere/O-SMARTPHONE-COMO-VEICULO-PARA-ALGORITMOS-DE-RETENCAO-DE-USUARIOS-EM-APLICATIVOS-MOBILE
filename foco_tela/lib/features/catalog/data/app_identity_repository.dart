import 'dart:io' show Platform;
import 'package:flutter/services.dart';

import '../domain/app_identity.dart';

abstract interface class AppIdentityRepository {
  Future<List<AppIdentity>> resolveMany(
    Iterable<String> packageNames, {
    bool refresh = false,
  });

  Future<AppIdentity> resolveOne(String packageName, {bool refresh = false});
}

class AndroidAppIdentityRepository implements AppIdentityRepository {
  AndroidAppIdentityRepository({
    MethodChannel channel = const MethodChannel('com.foco_tela/app_identity'),
    bool Function()? isAndroid,
  }) : _channel = channel,
       _isAndroid = isAndroid ?? (() => Platform.isAndroid);

  static const _contractVersion = 1;
  final MethodChannel _channel;
  final bool Function() _isAndroid;
  final Map<String, AppIdentity> _cache = {};

  @override
  Future<List<AppIdentity>> resolveMany(
    Iterable<String> packageNames, {
    bool refresh = false,
  }) async {
    final normalizedPackageNames = _normalize(packageNames);
    if (normalizedPackageNames.isEmpty) {
      return const [];
    }

    if (!refresh &&
        normalizedPackageNames.every(
          (packageName) => _cache.containsKey(packageName),
        )) {
      return [
        for (final packageName in normalizedPackageNames) _cache[packageName]!,
      ];
    }

    final missingPackageNames = refresh
        ? normalizedPackageNames
        : normalizedPackageNames
              .where((packageName) => !_cache.containsKey(packageName))
              .toList(growable: false);

    final resolvedByPackageName = <String, AppIdentity>{};
    if (missingPackageNames.isNotEmpty) {
      final resolved = await _queryAndroidIdentity(missingPackageNames);
      for (final identity in resolved) {
        _cache[identity.packageName] = identity;
        resolvedByPackageName[identity.packageName] = identity;
      }
    }

    return [
      for (final packageName in normalizedPackageNames)
        _cache[packageName] ??
            resolvedByPackageName[packageName] ??
            AppIdentity(packageName: packageName),
    ];
  }

  @override
  Future<AppIdentity> resolveOne(
    String packageName, {
    bool refresh = false,
  }) async {
    final resolved = await resolveMany([packageName], refresh: refresh);
    return resolved.single;
  }

  Future<List<AppIdentity>> _queryAndroidIdentity(
    List<String> packageNames,
  ) async {
    if (!_isAndroid()) {
      return packageNames
          .map((packageName) => AppIdentity(packageName: packageName))
          .toList(growable: false);
    }

    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getInstalledAppIdentities',
      <String, Object>{'packageNames': packageNames},
    );

    if (result == null) {
      return packageNames
          .map((packageName) => AppIdentity(packageName: packageName))
          .toList(growable: false);
    }

    switch (result) {
      case {
        'contractVersion': _contractVersion,
        'apps': final List<dynamic> rawApps,
      }:
        final identities = rawApps
            .map(
              (raw) => AppIdentity.fromContract(
                Map<Object?, Object?>.from(raw as Map),
              ),
            )
            .toList(growable: false);
        final resolvedByPackageName = {
          for (final identity in identities) identity.packageName: identity,
        };
        return [
          for (final packageName in packageNames)
            resolvedByPackageName[packageName] ??
                AppIdentity(packageName: packageName),
        ];
      case {'contractVersion': final int version}:
        throw Exception(
          'Versão do contrato de identidade de apps não suportada: $version.',
        );
      default:
        throw Exception('Resposta inválida do canal de identidade de apps.');
    }
  }

  static List<String> _normalize(Iterable<String> packageNames) {
    final normalized = <String>[];
    final seen = <String>{};
    for (final packageName in packageNames) {
      final trimmed = packageName.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) {
        continue;
      }
      normalized.add(trimmed);
    }
    return normalized;
  }
}

class UnsupportedAppIdentityRepository implements AppIdentityRepository {
  const UnsupportedAppIdentityRepository();

  @override
  Future<List<AppIdentity>> resolveMany(
    Iterable<String> packageNames, {
    bool refresh = false,
  }) async => packageNames
      .map((packageName) => AppIdentity(packageName: packageName.trim()))
      .toList(growable: false);

  @override
  Future<AppIdentity> resolveOne(
    String packageName, {
    bool refresh = false,
  }) async => AppIdentity(packageName: packageName.trim());
}

class InMemoryAppIdentityRepository implements AppIdentityRepository {
  InMemoryAppIdentityRepository(Iterable<AppIdentity> identities)
    : _identitiesByPackageName = {
        for (final identity in identities) identity.packageName: identity,
      };

  final Map<String, AppIdentity> _identitiesByPackageName;

  @override
  Future<List<AppIdentity>> resolveMany(
    Iterable<String> packageNames, {
    bool refresh = false,
  }) async => [
    for (final packageName in packageNames)
      _identitiesByPackageName[packageName.trim()] ??
          AppIdentity(packageName: packageName.trim()),
  ];

  @override
  Future<AppIdentity> resolveOne(
    String packageName, {
    bool refresh = false,
  }) async =>
      _identitiesByPackageName[packageName.trim()] ??
      AppIdentity(packageName: packageName.trim());
}
