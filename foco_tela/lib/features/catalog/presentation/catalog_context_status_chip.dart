import 'package:flutter/material.dart';

import '../domain/app_catalog.dart';

class CatalogContextStatusChip extends StatelessWidget {
  const CatalogContextStatusChip({
    super.key,
    required this.status,
    this.compact = false,
  });

  final CatalogContextStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = switch (status) {
      CatalogContextStatus.approved => (
        background: theme.colorScheme.primaryContainer,
        foreground: theme.colorScheme.onPrimaryContainer,
        icon: Icons.verified_outlined,
      ),
      CatalogContextStatus.candidateAutomatic => (
        background: theme.colorScheme.tertiaryContainer,
        foreground: theme.colorScheme.onTertiaryContainer,
        icon: Icons.auto_awesome_outlined,
      ),
      CatalogContextStatus.insufficient => (
        background: theme.colorScheme.surfaceContainerHighest,
        foreground: theme.colorScheme.onSurfaceVariant,
        icon: Icons.search_off_outlined,
      ),
    };

    return Chip(
      key: ValueKey('catalog-context-status-${status.name}'),
      avatar: Icon(
        palette.icon,
        size: compact ? 16 : 18,
        color: palette.foreground,
      ),
      label: Text(status.label),
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        color: palette.foreground,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: palette.background,
      side: BorderSide.none,
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
    );
  }
}
