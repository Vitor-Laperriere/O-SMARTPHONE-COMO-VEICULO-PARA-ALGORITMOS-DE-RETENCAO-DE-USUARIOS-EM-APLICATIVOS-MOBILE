enum CoverageStatus { sufficient, partial, unavailable }

extension CoverageStatusLabel on CoverageStatus {
  String get label => switch (this) {
    CoverageStatus.sufficient => 'Cobertura suficiente',
    CoverageStatus.partial => 'Cobertura parcial',
    CoverageStatus.unavailable => 'Cobertura indisponível',
  };

  String get shortLabel => switch (this) {
    CoverageStatus.sufficient => 'Completa',
    CoverageStatus.partial => 'Parcial',
    CoverageStatus.unavailable => 'Indisponível',
  };

  bool get isAvailable => this != CoverageStatus.unavailable;
}
