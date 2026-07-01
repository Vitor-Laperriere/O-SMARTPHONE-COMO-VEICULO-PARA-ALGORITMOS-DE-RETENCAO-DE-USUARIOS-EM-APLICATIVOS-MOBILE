import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foco_tela/features/catalog/data/app_identity_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'decodifica metadados nativos e usa cache com refresh explícito',
    () async {
      final channel = MethodChannel('com.foco_tela/app_identity_test');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var invocationCount = 0;
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
      });
      messenger.setMockMethodCallHandler(channel, (call) async {
        invocationCount += 1;
        expect(call.method, 'getInstalledAppIdentities');
        return {
          'contractVersion': 1,
          'apps': [
            {
              'packageName': 'com.example.video',
              'friendlyName': 'Vídeo Visto',
              'nativeCategoryCode': 7,
              'nativeCategoryLabel': 'Vídeo',
              'iconPngBytes': _transparentPngBytes(),
            },
          ],
        };
      });

      final repository = AndroidAppIdentityRepository(
        channel: channel,
        isAndroid: () => true,
      );

      final first = await repository.resolveMany(['com.example.video']);
      expect(invocationCount, 1);
      expect(first.single.packageName, 'com.example.video');
      expect(first.single.friendlyName, 'Vídeo Visto');
      expect(first.single.hasFriendlyName, isTrue);
      expect(first.single.nativeCategoryLabel, 'Vídeo');
      expect(first.single.hasIcon, isTrue);

      final cached = await repository.resolveMany(['com.example.video']);
      expect(invocationCount, 1);
      expect(cached.single.friendlyName, 'Vídeo Visto');

      final refreshed = await repository.resolveMany([
        'com.example.video',
      ], refresh: true);
      expect(invocationCount, 2);
      expect(refreshed.single.technicalIdentifier, 'com.example.video');
    },
  );

  test(
    'preserva o identificador técnico quando o Android não resolve metadados',
    () async {
      final channel = MethodChannel('com.foco_tela/app_identity_fallback_test');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
      });
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => {
          'contractVersion': 1,
          'apps': [
            {'packageName': 'com.example.unknown'},
          ],
        },
      );

      final repository = AndroidAppIdentityRepository(
        channel: channel,
        isAndroid: () => true,
      );

      final identity = await repository.resolveOne('com.example.unknown');
      expect(identity.packageName, 'com.example.unknown');
      expect(identity.hasFriendlyName, isFalse);
      expect(identity.friendlyName, isNull);
      expect(identity.hasIcon, isFalse);
      expect(identity.nativeCategoryLabel, isNull);
      expect(identity.technicalIdentifier, 'com.example.unknown');
    },
  );
}

Uint8List _transparentPngBytes() => base64Decode(_transparentPngBase64);

const String _transparentPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO2X4WQAAAAASUVORK5CYII=';
