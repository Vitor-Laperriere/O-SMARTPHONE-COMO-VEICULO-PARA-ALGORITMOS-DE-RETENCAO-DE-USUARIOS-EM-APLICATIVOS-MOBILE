import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/app_catalog.dart';

abstract interface class AppCatalogRepository {
  Future<CatalogSnapshot> loadSnapshot();

  Future<CatalogApp?> findByPackageName(String packageName);
}

class AssetAppCatalogRepository implements AppCatalogRepository {
  AssetAppCatalogRepository({
    AssetBundle? bundle,
    this.assetPath = 'assets/catalog/apps.json',
  }) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final String assetPath;
  CatalogSnapshot? _snapshot;

  @override
  Future<CatalogSnapshot> loadSnapshot() async {
    final cached = _snapshot;
    if (cached != null) {
      return cached;
    }

    final rawJson = await _bundle.loadString(assetPath);
    final decoded = jsonDecode(rawJson);
    final snapshot = CatalogSnapshot.fromJson(
      Map<Object?, Object?>.from(decoded as Map),
    );
    _snapshot = snapshot;
    return snapshot;
  }

  @override
  Future<CatalogApp?> findByPackageName(String packageName) async =>
      (await loadSnapshot()).appForPackageName(packageName);
}

class InMemoryAppCatalogRepository implements AppCatalogRepository {
  InMemoryAppCatalogRepository(this.snapshot);

  final CatalogSnapshot snapshot;

  @override
  Future<CatalogSnapshot> loadSnapshot() async => snapshot;

  @override
  Future<CatalogApp?> findByPackageName(String packageName) async =>
      snapshot.appForPackageName(packageName);
}
