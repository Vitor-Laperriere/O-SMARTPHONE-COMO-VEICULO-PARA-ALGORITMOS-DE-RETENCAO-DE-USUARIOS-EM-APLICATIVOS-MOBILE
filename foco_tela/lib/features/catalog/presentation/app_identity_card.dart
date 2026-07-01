import 'package:flutter/material.dart';

import '../domain/app_identity.dart';
import '../domain/app_catalog.dart';
import 'catalog_context_status_chip.dart';

class AppIdentityCard extends StatelessWidget {
  const AppIdentityCard({super.key, required this.app, required this.identity});

  final CatalogApp app;
  final AppIdentity identity;

  @override
  Widget build(BuildContext context) {
    final resolvedName = _resolvedDisplayName();
    final categoryLabel = identity.nativeCategoryLabel?.trim();
    final subtitleText = switch (categoryLabel) {
      final String label when label.isNotEmpty => 'Categoria nativa: $label',
      _ => 'Grupo da amostra: ${app.sampleGroup.label}',
    };

    return Card(
      key: ValueKey('catalog-app-card-${app.packageName}'),
      child: ExpansionTile(
        key: ValueKey('catalog-app-${app.packageName}'),
        leading: _AppIdentityAvatar(
          packageName: app.packageName,
          displayName: resolvedName,
          identity: identity,
        ),
        title: Text(
          resolvedName,
          key: ValueKey('catalog-app-title-${app.packageName}'),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitleText),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                CatalogContextStatusChip(
                  status: app.contextStatus,
                  compact: true,
                ),
              ],
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          _DetailLine(
            label: 'Status de catalogação',
            value: app.contextStatus.label,
          ),
          _DetailLine(
            label: 'Identificador técnico',
            value: identity.technicalIdentifier,
          ),
          _DetailLine(
            label: 'Nome amigável do Android',
            value: switch (identity.friendlyName?.trim()) {
              final String label when label.isNotEmpty => label,
              _ => 'indisponível',
            },
          ),
          _DetailLine(
            label: 'Categoria nativa Android',
            value: identity.nativeCategoryLabel ?? 'indisponível',
          ),
          _DetailLine(label: 'Grupo do catálogo', value: app.sampleGroup.label),
          _DetailLine(
            label: 'Técnica psicológica',
            value: app.psychologicalTechniqueLabel,
          ),
          _DetailLine(
            label: 'Intenção institucional',
            value: app.institutionalIntentionLabel,
          ),
          _DetailLine(
            label: 'Força contextual',
            value: app.retentionStrengthBand.label,
          ),
          if (app.hasCandidateContextSuggestions) ...[
            _DetailLine(
              label: 'Tipo sugerido',
              value: app.contextProfile.candidateLabels.join(' · '),
            ),
          ],
        ],
      ),
    );
  }

  String _resolvedDisplayName() {
    final friendlyName = identity.friendlyName?.trim();
    if (friendlyName != null && friendlyName.isNotEmpty) {
      return friendlyName;
    }
    if (app.displayName.trim().isNotEmpty) {
      return app.displayName;
    }
    return identity.packageName;
  }
}

class _AppIdentityAvatar extends StatelessWidget {
  const _AppIdentityAvatar({
    required this.packageName,
    required this.displayName,
    required this.identity,
  });

  final String packageName;
  final String displayName;
  final AppIdentity identity;

  @override
  Widget build(BuildContext context) {
    if (identity.hasIcon) {
      return ClipRRect(
        key: ValueKey('catalog-app-icon-$packageName'),
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          identity.iconPngBytes!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
        ),
      );
    }

    return CircleAvatar(
      key: ValueKey('catalog-app-icon-$packageName'),
      radius: 20,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      child: Text(_initials(displayName)),
    );
  }

  static String _initials(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '?';
    }
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 168,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
