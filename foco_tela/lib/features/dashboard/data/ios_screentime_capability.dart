import 'dart:io' show Platform;
import 'package:flutter/services.dart';

import '../domain/usage_repository.dart'; // ou onde estiver ScreenTimeCapability

class IosScreenTimeCapabilityRepository implements ScreenTimeCapability {
  static const MethodChannel _channel = MethodChannel(
    'com.foco_tela/ios_screentime',
  );

  @override
  Future<bool> isScreenTimeAvailable() async {
    if (!Platform.isIOS) return false;
    final result = await _channel.invokeMethod<bool>('isScreenTimeAvailable');
    return result ?? false;
  }

  @override
  Future<void> openNativeScreenTimeReport() async {
    if (!Platform.isIOS) return;
    await _channel.invokeMethod('openScreenTimeReport');
  }
}
