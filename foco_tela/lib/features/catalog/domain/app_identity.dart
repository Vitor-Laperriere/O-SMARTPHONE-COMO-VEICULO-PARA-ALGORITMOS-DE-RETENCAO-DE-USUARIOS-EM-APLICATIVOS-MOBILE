import 'dart:typed_data';

class AppIdentity {
  const AppIdentity({
    required this.packageName,
    this.friendlyName,
    this.nativeCategoryCode,
    this.nativeCategoryLabel,
    this.iconPngBytes,
  });

  final String packageName;
  final String? friendlyName;
  final int? nativeCategoryCode;
  final String? nativeCategoryLabel;
  final Uint8List? iconPngBytes;

  bool get hasFriendlyName =>
      friendlyName != null && friendlyName!.trim().isNotEmpty;

  bool get hasIcon => iconPngBytes != null && iconPngBytes!.isNotEmpty;

  String get technicalIdentifier => packageName;

  factory AppIdentity.fromContract(Map<Object?, Object?> raw) => switch (raw) {
    {'packageName': String packageName} => AppIdentity(
      packageName: packageName,
      friendlyName: raw['friendlyName'] as String?,
      nativeCategoryCode: raw['nativeCategoryCode'] as int?,
      nativeCategoryLabel: raw['nativeCategoryLabel'] as String?,
      iconPngBytes: raw['iconPngBytes'] as Uint8List?,
    ),
    _ => throw const FormatException('Identidade de app inválida.'),
  };
}
