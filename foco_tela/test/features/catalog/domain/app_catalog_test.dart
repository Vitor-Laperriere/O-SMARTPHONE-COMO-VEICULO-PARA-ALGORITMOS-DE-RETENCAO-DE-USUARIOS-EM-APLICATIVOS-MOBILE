import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:foco_tela/features/catalog/domain/app_catalog.dart';
import '../../../../tool/catalog/catalog_support.dart';

void main() {
  test('mantém o catálogo completo sincronizado e com IRIs válidas', () async {
    final sourceSnapshot = await _loadSourceSnapshot();
    final assetSnapshot = _loadAssetSnapshot();

    expect(encodeSnapshot(assetSnapshot), encodeSnapshot(sourceSnapshot));

    expect(assetSnapshot.apps, hasLength(16));
    expect(
      assetSnapshot.apps.where(
        (app) => app.sampleGroup == CatalogSampleGroup.retentionSocial,
      ),
      hasLength(6),
    );
    expect(
      assetSnapshot.apps.where(
        (app) => app.sampleGroup == CatalogSampleGroup.mixed,
      ),
      hasLength(5),
    );
    expect(
      assetSnapshot.apps.where(
        (app) => app.sampleGroup == CatalogSampleGroup.utility,
      ),
      hasLength(5),
    );

    final packageNames = assetSnapshot.apps
        .map((app) => app.packageName)
        .toSet();
    expect(packageNames, {
      'com.instagram.android',
      'com.zhiliaoapp.musically',
      'com.google.android.youtube',
      'com.twitter.android',
      'com.facebook.katana',
      'com.instagram.barcelona',
      'com.whatsapp',
      'com.openai.chatgpt',
      'com.mercadolibre',
      'com.shopee.br',
      'com.lemon.lvoverseas',
      'com.google.android.gm',
      'com.google.android.apps.maps',
      'br.com.intermedium',
      'br.gov.meugovbr',
      'com.waze',
    });

    final instagram = assetSnapshot.appForPackageName('com.instagram.android');
    expect(instagram, isNotNull);
    expect(instagram!.technicalMechanisms, hasLength(3));
    expect(instagram.psychologicalTechniques, hasLength(1));
    expect(instagram.institutionalIntentions, hasLength(1));
    expect(instagram.associations, hasLength(5));
    expect(
      instagram.psychologicalTechniques.single.isCuratedForScoreTotal,
      isTrue,
    );
    expect(
      instagram.institutionalIntentions.single.isCuratedForScoreTotal,
      isTrue,
    );
    expect(instagram.contextStatus, CatalogContextStatus.approved);
    expect(instagram.hasApprovedContext, isTrue);
    expect(instagram.hasCandidateContextSuggestions, isFalse);
    expect(instagram.retentionStrength, closeTo(2.0, 0.0001));
    expect(instagram.retentionStrengthBand.label, 'alta');

    final capcut = assetSnapshot.appForPackageName('com.lemon.lvoverseas');
    expect(capcut, isNotNull);
    expect(capcut!.contextStatus, CatalogContextStatus.candidateAutomatic);
    expect(capcut.hasApprovedContext, isFalse);
    expect(capcut.hasCandidateContextSuggestions, isTrue);
    expect(
      capcut.contextProfile.candidateLabels,
      contains('Social Validation'),
    );
    expect(capcut.contextProfile.summary, contains('tipo sugerido'));
    expect(capcut.retentionStrength, 0);

    final chatgpt = assetSnapshot.appForPackageName('com.openai.chatgpt');
    expect(chatgpt, isNotNull);
    expect(chatgpt!.associations, isEmpty);
    expect(chatgpt.contextStatus, CatalogContextStatus.insufficient);
    expect(chatgpt.hasApprovedContext, isFalse);
    expect(chatgpt.hasCandidateContextSuggestions, isFalse);
    expect(chatgpt.retentionStrength, 0);
    expect(chatgpt.retentionStrengthBand.label, 'ausente');

    final inter = assetSnapshot.appForPackageName('br.com.intermedium');
    expect(inter, isNotNull);
    expect(inter!.associations, hasLength(1));
    expect(
      inter.associations.first.contextualRole,
      CatalogContextualRole.undetermined,
    );
    expect(inter.retentionStrength, 0);

    expect(
      () => validateCatalogSnapshot(
        assetSnapshot,
        allowedIris: loadAllowedIrisFromOwx(_owxFile()),
      ),
      returnsNormally,
    );
  });
}

Future<CatalogSnapshot> _loadSourceSnapshot() async {
  final sourceApps = loadYamlMap(File('catalog/apps.yaml'));
  final sourceEvidence = loadYamlMap(File('catalog/evidence.yaml'));
  final commit = await readGitCommit(Directory.current);
  final owxHash = await readSha256(_owxFile());

  final mergedSource = <Object?, Object?>{
    ...sourceApps,
    'evidence': List<Object?>.from(sourceEvidence['evidence'] as List),
  };

  return CatalogSnapshot.fromSourceMap(
    map: mergedSource,
    owxCommit: commit,
    owxHash: owxHash,
  );
}

CatalogSnapshot _loadAssetSnapshot() {
  final rawJson = File('assets/catalog/apps.json').readAsStringSync();
  return CatalogSnapshot.fromJson(
    Map<Object?, Object?>.from(jsonDecode(rawJson) as Map),
  );
}

File _owxFile() => File(
  '../poc1-ontologies-owx-REVISION-HEAD/'
  'urn_webprotege_ontology_7543882f-929e-4586-bf29-1f3930cfc5f2.owx',
);
