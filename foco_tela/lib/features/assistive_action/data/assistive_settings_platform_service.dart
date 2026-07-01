import 'package:flutter/services.dart';

class AssistiveSettingsPlatformService {
  const AssistiveSettingsPlatformService({required MethodChannel channel})
    : _channel = channel;

  final MethodChannel _channel;

  Future<Object?> openAppUsageSettings(String packageName) {
    return _channel.invokeMethod<Object?>('openAppUsageSettings', {
      'packageName': packageName,
    });
  }
}
