import '../../catalog/domain/app_catalog.dart';
import 'episode_analysis.dart';

enum ScoreTotalBand { low, moderate, high }

extension ScoreTotalBandLabel on ScoreTotalBand {
  String get label => switch (this) {
    ScoreTotalBand.low => 'Baixos',
    ScoreTotalBand.moderate => 'Moderados',
    ScoreTotalBand.high => 'Altos',
  };
}

enum ScoreTotalDimensionKind {
  behavioralSignals,
  technicalMechanisms,
  psychologicalTechniques,
  institutionalIntentions,
}

extension ScoreTotalDimensionKindLabel on ScoreTotalDimensionKind {
  String get label => switch (this) {
    ScoreTotalDimensionKind.behavioralSignals => 'Sinais comportamentais',
    ScoreTotalDimensionKind.technicalMechanisms => 'Mecanismos técnicos',
    ScoreTotalDimensionKind.psychologicalTechniques =>
      'Técnicas psicológicas curadas',
    ScoreTotalDimensionKind.institutionalIntentions =>
      'Intenções institucionais curadas',
  };
}

class ScoreTotalDimension {
  const ScoreTotalDimension({
    required this.kind,
    required this.contribution,
    required this.maxWeight,
    required this.evidenceLabel,
    required this.version,
    required this.caution,
    this.iri,
    this.scope,
  });

  final ScoreTotalDimensionKind kind;
  final double contribution;
  final double maxWeight;
  final String evidenceLabel;
  final String version;
  final String caution;
  final String? iri;
  final String? scope;
}

class ScoreTotalAssessment {
  ScoreTotalAssessment({
    required this.value,
    required this.band,
    required this.algorithmVersion,
    required List<ScoreTotalDimension> dimensions,
    required List<CatalogAssociation> curatedAssociations,
  }) : dimensions = List.unmodifiable(dimensions),
       curatedAssociations = List.unmodifiable(curatedAssociations);

  final double value;
  final ScoreTotalBand band;
  final String algorithmVersion;
  final List<ScoreTotalDimension> dimensions;
  final List<CatalogAssociation> curatedAssociations;

  bool get hasCuratedTechniqueOrIntention => curatedAssociations.any(
    (association) =>
        association.kind == CatalogAssociationKind.psychologicalTechnique ||
        association.kind == CatalogAssociationKind.institutionalIntention,
  );

  ScoreTotalDimension? dimension(ScoreTotalDimensionKind kind) {
    for (final dimension in dimensions) {
      if (dimension.kind == kind) return dimension;
    }
    return null;
  }
}

class ScoreTotalCalculator {
  const ScoreTotalCalculator();

  static const algorithmVersion = 'score-total-2026-06-26-v1';
  static const behavioralMaxWeight = 0.40;
  static const technicalMaxWeight = 0.25;
  static const psychologicalMaxWeight = 0.20;
  static const institutionalMaxWeight = 0.15;

  ScoreTotalAssessment calculate({
    required BehavioralSignalScore behavioralScore,
    required ContextualRetentionStrength technicalContext,
    required CatalogApp? catalogApp,
    required AnalysisArtifactVersions versions,
  }) {
    final curatedPsychological = _curatedAssociations(
      catalogApp?.psychologicalTechniques ?? const [],
    );
    final curatedInstitutional = _curatedAssociations(
      catalogApp?.institutionalIntentions ?? const [],
    );

    final behavioralContribution =
        _clamp01(behavioralScore.value) * behavioralMaxWeight;
    final technicalContribution = technicalContext.cap <= 0
        ? 0.0
        : _clamp01(technicalContext.matrixValue / technicalContext.cap) *
              technicalMaxWeight;
    final psychologicalContribution =
        _strongestConfidence(curatedPsychological) * psychologicalMaxWeight;
    final institutionalContribution =
        _strongestConfidence(curatedInstitutional) * institutionalMaxWeight;

    final value = _clamp01(
      behavioralContribution +
          technicalContribution +
          psychologicalContribution +
          institutionalContribution,
    );

    return ScoreTotalAssessment(
      value: value,
      band: _bandFor(value),
      algorithmVersion: algorithmVersion,
      dimensions: [
        ScoreTotalDimension(
          kind: ScoreTotalDimensionKind.behavioralSignals,
          contribution: behavioralContribution,
          maxWeight: behavioralMaxWeight,
          evidenceLabel: behavioralScore.range.name,
          version: versions.calibrationVersion,
          caution:
              'Sinais de uso observados são descritivos e não demonstram causalidade.',
        ),
        ScoreTotalDimension(
          kind: ScoreTotalDimensionKind.technicalMechanisms,
          contribution: technicalContribution,
          maxWeight: technicalMaxWeight,
          evidenceLabel: technicalContext.contributions.isEmpty
              ? 'sem mecanismo técnico curado'
              : technicalContext.contributions
                    .map((item) => '${item.label} (${item.confidence.label})')
                    .join(', '),
          version: versions.catalogVersion,
          caution:
              'Mecanismos catalogados indicam contexto de retenção, não intenção isolada.',
          iri: technicalContext.contributions.isEmpty
              ? null
              : technicalContext.contributions.first.iri,
        ),
        _curatedDimension(
          kind: ScoreTotalDimensionKind.psychologicalTechniques,
          associations: curatedPsychological,
          maxWeight: psychologicalMaxWeight,
          version: versions.catalogVersion,
        ),
        _curatedDimension(
          kind: ScoreTotalDimensionKind.institutionalIntentions,
          associations: curatedInstitutional,
          maxWeight: institutionalMaxWeight,
          version: versions.catalogVersion,
        ),
      ],
      curatedAssociations: [...curatedPsychological, ...curatedInstitutional],
    );
  }

  List<CatalogAssociation> _curatedAssociations(
    List<CatalogAssociation> associations,
  ) => associations
      .where((association) => association.isCuratedForScoreTotal)
      .toList(growable: false);

  ScoreTotalDimension _curatedDimension({
    required ScoreTotalDimensionKind kind,
    required List<CatalogAssociation> associations,
    required double maxWeight,
    required String version,
  }) {
    final strongest = _strongestAssociation(associations);
    return ScoreTotalDimension(
      kind: kind,
      contribution: _strongestConfidence(associations) * maxWeight,
      maxWeight: maxWeight,
      evidenceLabel: strongest == null
          ? 'sem associação curada suficiente'
          : '${strongest.label} (${strongest.confidence.label})',
      version: version,
      caution:
          strongest?.caution ??
          'Ausência de associação curada suficiente não é tratada como zero comportamental.',
      iri: strongest?.iri,
      scope: strongest?.scope,
    );
  }

  CatalogAssociation? _strongestAssociation(
    List<CatalogAssociation> associations,
  ) {
    if (associations.isEmpty) return null;
    return associations.reduce(
      (current, candidate) =>
          candidate.confidence.weight > current.confidence.weight
          ? candidate
          : current,
    );
  }

  double _strongestConfidence(List<CatalogAssociation> associations) {
    final strongest = _strongestAssociation(associations);
    return strongest?.confidence.weight ?? 0.0;
  }

  double _clamp01(double value) => value.clamp(0.0, 1.0).toDouble();

  ScoreTotalBand _bandFor(double value) {
    if (value < 0.40) return ScoreTotalBand.low;
    if (value < 0.70) return ScoreTotalBand.moderate;
    return ScoreTotalBand.high;
  }
}
