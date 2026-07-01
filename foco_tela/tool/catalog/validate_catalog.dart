import 'dart:convert';
import 'dart:io';

import 'package:foco_tela/features/catalog/domain/app_catalog.dart';
import 'catalog_support.dart';

Future<void> main() async {
  final paths = resolveCatalogPaths();
  final sourceApps = loadYamlMap(paths.sourceAppsPath);
  final sourceEvidence = loadYamlMap(paths.sourceEvidencePath);
  final assetJson = paths.generatedAssetPath.readAsStringSync();

  final commit = await readGitCommit(paths.packageRoot);
  final owxHash = await readSha256(paths.owxPath);

  final mergedSource = <Object?, Object?>{
    ...sourceApps,
    'evidence': List<Object?>.from(sourceEvidence['evidence'] as List),
  };

  final expectedSnapshot = CatalogSnapshot.fromSourceMap(
    map: mergedSource,
    owxCommit: commit,
    owxHash: owxHash,
  );
  validateCatalogSnapshot(
    expectedSnapshot,
    allowedIris: loadAllowedIrisFromOwx(paths.owxPath),
  );

  final actualSnapshot = CatalogSnapshot.fromJson(
    Map<Object?, Object?>.from(jsonDecode(assetJson) as Map),
  );

  final expectedJson = encodeSnapshot(expectedSnapshot);
  final actualJson = encodeSnapshot(actualSnapshot);
  if (actualJson != expectedJson) {
    stderr.writeln('O asset gerado está desatualizado.');
    exitCode = 1;
    return;
  }

  stdout.writeln('Catalogo validado com sucesso.');
}
