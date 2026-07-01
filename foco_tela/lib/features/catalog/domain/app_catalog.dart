enum CatalogSampleGroup { retentionSocial, mixed, utility }

extension CatalogSampleGroupLabel on CatalogSampleGroup {
  String get label => switch (this) {
    CatalogSampleGroup.retentionSocial => 'retenção/social',
    CatalogSampleGroup.mixed => 'casos mistos',
    CatalogSampleGroup.utility => 'controles utilitários',
  };

  static CatalogSampleGroup fromValue(String value) => switch (value) {
    'retention_social' => CatalogSampleGroup.retentionSocial,
    'mixed' => CatalogSampleGroup.mixed,
    'utility' => CatalogSampleGroup.utility,
    _ => throw FormatException('Grupo de amostra inválido: $value.'),
  };

  String get value => switch (this) {
    CatalogSampleGroup.retentionSocial => 'retention_social',
    CatalogSampleGroup.mixed => 'mixed',
    CatalogSampleGroup.utility => 'utility',
  };
}

CatalogSampleGroup catalogSampleGroupFromValue(String value) => switch (value) {
  'retention_social' => CatalogSampleGroup.retentionSocial,
  'mixed' => CatalogSampleGroup.mixed,
  'utility' => CatalogSampleGroup.utility,
  _ => throw FormatException('Grupo de amostra inválido: $value.'),
};

enum CatalogAssociationKind {
  technicalMechanism,
  osComponent,
  psychologicalTechnique,
  institutionalIntention,
}

extension CatalogAssociationKindLabel on CatalogAssociationKind {
  String get label => switch (this) {
    CatalogAssociationKind.technicalMechanism => 'mecanismo técnico',
    CatalogAssociationKind.osComponent => 'componente do sistema operacional',
    CatalogAssociationKind.psychologicalTechnique => 'técnica psicológica',
    CatalogAssociationKind.institutionalIntention => 'intenção institucional',
  };

  static CatalogAssociationKind fromValue(String value) => switch (value) {
    'technical_mechanism' => CatalogAssociationKind.technicalMechanism,
    'os_component' => CatalogAssociationKind.osComponent,
    'psychological_technique' => CatalogAssociationKind.psychologicalTechnique,
    'institutional_intention' => CatalogAssociationKind.institutionalIntention,
    _ => throw FormatException('Tipo de associação inválido: $value.'),
  };

  String get value => switch (this) {
    CatalogAssociationKind.technicalMechanism => 'technical_mechanism',
    CatalogAssociationKind.osComponent => 'os_component',
    CatalogAssociationKind.psychologicalTechnique => 'psychological_technique',
    CatalogAssociationKind.institutionalIntention => 'institutional_intention',
  };
}

CatalogAssociationKind catalogAssociationKindFromValue(
  String value,
) => switch (value) {
  'technical_mechanism' => CatalogAssociationKind.technicalMechanism,
  'os_component' => CatalogAssociationKind.osComponent,
  'psychological_technique' => CatalogAssociationKind.psychologicalTechnique,
  'institutional_intention' => CatalogAssociationKind.institutionalIntention,
  _ => throw FormatException('Tipo de associação inválido: $value.'),
};

enum CatalogContextualRole { retention, utility, wellbeing, undetermined }

extension CatalogContextualRoleLabel on CatalogContextualRole {
  String get label => switch (this) {
    CatalogContextualRole.retention => 'retenção',
    CatalogContextualRole.utility => 'utilidade',
    CatalogContextualRole.wellbeing => 'bem-estar',
    CatalogContextualRole.undetermined => 'não determinado',
  };

  static CatalogContextualRole fromValue(String value) => switch (value) {
    'retention' => CatalogContextualRole.retention,
    'utility' => CatalogContextualRole.utility,
    'wellbeing' => CatalogContextualRole.wellbeing,
    'undetermined' => CatalogContextualRole.undetermined,
    _ => throw FormatException('Papel contextual inválido: $value.'),
  };

  String get value => switch (this) {
    CatalogContextualRole.retention => 'retention',
    CatalogContextualRole.utility => 'utility',
    CatalogContextualRole.wellbeing => 'wellbeing',
    CatalogContextualRole.undetermined => 'undetermined',
  };
}

