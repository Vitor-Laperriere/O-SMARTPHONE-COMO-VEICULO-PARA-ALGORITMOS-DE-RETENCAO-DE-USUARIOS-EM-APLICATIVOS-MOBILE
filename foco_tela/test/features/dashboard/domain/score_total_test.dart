import 'package:flutter_test/flutter_test.dart';

import 'package:foco_tela/features/catalog/domain/app_catalog.dart';
import 'package:foco_tela/features/dashboard/domain/behavioral_signal_calibration.dart';
import 'package:foco_tela/features/dashboard/domain/episode_analysis.dart';
import 'package:foco_tela/features/dashboard/domain/score_total.dart';

void main() {
  test('calcula pesos, faixas e decomposição do score_total', () {
    final assessment = const ScoreTotalCalculator().calculate(
      behavioralScore: _behavioralScore(BehavioralScoreRange.high, 1.0),
      technicalContext: _technicalContext(weight: 1.0),
      catalogApp: _catalogApp(
        psychologicalTechniques: [_curatedPsychological()],
        institutionalIntentions: [_curatedInstitutional()],
      ),
      versions: _versions,
    );

    expect(assessment.value, closeTo(0.875, 0.0001));
    expect(assessment.band, ScoreTotalBand.high);
    expect(assessment.algorithmVersion, 'score-total-2026-06-26-v1');
    expect(assessment.dimensions, hasLength(4));
    expect(
      assessment
          .dimension(ScoreTotalDimensionKind.behavioralSignals)!
          .maxWeight,
      0.40,
    );
    expect(
      assessment
          .dimension(ScoreTotalDimensionKind.technicalMechanisms)!
          .maxWeight,
      0.25,
    );
    expect(
      assessment
          .dimension(ScoreTotalDimensionKind.psychologicalTechniques)!
          .iri,
      'SocialValidation',
    );
    expect(
      assessment
          .dimension(ScoreTotalDimensionKind.institutionalIntentions)!
          .iri,
      'EngagementIntention',
    );
  });

  test('não promove técnica ou intenção sem curadoria suficiente', () {
    final assessment = const ScoreTotalCalculator().calculate(
      behavioralScore: _behavioralScore(BehavioralScoreRange.high, 1.0),
      technicalContext: _technicalContext(weight: 0.2),
      catalogApp: _catalogApp(
        psychologicalTechniques: [
          _curatedPsychological(confidence: CatalogConfidence.low),
          _curatedPsychological(relation: null),
        ],
        institutionalIntentions: [
          _curatedInstitutional(role: CatalogContextualRole.utility),
          _curatedInstitutional(caution: null),
        ],
      ),
      versions: _versions,
    );

    expect(assessment.hasCuratedTechniqueOrIntention, isFalse);
    expect(
      assessment
          .dimension(ScoreTotalDimensionKind.psychologicalTechniques)!
          .contribution,
      0,
    );
    expect(
      assessment
          .dimension(ScoreTotalDimensionKind.institutionalIntentions)!
          .contribution,
      0,
    );
    expect(assessment.band, ScoreTotalBand.moderate);
  });

  test('campos textuais legados não alimentam score_total', () {
    final assessment = const ScoreTotalCalculator().calculate(
      behavioralScore: _behavioralScore(BehavioralScoreRange.medium, 0.5),
      technicalContext: _technicalContext(weight: 0),
      catalogApp: _catalogApp(
        psychologicalTechnique: 'FOMO',
        institutionalIntention: 'EngagementIntention',
      ),
      versions: _versions,
    );

    expect(assessment.value, closeTo(0.20, 0.0001));
    expect(assessment.band, ScoreTotalBand.low);
    expect(assessment.hasCuratedTechniqueOrIntention, isFalse);
  });
}

BehavioralSignalScore _behavioralScore(
  BehavioralScoreRange range,
  double value,
) => BehavioralSignalScore(value: value, range: range, contributions: const []);

ContextualRetentionStrength _technicalContext({required double weight}) =>
    ContextualRetentionStrength(
      isAvailable: true,
      rawValue: weight,
      matrixValue: weight,
      cap: 2.0,
      range: ContextualStrengthRange.medium,
      contributions: weight == 0
          ? const []
          : [
              ContextualRetentionContribution(
                iri: 'InfiniteScrollFeed',
                label: 'Infinite Scroll Feed',
                confidence: CatalogConfidence.high,
                weight: weight,
                evidence: [_evidence()],
              ),
            ],
    );

CatalogApp _catalogApp({
  String? psychologicalTechnique,
  String? institutionalIntention,
  List<CatalogAssociation> psychologicalTechniques = const [],
  List<CatalogAssociation> institutionalIntentions = const [],
}) => CatalogApp(
  packageName: 'com.example.social',
  displayName: 'Social',
  sampleGroup: CatalogSampleGroup.retentionSocial,
  technicalMechanisms: const [],
  osComponents: const [],
  psychologicalTechnique: psychologicalTechnique,
  institutionalIntention: institutionalIntention,
  psychologicalTechniques: psychologicalTechniques,
  institutionalIntentions: institutionalIntentions,
);

CatalogAssociation _curatedPsychological({
  CatalogConfidence confidence = CatalogConfidence.high,
  CatalogContextualRole role = CatalogContextualRole.retention,
  String? relation = 'usesTechnique via SocialValidation',
  String? caution = 'Cautela rastreável.',
}) => CatalogAssociation(
  kind: CatalogAssociationKind.psychologicalTechnique,
  iri: 'SocialValidation',
  label: 'Validação social',
  contextualRole: role,
  confidence: confidence,
  evidence: [_evidence()],
  relation: relation,
  scope: 'app_specific_catalog_association',
  caution: caution,
);

CatalogAssociation _curatedInstitutional({
  CatalogContextualRole role = CatalogContextualRole.retention,
  String? caution = 'Cautela rastreável.',
}) => CatalogAssociation(
  kind: CatalogAssociationKind.institutionalIntention,
  iri: 'EngagementIntention',
  label: 'Intenção de engajamento',
  contextualRole: role,
  confidence: CatalogConfidence.high,
  evidence: [_evidence()],
  relation: 'aimsAtIntention via FeedAlgorithm',
  scope: 'app_specific_catalog_association',
  caution: caution,
);

CatalogEvidence _evidence() => CatalogEvidence(
  id: 'evidence',
  type: CatalogEvidenceType.appStoreListing,
  reference: 'https://example.test',
  date: DateTime(2026, 6, 26),
  observedVersion: '2026-06-26',
  supportedStatement: 'Evidência de teste.',
  scope: 'app_specific',
);

const _versions = AnalysisArtifactVersions(
  calibrationVersion: 'calibration-v1',
  catalogVersion: 'catalog-v1',
  owxIri: 'urn:test:owl',
  owxVersion: 'owl-v1',
  owxCommit: 'abc123',
  owxHash: 'def456',
);
