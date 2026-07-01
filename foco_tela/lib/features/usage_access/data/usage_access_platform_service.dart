import 'package:flutter/services.dart';

class UsageAccessPlatformService {
  const UsageAccessPlatformService({required MethodChannel channel})
    : _channel = channel;

  final MethodChannel _channel;

  Future<Object?> getUsageAccessState() {
    return _channel.invokeMethod<Object?>('getUsageAccessState');
  }

  Future<Object?> openUsageAccessSettings() {
    return _channel.invokeMethod<Object?>('openUsageAccessSettings');
  }
}