CatalogContextualRole catalogContextualRoleFromValue(String value) =>
    switch (value) {
      'retention' => CatalogContextualRole.retention,
      'utility' => CatalogContextualRole.utility,
      'wellbeing' => CatalogContextualRole.wellbeing,
      'undetermined' => CatalogContextualRole.undetermined,
      _ => throw FormatException('Papel contextual inválido: $value.'),
    };

enum CatalogConfidence { low, medium, high, unavailable }

extension CatalogConfidenceLabel on CatalogConfidence {
  String get label => switch (this) {
    CatalogConfidence.low => 'baixa',
    CatalogConfidence.medium => 'média',
    CatalogConfidence.high => 'alta',
    CatalogConfidence.unavailable => 'indisponível',
  };

  double get weight => switch (this) {
    CatalogConfidence.low => 0.1,
    CatalogConfidence.medium => 0.5,
    CatalogConfidence.high => 1.0,
    CatalogConfidence.unavailable => 0.0,
  };

  static CatalogConfidence fromValue(String value) => switch (value) {
    'low' => CatalogConfidence.low,
    'medium' => CatalogConfidence.medium,
    'high' => CatalogConfidence.high,
    'unavailable' => CatalogConfidence.unavailable,
    _ => throw FormatException('Confiança contextual inválida: $value.'),
  };

  String get value => switch (this) {
    CatalogConfidence.low => 'low',
    CatalogConfidence.medium => 'medium',
    CatalogConfidence.high => 'high',
    CatalogConfidence.unavailable => 'unavailable',
  };
}

CatalogConfidence catalogConfidenceFromValue(String value) => switch (value) {
  'low' => CatalogConfidence.low,
  'medium' => CatalogConfidence.medium,
  'high' => CatalogConfidence.high,
  'unavailable' => CatalogConfidence.unavailable,
  _ => throw FormatException('Confiança contextual inválida: $value.'),
};

enum CatalogEvidenceType {
  sampleSelection,
  appStoreListing,
  literatureNote,
  ontologyNote,
  validationNote,
}

extension CatalogEvidenceTypeLabel on CatalogEvidenceType {
  String get label => switch (this) {
    CatalogEvidenceType.sampleSelection => 'seleção da amostra',
    CatalogEvidenceType.appStoreListing => 'listagem da loja',
    CatalogEvidenceType.literatureNote => 'nota bibliográfica',
    CatalogEvidenceType.ontologyNote => 'nota ontológica',
    CatalogEvidenceType.validationNote => 'nota de validação',
  };

  static CatalogEvidenceType fromValue(String value) => switch (value) {
    'sample_selection' => CatalogEvidenceType.sampleSelection,
    'app_store_listing' => CatalogEvidenceType.appStoreListing,
    'literature_note' => CatalogEvidenceType.literatureNote,
    'ontology_note' => CatalogEvidenceType.ontologyNote,
    'validation_note' => CatalogEvidenceType.validationNote,
    _ => throw FormatException('Tipo de evidência inválido: $value.'),
  };

  String get value => switch (this) {
    CatalogEvidenceType.sampleSelection => 'sample_selection',
    CatalogEvidenceType.appStoreListing => 'app_store_listing',
    CatalogEvidenceType.literatureNote => 'literature_note',
    CatalogEvidenceType.ontologyNote => 'ontology_note',
    CatalogEvidenceType.validationNote => 'validation_note',
  };
}

CatalogEvidenceType catalogEvidenceTypeFromValue(String value) =>
    switch (value) {
      'sample_selection' => CatalogEvidenceType.sampleSelection,
      'app_store_listing' => CatalogEvidenceType.appStoreListing,
      'literature_note' => CatalogEvidenceType.literatureNote,
      'ontology_note' => CatalogEvidenceType.ontologyNote,
      'validation_note' => CatalogEvidenceType.validationNote,
      _ => throw FormatException('Tipo de evidência inválido: $value.'),
    };

class CatalogEvidence {
  const CatalogEvidence({
    required this.id,
    required this.type,
    required this.reference,
    required this.date,
    required this.observedVersion,
    required this.supportedStatement,
    required this.scope,
  });

  final String id;
  final CatalogEvidenceType type;
  final String reference;
  final DateTime date;
  final String observedVersion;
  final String supportedStatement;
  final String scope;

