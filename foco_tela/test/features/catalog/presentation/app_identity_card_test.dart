import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foco_tela/features/catalog/domain/app_catalog.dart';
import 'package:foco_tela/features/catalog/domain/app_identity.dart';
import 'package:foco_tela/features/catalog/presentation/app_identity_card.dart';

void main() {
  testWidgets(
    'mostra nome amigável e ícone e esconde packageName até expandir',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppIdentityCard(
              app: _catalogApp(),
              identity: AppIdentity(
                packageName: 'com.example.video',
                friendlyName: 'Vídeo Visto',
                nativeCategoryLabel: 'Vídeo',
                iconPngBytes: _transparentPngBytes(),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Vídeo Visto'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('catalog-context-status-insufficient')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('catalog-app-icon-com.example.video')),
        findsOneWidget,
      );
      expect(find.text('com.example.video'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('catalog-app-com.example.video')),
      );
      await tester.pumpAndSettle();

      expect(find.text('com.example.video'), findsOneWidget);
      expect(find.text('Categoria nativa Android'), findsOneWidget);
      expect(find.text('Vídeo'), findsWidgets);
    },
  );

  testWidgets(
    'cai para o nome do catálogo quando o Android não fornece metadados',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppIdentityCard(
              app: _catalogApp(),
              identity: const AppIdentity(packageName: 'com.example.video'),
            ),
          ),
        ),
      );

      expect(find.text('App Teste'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('catalog-context-status-insufficient')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('catalog-app-icon-com.example.video')),
        findsOneWidget,
      );
      expect(find.text('com.example.video'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('catalog-app-com.example.video')),
      );
      await tester.pumpAndSettle();

      expect(find.text('com.example.video'), findsOneWidget);
      expect(find.text('indisponível'), findsWidgets);
    },
  );

  testWidgets('mostra contexto aprovado no cartão', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppIdentityCard(
            app: _approvedCatalogApp(),
            identity: const AppIdentity(
              packageName: 'com.example.video',
              nativeCategoryLabel: 'Vídeo',
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('catalog-context-status-approved')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('catalog-app-com.example.video')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Status de catalogação'), findsOneWidget);
  });

  testWidgets(
    'mostra sugestão automática sem promover para contexto aprovado',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppIdentityCard(
              app: _candidateCatalogApp(),
              identity: const AppIdentity(
                packageName: 'com.lemon.lvoverseas',
                nativeCategoryLabel: 'Vídeo',
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('catalog-context-status-candidateAutomatic')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('catalog-app-com.lemon.lvoverseas')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tipo sugerido'), findsWidgets);
      expect(find.text('SocialValidation'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('catalog-context-status-approved')),
        findsNothing,
      );
    },
  );
}

CatalogApp _catalogApp() => CatalogApp(
  packageName: 'com.example.video',
  displayName: 'App Teste',
  sampleGroup: CatalogSampleGroup.retentionSocial,
  technicalMechanisms: [],
  osComponents: [],
);

CatalogApp _approvedCatalogApp() => CatalogApp(
  packageName: 'com.example.video',
  displayName: 'App Teste',
  sampleGroup: CatalogSampleGroup.retentionSocial,
  technicalMechanisms: [
    CatalogAssociation(
      kind: CatalogAssociationKind.technicalMechanism,
      iri: 'SocialValidation',
      label: 'SocialValidation',
      contextualRole: CatalogContextualRole.retention,
      confidence: CatalogConfidence.medium,
      evidence: [
        CatalogEvidence(
          id: 'evidence-social-validation',
          type: CatalogEvidenceType.appStoreListing,
          reference: 'https://example.test/social-validation',
          date: DateTime(2026, 6, 21),
          observedVersion: '2026-06-21',
          supportedStatement: 'Evidência específica para SocialValidation.',
          scope: 'app_specific',
        ),
      ],
    ),
  ],
  osComponents: [],
);

CatalogApp _candidateCatalogApp() => CatalogApp(
  packageName: 'com.lemon.lvoverseas',
  displayName: 'CapCut',
  sampleGroup: CatalogSampleGroup.mixed,
  technicalMechanisms: [
    CatalogAssociation(
      kind: CatalogAssociationKind.technicalMechanism,
      iri: 'SocialValidation',
      label: 'SocialValidation',
      contextualRole: CatalogContextualRole.undetermined,
      confidence: CatalogConfidence.medium,
      evidence: [
        CatalogEvidence(
          id: 'evidence-social-validation-candidate',
          type: CatalogEvidenceType.appStoreListing,
          reference: 'https://example.test/social-validation-candidate',
          date: DateTime(2026, 6, 21),
          observedVersion: '2026-06-21',
          supportedStatement: 'Evidência específica para SocialValidation.',
          scope: 'app_specific',
        ),
      ],
    ),
  ],
  osComponents: [],
);

Uint8List _transparentPngBytes() => base64Decode(_transparentPngBase64);

const String _transparentPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO2X4WQAAAAASUVORK5CYII=';
