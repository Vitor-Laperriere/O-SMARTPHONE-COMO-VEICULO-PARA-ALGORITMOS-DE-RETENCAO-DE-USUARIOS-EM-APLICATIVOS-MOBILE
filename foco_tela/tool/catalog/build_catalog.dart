import 'dart:io';

import 'package:foco_tela/features/catalog/domain/app_catalog.dart';
import 'catalog_support.dart';

Future<void> main() async {
  final paths = resolveCatalogPaths();
  final sourceApps = loadYamlMap(paths.sourceAppsPath);
  final sourceEvidence = loadYamlMap(paths.sourceEvidencePath);

  final commit = await readGitCommit(paths.packageRoot);
  final owxHash = await readSha256(paths.owxPath);

  final mergedSource = <Object?, Object?>{
    ...sourceApps,
    'evidence': List<Object?>.from(sourceEvidence['evidence'] as List),
  };

  final snapshot = CatalogSnapshot.fromSourceMap(
    map: mergedSource,
    owxCommit: commit,
    owxHash: owxHash,
  );

  validateCatalogSnapshot(
    snapshot,
    allowedIris: loadAllowedIrisFromOwx(paths.owxPath),
  );

  final json = encodeSnapshot(snapshot);
  paths.generatedAssetPath.writeAsStringSync('$json\n');

  stdout.writeln(
    'Generated ${paths.generatedAssetPath.path} '
    '(commit $commit, owx $owxHash).',
  );
}