  String get dateLabel =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.value,
    'reference': reference,
    'date': dateLabel,
    'observed_version': observedVersion,
    'supported_statement': supportedStatement,
    'scope': scope,
  };

  factory CatalogEvidence.fromMap(Map<Object?, Object?> map) => switch (map) {
    {
      'id': String id,
      'type': String type,
      'reference': String reference,
      'date': String date,
      'observed_version': String observedVersion,
      'supported_statement': String supportedStatement,
      'scope': String scope,
    } =>
      CatalogEvidence(
        id: id,
        type: catalogEvidenceTypeFromValue(type),
        reference: reference,
        date: DateTime.parse(date),
        observedVersion: observedVersion,
        supportedStatement: supportedStatement,
        scope: scope,
      ),
    _ => throw const FormatException('Evidência do catálogo inválida.'),
  };
}

class CatalogAssociation {
  const CatalogAssociation({
    required this.kind,
    required this.iri,
    required this.label,
    required this.contextualRole,
    required this.confidence,
    required this.evidence,
    this.relation,
    this.scope,
    this.caution,
  });

  final CatalogAssociationKind kind;
  final String iri;
  final String label;
  final CatalogContextualRole contextualRole;
  final CatalogConfidence confidence;
  final List<CatalogEvidence> evidence;
  final String? relation;
  final String? scope;
  final String? caution;

  bool get hasTraceableEvidence => evidence.isNotEmpty;

  bool get hasExplicitRelation => relation != null && relation!.isNotEmpty;

  bool get hasScope => scope != null && scope!.isNotEmpty;

  bool get hasCaution => caution != null && caution!.isNotEmpty;

  bool get hasMediumOrHighEvidence =>
      confidence == CatalogConfidence.medium ||
      confidence == CatalogConfidence.high;

  bool get isCuratedForScoreTotal =>
      hasTraceableEvidence &&
      hasMediumOrHighEvidence &&
      contextualRole == CatalogContextualRole.retention &&
      hasExplicitRelation &&
      hasScope &&
      hasCaution;

  Map<String, Object?> toJson() => {
    'kind': kind.value,
    'iri': iri,
    'label': label,
    'contextual_role': contextualRole.value,
    'confidence': confidence.value,
    'evidence_refs': evidence.map((item) => item.id).toList(growable: false),
    if (relation != null) 'relation': relation,
    if (scope != null) 'scope': scope,
    if (caution != null) 'caution': caution,
  };

  factory CatalogAssociation.fromMap({
    required Map<Object?, Object?> map,
    required CatalogAssociationKind kind,
    required Map<String, CatalogEvidence> evidenceById,
  }) {
    final iri = map['iri'];
    final label = map['label'];
    final contextualRole = map['contextual_role'];
    final confidence = map['confidence'];
    final evidenceRefs = map['evidence_refs'];
    if (iri is! String ||
        label is! String ||
        contextualRole is! String ||
        confidence is! String ||
        evidenceRefs is! List<Object?>) {
      throw const FormatException('Associação do catálogo inválida.');
    }
    return CatalogAssociation(
      kind: kind,
      iri: iri,
      label: label,
      contextualRole: catalogContextualRoleFromValue(contextualRole),
      confidence: catalogConfidenceFromValue(confidence),
      evidence: _resolveEvidenceRefs(
        iri: iri,
        evidenceRefs: evidenceRefs,
        evidenceById: evidenceById,
      ),
      relation: map['relation'] as String?,
      scope: map['scope'] as String?,
      caution: map['caution'] as String?,
    );
  }

  factory CatalogAssociation.fromSourceMap({
    required Map<Object?, Object?> map,
    required CatalogAssociationKind kind,
    required Map<String, CatalogEvidence> evidenceById,
  }) {
    final iri = map['iri'];
    final label = map['label'];
    final contextualRole = map['contextual_role'];
    final evidenceRefs = map['evidence_refs'];
    if (iri is! String ||
        label is! String ||
        contextualRole is! String ||
        evidenceRefs is! List<Object?>) {
      throw const FormatException('Associação de origem inválida.');
    }
    final evidence = _resolveEvidenceRefs(
      iri: iri,
      evidenceRefs: evidenceRefs,
      evidenceById: evidenceById,
    );
    return CatalogAssociation(
      kind: kind,
      iri: iri,
      label: label,
      contextualRole: catalogContextualRoleFromValue(contextualRole),
      confidence: _deriveConfidence(evidence),
      evidence: evidence,
      relation: map['relation'] as String?,
      scope: map['scope'] as String?,
      caution: map['caution'] as String?,
    );
  }
}

