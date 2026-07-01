import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:yaml/yaml.dart';

import 'package:foco_tela/features/catalog/domain/app_catalog.dart';

class CatalogSourcePaths {
  CatalogSourcePaths({
    required this.packageRoot,
    required this.tccRoot,
    required this.sourceAppsPath,
    required this.sourceEvidencePath,
    required this.generatedAssetPath,
    required this.owxPath,
  });

  final Directory packageRoot;
  final Directory tccRoot;
  final File sourceAppsPath;
  final File sourceEvidencePath;
  final File generatedAssetPath;
  final File owxPath;
}

CatalogSourcePaths resolveCatalogPaths() {
  final packageRoot = Directory.fromUri(Platform.script.resolve('../..'));
  final tccRoot = Directory.fromUri(packageRoot.uri.resolve('../'));
  final sourceAppsPath = File.fromUri(
    packageRoot.uri.resolve('catalog/apps.yaml'),
  );
  final sourceEvidencePath = File.fromUri(
    packageRoot.uri.resolve('catalog/evidence.yaml'),
  );
  final generatedAssetPath = File.fromUri(
    packageRoot.uri.resolve('assets/catalog/apps.json'),
  );
  final owxPath = File.fromUri(
    tccRoot.uri.resolve(
      'poc1-ontologies-owx-REVISION-HEAD/'
      'urn_webprotege_ontology_7543882f-929e-4586-bf29-1f3930cfc5f2.owx',
    ),
  );

  return CatalogSourcePaths(
    packageRoot: packageRoot,
    tccRoot: tccRoot,
    sourceAppsPath: sourceAppsPath,
    sourceEvidencePath: sourceEvidencePath,
    generatedAssetPath: generatedAssetPath,
    owxPath: owxPath,
  );
}

Future<String> readGitCommit(Directory workingDirectory) async {
  final result = await Process.run('git', [
    'rev-parse',
    'HEAD',
  ], workingDirectory: workingDirectory.path);
  if (result.exitCode != 0) {
    return 'unknown';
  }
  return (result.stdout as String).trim();
}

Future<String> readSha256(File file) async {
  final bytes = await file.readAsBytes();
  return sha256.convert(bytes).toString();
}

Map<Object?, Object?> loadYamlMap(File file) {
  final parsed = loadYaml(file.readAsStringSync());
  if (parsed is! YamlMap) {
    throw FormatException('Arquivo YAML inválido: ${file.path}.');
  }
  return Map<Object?, Object?>.from(parsed);
}

Set<String> loadAllowedIrisFromOwx(File owxFile) {
  final content = owxFile.readAsStringSync();
  final iris = <String>{};
  final barePattern = RegExp(r'<IRI>([^<]+)</IRI>');
  final attributePattern = RegExp(r'IRI="([^"]+)"');

  for (final match in barePattern.allMatches(content)) {
    iris.add(match.group(1)!);
  }
  for (final match in attributePattern.allMatches(content)) {
    final iri = match.group(1)!;
    if (iri.startsWith('#')) {
      iris.add(iri.substring(1));
    } else {
      iris.add(iri);
    }
  }
  return iris;
}

void validateCatalogSnapshot(
  CatalogSnapshot snapshot, {
  required Set<String> allowedIris,
}) {
  if (snapshot.apps.isEmpty) {
    throw const FormatException('Catálogo sem aplicativos.');
  }
  if (snapshot.evidence.isEmpty) {
    throw const FormatException('Catálogo sem evidências.');
  }
  if (snapshot.apps.length != 16) {
    throw FormatException(
      'Catálogo incompleto: esperados 16 aplicativos, '
      'encontrados ${snapshot.apps.length}.',
    );
  }
  if (snapshot.apps.length != snapshot.appsByPackageName.length) {
    throw const FormatException('package_name duplicado no catálogo.');
  }
  if (snapshot.evidence.length != snapshot.evidenceById.length) {
    throw const FormatException('Evidence id duplicado no catálogo.');
  }

  final expectedGroupCounts = <CatalogSampleGroup, int>{
    CatalogSampleGroup.retentionSocial: 6,
    CatalogSampleGroup.mixed: 5,
    CatalogSampleGroup.utility: 5,
  };
  final actualGroupCounts = <CatalogSampleGroup, int>{};
  for (final app in snapshot.apps) {
    actualGroupCounts.update(
      app.sampleGroup,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }
  for (final entry in expectedGroupCounts.entries) {
    if (actualGroupCounts[entry.key] != entry.value) {
      throw FormatException(
        'Contagem inválida para o grupo ${entry.key.value}: '
        'esperado ${entry.value}, encontrado ${actualGroupCounts[entry.key] ?? 0}.',
      );
    }
  }

  for (final app in snapshot.apps) {
    for (final association in app.associations) {
      if (!allowedIris.contains(association.iri)) {
        throw FormatException('IRI inexistente na OWX: ${association.iri}.');
      }
      if (association.contextualRole == CatalogContextualRole.retention &&
          association.evidence.isEmpty) {
        throw FormatException(
          'Associação retention sem evidência: ${app.packageName}/${association.iri}.',
        );
      }
      if (association.kind == CatalogAssociationKind.psychologicalTechnique ||
          association.kind == CatalogAssociationKind.institutionalIntention) {
        _validateScoreTotalAssociation(app: app, association: association);
      }
    }
  }
}

void _validateScoreTotalAssociation({
  required CatalogApp app,
  required CatalogAssociation association,
}) {
  final target = '${app.packageName}/${association.iri}';
  if (!association.hasMediumOrHighEvidence) {
    throw FormatException(
      'Associação analítica sem evidência média/alta: $target.',
    );
  }
  if (association.contextualRole != CatalogContextualRole.retention) {
    throw FormatException(
      'Associação analítica sem papel de retenção: $target.',
    );
  }
  if (!association.hasExplicitRelation) {
    throw FormatException(
      'Associação analítica sem relação explícita: $target.',
    );
  }
  if (!association.hasScope) {
    throw FormatException('Associação analítica sem escopo: $target.');
  }
  if (!association.hasCaution) {
    throw FormatException('Associação analítica sem cautela: $target.');
  }
}

String encodeSnapshot(CatalogSnapshot snapshot) =>
    const JsonEncoder.withIndent('  ').convert(snapshot.toJson());
