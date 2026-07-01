import 'coverage_status.dart';

class ScientificTraceability {
  const ScientificTraceability({
    required this.metric,
    required this.value,
    required this.unit,
    required this.period,
    required this.coverageStatus,
    required this.signalOrState,
    required this.thresholdOrWeight,
    required this.configurationVersion,
    required this.catalogVersion,
    required this.owlIri,
    required this.caution,
  });

  final String metric;
  final String value;
  final String unit;
  final String period;
  final CoverageStatus coverageStatus;
  final String signalOrState;
  final String thresholdOrWeight;
  final String configurationVersion;
  final String catalogVersion;
  final String owlIri;
  final String caution;

  bool get isComplete =>
      metric.isNotEmpty &&
      value.isNotEmpty &&
      unit.isNotEmpty &&
      period.isNotEmpty &&
      signalOrState.isNotEmpty &&
      thresholdOrWeight.isNotEmpty &&
      configurationVersion.isNotEmpty &&
      catalogVersion.isNotEmpty &&
      owlIri.isNotEmpty &&
      caution.isNotEmpty;
}