List<CatalogEvidence> _resolveEvidenceRefs({
  required String iri,
  required List<Object?> evidenceRefs,
  required Map<String, CatalogEvidence> evidenceById,
}) {
  return evidenceRefs
      .map((ref) {
        final evidenceId = ref as String;
        final evidence = evidenceById[evidenceId];
        if (evidence == null) {
          throw FormatException(
            'Evidência ausente para a associação $iri: $evidenceId.',
          );
        }
        return evidence;
      })
      .toList(growable: false);
}

class CatalogConfidenceBand {
  const CatalogConfidenceBand._(this.label);

  static const absent = CatalogConfidenceBand._('ausente');
  static const low = CatalogConfidenceBand._('baixa');
  static const medium = CatalogConfidenceBand._('média');
  static const high = CatalogConfidenceBand._('alta');

  final String label;
}

enum CatalogContextStatus { approved, candidateAutomatic, insufficient }

extension CatalogContextStatusLabel on CatalogContextStatus {
  String get label => switch (this) {
    CatalogContextStatus.approved => 'Tipo aprovado',
    CatalogContextStatus.candidateAutomatic => 'Tipo sugerido',
    CatalogContextStatus.insufficient => 'Tipo não avaliado',
  };

  String get shortLabel => switch (this) {
    CatalogContextStatus.approved => 'aprovado',
    CatalogContextStatus.candidateAutomatic => 'sugerido',
    CatalogContextStatus.insufficient => 'não avaliado',
  };
}

class CatalogContextProfile {
  CatalogContextProfile({
    required this.status,
    required List<CatalogAssociation> approvedAssociations,
    required List<CatalogAssociation> candidateAssociations,
  }) : approvedAssociations = List.unmodifiable(approvedAssociations),
       candidateAssociations = List.unmodifiable(candidateAssociations);

  const CatalogContextProfile.insufficient()
    : status = CatalogContextStatus.insufficient,
      approvedAssociations = const [],
      candidateAssociations = const [];

  final CatalogContextStatus status;
  final List<CatalogAssociation> approvedAssociations;
  final List<CatalogAssociation> candidateAssociations;

  bool get hasApprovedContext => approvedAssociations.isNotEmpty;

  bool get hasCandidateSuggestions => candidateAssociations.isNotEmpty;

  List<String> get approvedLabels =>
      approvedAssociations.map((item) => item.label).toList(growable: false);

  List<String> get candidateLabels =>
      candidateAssociations.map((item) => item.label).toList(growable: false);

  String get summary => switch (status) {
    CatalogContextStatus.approved =>
      'Há tipo de aplicativo aprovado e rastreável para este app.',
    CatalogContextStatus.candidateAutomatic =>
      'Há tipo sugerido por regra local versionada; ele entra na análise com selo próprio.',
    CatalogContextStatus.insufficient =>
      'Ainda não há tipo de aplicativo suficiente para este app.',
  };
}

class CatalogApp {
  CatalogApp({
    required this.packageName,
    required this.displayName,
    required this.sampleGroup,
    required List<CatalogAssociation> technicalMechanisms,
    required List<CatalogAssociation> osComponents,
    List<CatalogAssociation> psychologicalTechniques = const [],
    List<CatalogAssociation> institutionalIntentions = const [],
    this.psychologicalTechnique,
    this.institutionalIntention,
  }) : technicalMechanisms = List.unmodifiable(technicalMechanisms),
       osComponents = List.unmodifiable(osComponents),
       psychologicalTechniques = List.unmodifiable(psychologicalTechniques),
       institutionalIntentions = List.unmodifiable(institutionalIntentions);

  final String packageName;
  final String displayName;
  final CatalogSampleGroup sampleGroup;
  final String? psychologicalTechnique;
  final String? institutionalIntention;
  final List<CatalogAssociation> technicalMechanisms;
  final List<CatalogAssociation> osComponents;
  final List<CatalogAssociation> psychologicalTechniques;
  final List<CatalogAssociation> institutionalIntentions;

  List<CatalogAssociation> get associations => [
    ...technicalMechanisms,
    ...osComponents,
    ...psychologicalTechniques,
    ...institutionalIntentions,
  ];

