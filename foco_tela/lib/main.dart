import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/assistive_action/data/android_assistive_settings_repository.dart';
import 'features/assistive_action/domain/assistive_settings.dart';
import 'features/catalog/data/app_catalog_repository.dart';
import 'features/catalog/data/app_identity_repository.dart';
import 'features/dashboard/data/in_memory_derived_analysis_repository.dart';
import 'features/dashboard/data/sqflite_derived_analysis_repository.dart';
import 'features/dashboard/domain/derived_analysis_repository.dart';
import 'features/dashboard/presentation/dashboard_view_model.dart';
import 'features/dashboard/data/android_usage_repository.dart';
import 'features/dashboard/domain/usage_repository.dart';
import 'features/dashboard/data/ios_screentime_capability.dart';
import 'features/notifications/data/android_notification_repository.dart';
import 'features/notifications/domain/notification_observation.dart';
import 'features/usage_access/data/android_usage_access_repository.dart';
import 'features/usage_access/domain/usage_access.dart';
import 'features/navigation/presentation/foco_tela_shell.dart';

void main() => runApp(const FocoTelaApp());

UsageRepository _createUsageRepository() {
  if (Platform.isAndroid) {
    return AndroidUsageRepository();
  }
  return UnsupportedUsageRepository();
}

UsageAccessRepository _createUsageAccessRepository() {
  if (Platform.isAndroid) {
    return AndroidUsageAccessRepository();
  }
  return const UnsupportedUsageAccessRepository();
}

ScreenTimeCapability? _createScreenTimeCapability() {
  if (Platform.isIOS) {
    return IosScreenTimeCapabilityRepository();
  }
  return null;
}

AssistiveSettingsRepository _createAssistiveSettingsRepository() {
  if (Platform.isAndroid) {
    return AndroidAssistiveSettingsRepository();
  }
  return const UnsupportedAssistiveSettingsRepository();
}

NotificationRepository _createNotificationRepository() {
  if (Platform.isAndroid) {
    return AndroidNotificationRepository();
  }
  return const UnsupportedNotificationRepository();
}

DerivedAnalysisRepository _createDerivedAnalysisRepository() {
  if (Platform.isAndroid) {
    return SqfliteDerivedAnalysisRepository();
  }
  return InMemoryDerivedAnalysisRepository();
}

class FocoTelaApp extends StatelessWidget {
  const FocoTelaApp({
    super.key,
    this.usageRepository,
    this.usageAccessRepository,
    this.catalogRepository,
    this.appIdentityRepository,
    this.derivedAnalysisRepository,
    this.assistiveSettingsRepository,
    this.notificationRepository,
    this.screenTimeCapability,
    this.now,
  });

  final UsageRepository? usageRepository;
  final UsageAccessRepository? usageAccessRepository;
  final AppCatalogRepository? catalogRepository;
  final AppIdentityRepository? appIdentityRepository;
  final DerivedAnalysisRepository? derivedAnalysisRepository;
  final AssistiveSettingsRepository? assistiveSettingsRepository;
  final NotificationRepository? notificationRepository;
  final ScreenTimeCapability? screenTimeCapability;
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) {
    final effectiveCatalogRepository =
        catalogRepository ?? AssetAppCatalogRepository();
    final effectiveIdentityRepository =
        appIdentityRepository ?? _createAppIdentityRepository();
    final effectiveDerivedRepository =
        derivedAnalysisRepository ?? _createDerivedAnalysisRepository();
    final effectiveUsageAccessRepository =
        usageAccessRepository ?? _createUsageAccessRepository();
    return MultiProvider(
      providers: [
        Provider<UsageAccessRepository>.value(
          value: effectiveUsageAccessRepository,
        ),
        ChangeNotifierProvider(
          create: (_) => DashboardViewModel(
            usageRepository: usageRepository ?? _createUsageRepository(),
            usageAccessRepository: effectiveUsageAccessRepository,
            catalogRepository: effectiveCatalogRepository,
            derivedRepository: effectiveDerivedRepository,
            notificationRepository:
                notificationRepository ?? _createNotificationRepository(),
            screenTimeCapability:
                screenTimeCapability ?? _createScreenTimeCapability(),
            now: now,
          ),
        ),
        Provider<AppCatalogRepository>(
          create: (_) => effectiveCatalogRepository,
        ),
        Provider<AppIdentityRepository>(
          create: (_) => effectiveIdentityRepository,
        ),
        Provider<DerivedAnalysisRepository>(
          create: (_) => effectiveDerivedRepository,
          dispose: (_, repository) => repository.close(),
        ),
        Provider<AssistiveSettingsRepository>(
          create: (_) =>
              assistiveSettingsRepository ??
              _createAssistiveSettingsRepository(),
        ),
        Provider<NotificationRepository>(
          create: (_) =>
              notificationRepository ?? _createNotificationRepository(),
        ),
      ],
      child: MaterialApp(
        title: 'Foco Tela',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F51B5)),
          useMaterial3: true,
        ),
        home: FocoTelaShell(now: now),
      ),
    );
  }
}

AppIdentityRepository _createAppIdentityRepository() {
  if (Platform.isAndroid) {
    return AndroidAppIdentityRepository();
  }
  return const UnsupportedAppIdentityRepository();
}