  CatalogContextProfile get contextProfile {
    final approvedAssociations = associations
        .where(_isApprovedCatalogAssociation)
        .toList(growable: false);
    final candidateAssociations = associations
        .where(_isCandidateCatalogAssociation)
        .toList(growable: false);

    return switch ((
      approvedAssociations.isNotEmpty,
      candidateAssociations.isNotEmpty,
    )) {
      (true, _) => CatalogContextProfile(
        status: CatalogContextStatus.approved,
        approvedAssociations: approvedAssociations,
        candidateAssociations: candidateAssociations,
      ),
      (false, true) => CatalogContextProfile(
        status: CatalogContextStatus.candidateAutomatic,
        approvedAssociations: approvedAssociations,
        candidateAssociations: candidateAssociations,
      ),
      (false, false) => const CatalogContextProfile.insufficient(),
    };
  }

  CatalogContextStatus get contextStatus => contextProfile.status;

  bool get hasApprovedContext => contextProfile.hasApprovedContext;

  bool get hasCandidateContextSuggestions =>
      contextProfile.hasCandidateSuggestions;

  bool get hasCatalogContext => hasApprovedContext;

  double get retentionStrength {
    final countedIris = <String>{};
    var total = 0.0;
    for (final association in associations) {
      if (association.contextualRole != CatalogContextualRole.retention) {
        continue;
      }
      if (!countedIris.add(association.iri)) {
        continue;
      }
      total += association.confidence.weight;
    }
    if (total > 2.0) {
      return 2.0;
    }
    return total;
  }

  CatalogConfidenceBand get retentionStrengthBand =>
      switch (retentionStrength) {
        0 => CatalogConfidenceBand.absent,
        >= 0.1 && < 0.5 => CatalogConfidenceBand.low,
        >= 0.5 && < 1.0 => CatalogConfidenceBand.medium,
        _ => CatalogConfidenceBand.high,
      };

  String get psychologicalTechniqueLabel =>
      psychologicalTechnique ?? 'não determinada';

  String get institutionalIntentionLabel =>
      institutionalIntention ?? 'não determinada';

  Map<String, Object?> toJson() => {
    'package_name': packageName,
    'display_name': displayName,
    'sample_group': sampleGroup.value,
    'psychological_technique': psychologicalTechnique,
    'institutional_intention': institutionalIntention,
    'technical_mechanisms': technicalMechanisms
        .map((item) => item.toJson())
        .toList(growable: false),
    'os_components': osComponents
        .map((item) => item.toJson())
        .toList(growable: false),
    'psychological_techniques': psychologicalTechniques
        .map((item) => item.toJson())
        .toList(growable: false),
    'institutional_intentions': institutionalIntentions
        .map((item) => item.toJson())
        .toList(growable: false),
  };

  factory CatalogApp.fromMap({
    required Map<Object?, Object?> map,
    required Map<String, CatalogEvidence> evidenceById,
  }) => switch (map) {
    {
      'package_name': String packageName,
      'display_name': String displayName,
      'sample_group': String sampleGroup,
      'technical_mechanisms': List<Object?> technicalMechanisms,
      'os_components': List<Object?> osComponents,
    } =>
      CatalogApp(
        packageName: packageName,
        displayName: displayName,
        sampleGroup: catalogSampleGroupFromValue(sampleGroup),
        psychologicalTechnique: map['psychological_technique'] as String?,
        institutionalIntention: map['institutional_intention'] as String?,
        technicalMechanisms: technicalMechanisms
            .map(
              (item) => CatalogAssociation.fromMap(
                map: Map<Object?, Object?>.from(item as Map),
                kind: CatalogAssociationKind.technicalMechanism,
                evidenceById: evidenceById,
              ),
            )
            .toList(growable: false),
        osComponents: osComponents
            .map(
              (item) => CatalogAssociation.fromMap(
                map: Map<Object?, Object?>.from(item as Map),
                kind: CatalogAssociationKind.osComponent,
                evidenceById: evidenceById,
              ),
            )
            .toList(growable: false),
        psychologicalTechniques:
            (map['psychological_techniques'] as List<Object?>? ?? const [])
                .map(
                  (item) => CatalogAssociation.fromMap(
                    map: Map<Object?, Object?>.from(item as Map),
                    kind: CatalogAssociationKind.psychologicalTechnique,
                    evidenceById: evidenceById,
                  ),
                )
                .toList(growable: false),
        institutionalIntentions:
            (map['institutional_intentions'] as List<Object?>? ?? const [])
                .map(
                  (item) => CatalogAssociation.fromMap(
                    map: Map<Object?, Object?>.from(item as Map),
                    kind: CatalogAssociationKind.institutionalIntention,
                    evidenceById: evidenceById,
                  ),
                )
                .toList(growable: false),
      ),
    _ => throw const FormatException('Aplicativo do catálogo inválido.'),
  };

  factory CatalogApp.fromSourceMap({
    required Map<Object?, Object?> map,
    required Map<String, CatalogEvidence> evidenceById,
  }) => switch (map) {
    {
      'package_name': String packageName,
      'display_name': String displayName,
      'sample_group': String sampleGroup,
      'technical_mechanisms': List<Object?> technicalMechanisms,
      'os_components': List<Object?> osComponents,
    } =>
      CatalogApp(
        packageName: packageName,
        displayName: displayName,
        sampleGroup: catalogSampleGroupFromValue(sampleGroup),
        psychologicalTechnique: map['psychological_technique'] as String?,
        institutionalIntention: map['institutional_intention'] as String?,
        technicalMechanisms: technicalMechanisms
            .map(
              (item) => CatalogAssociation.fromSourceMap(
                map: Map<Object?, Object?>.from(item as Map),
                kind: CatalogAssociationKind.technicalMechanism,
                evidenceById: evidenceById,
              ),
            )
            .toList(growable: false),
        osComponents: osComponents
            .map(
              (item) => CatalogAssociation.fromSourceMap(
                map: Map<Object?, Object?>.from(item as Map),
                kind: CatalogAssociationKind.osComponent,
                evidenceById: evidenceById,
              ),
            )
            .toList(growable: false),
        psychologicalTechniques:
            (map['psychological_techniques'] as List<Object?>? ?? const [])
                .map(
                  (item) => CatalogAssociation.fromSourceMap(
                    map: Map<Object?, Object?>.from(item as Map),
                    kind: CatalogAssociationKind.psychologicalTechnique,
                    evidenceById: evidenceById,
                  ),
                )
                .toList(growable: false),
        institutionalIntentions:
            (map['institutional_intentions'] as List<Object?>? ?? const [])
                .map(
                  (item) => CatalogAssociation.fromSourceMap(
                    map: Map<Object?, Object?>.from(item as Map),
                    kind: CatalogAssociationKind.institutionalIntention,
                    evidenceById: evidenceById,
                  ),
                )
                .toList(growable: false),
      ),
    _ => throw const FormatException('Aplicativo de origem inválido.'),
  };
}

bool _isApprovedCatalogAssociation(CatalogAssociation association) =>
    association.hasTraceableEvidence &&
    association.contextualRole != CatalogContextualRole.undetermined;

bool _isCandidateCatalogAssociation(CatalogAssociation association) =>
    association.hasTraceableEvidence &&
    association.contextualRole == CatalogContextualRole.undetermined;

class CatalogHeader {
  const CatalogHeader({
    required this.version,
    required this.owxIri,
    required this.owxVersion,
    required this.owxCommit,
    required this.owxHash,
  });

  final String version;
  final String owxIri;
  final String owxVersion;
  final String owxCommit;
  final String owxHash;

  Map<String, Object?> toJson() => {
    'version': version,
    'owx_iri': owxIri,
    'owx_version': owxVersion,
    'owx_commit': owxCommit,
    'owx_hash': owxHash,
  };

  factory CatalogHeader.fromRuntimeMap(Map<Object?, Object?> map) =>
      switch (map) {
        {
          'version': String version,
          'owx_iri': String owxIri,
          'owx_version': String owxVersion,
          'owx_commit': String owxCommit,
          'owx_hash': String owxHash,
        } =>
          CatalogHeader(
            version: version,
            owxIri: owxIri,
            owxVersion: owxVersion,
            owxCommit: owxCommit,
            owxHash: owxHash,
          ),
        _ => throw const FormatException('Cabeçalho do catálogo inválido.'),
      };

  factory CatalogHeader.fromSourceMap({
    required Map<Object?, Object?> map,
    required String owxCommit,
    required String owxHash,
  }) => switch (map) {
    {
      'version': String version,
      'owx_iri': String owxIri,
      'owx_version': String owxVersion,
    } =>
      CatalogHeader(
        version: version,
        owxIri: owxIri,
        owxVersion: owxVersion,
        owxCommit: owxCommit,
        owxHash: owxHash,
      ),
    _ => throw const FormatException(
      'Cabeçalho de origem do catálogo inválido.',
    ),
  };
}

class CatalogSnapshot {
  CatalogSnapshot({
    required this.header,
    required List<CatalogApp> apps,
    required List<CatalogEvidence> evidence,
  }) : apps = List.unmodifiable(apps),
       evidence = List.unmodifiable(evidence),
       appsByPackageName = {for (final app in apps) app.packageName: app},
       evidenceById = {for (final item in evidence) item.id: item};

  final CatalogHeader header;
  final List<CatalogApp> apps;
  final List<CatalogEvidence> evidence;
  final Map<String, CatalogApp> appsByPackageName;
  final Map<String, CatalogEvidence> evidenceById;

  CatalogApp? appForPackageName(String packageName) =>
      appsByPackageName[packageName];

  Map<String, Object?> toJson() => {
    'header': header.toJson(),
    'apps': apps.map((item) => item.toJson()).toList(growable: false),
    'evidence': evidence.map((item) => item.toJson()).toList(growable: false),
  };

  factory CatalogSnapshot.fromJson(Map<Object?, Object?> map) => switch (map) {
    {
      'header': Map<Object?, Object?> headerMap,
      'apps': List<Object?> appsList,
      'evidence': List<Object?> evidenceList,
    } =>
      _catalogSnapshotFromParts(
        header: CatalogHeader.fromRuntimeMap(headerMap),
        appsList: appsList,
        evidenceList: evidenceList,
      ),
    _ => throw const FormatException('Catálogo runtime inválido.'),
  };

  factory CatalogSnapshot.fromSourceMap({
    required Map<Object?, Object?> map,
    required String owxCommit,
    required String owxHash,
  }) {
    switch (map) {
      case {
        'catalog': Map<Object?, Object?> headerMap,
        'apps': List<Object?> appsList,
        'evidence': List<Object?> evidenceList,
      }:
        return _catalogSnapshotFromSourceParts(
          header: CatalogHeader.fromSourceMap(
            map: headerMap,
            owxCommit: owxCommit,
            owxHash: owxHash,
          ),
          appsList: appsList,
          evidenceList: evidenceList,
        );
      default:
        throw const FormatException('Catálogo de origem inválido.');
    }
  }
}

CatalogSnapshot _catalogSnapshotFromParts({
  required CatalogHeader header,
  required List<Object?> appsList,
  required List<Object?> evidenceList,
}) {
  final evidence = evidenceList
      .map(
        (item) =>
            CatalogEvidence.fromMap(Map<Object?, Object?>.from(item as Map)),
      )
      .toList(growable: false);
  final evidenceById = {for (final item in evidence) item.id: item};
  final apps = appsList
      .map(
        (item) => CatalogApp.fromMap(
          map: Map<Object?, Object?>.from(item as Map),
          evidenceById: evidenceById,
        ),
      )
      .toList(growable: false);
  return CatalogSnapshot(header: header, apps: apps, evidence: evidence);
}

CatalogSnapshot _catalogSnapshotFromSourceParts({
  required CatalogHeader header,
  required List<Object?> appsList,
  required List<Object?> evidenceList,
}) {
  final evidence = evidenceList
      .map(
        (item) =>
            CatalogEvidence.fromMap(Map<Object?, Object?>.from(item as Map)),
      )
      .toList(growable: false);
  final evidenceById = {for (final item in evidence) item.id: item};
  final apps = appsList
      .map(
        (item) => CatalogApp.fromSourceMap(
          map: Map<Object?, Object?>.from(item as Map),
          evidenceById: evidenceById,
        ),
      )
      .toList(growable: false);
  return CatalogSnapshot(header: header, apps: apps, evidence: evidence);
}

CatalogConfidence _deriveConfidence(List<CatalogEvidence> evidence) {
  if (evidence.isEmpty) {
    return CatalogConfidence.unavailable;
  }

  final hasSpecificEvidence = evidence.any((item) {
    final scope = item.scope.toLowerCase();
    return item.type == CatalogEvidenceType.appStoreListing ||
        scope.startsWith('app_') ||
        scope.contains('specific');
  });

  if (hasSpecificEvidence) {
    return CatalogConfidence.medium;
  }

  final hasLiterature = evidence.any(
    (item) => item.type == CatalogEvidenceType.literatureNote,
  );
  if (hasLiterature) {
    return CatalogConfidence.low;
  }

  return evidence.length > 1 ? CatalogConfidence.medium : CatalogConfidence.low;
}
