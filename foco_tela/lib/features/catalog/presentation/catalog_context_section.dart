import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../dashboard/domain/smartphone_usage_episode.dart';
import '../data/app_catalog_repository.dart';
import '../domain/app_catalog.dart';
import 'catalog_context_status_chip.dart';

class CatalogContextSection extends StatefulWidget {
  const CatalogContextSection({super.key, required this.episode});

  final SmartphoneUsageEpisode episode;

  @override
  State<CatalogContextSection> createState() => _CatalogContextSectionState();
}

class _CatalogContextSectionState extends State<CatalogContextSection> {
  late final Future<CatalogApp?> _catalogFuture;

  @override
  void initState() {
    super.initState();
    _catalogFuture = context.read<AppCatalogRepository>().findByPackageName(
      widget.episode.packageName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<CatalogApp?>(
      future: _catalogFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    Icons.hourglass_empty,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Carregando contexto do aplicativo…',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return _UnavailableContextCard(
            message:
                'Não foi possível carregar o catálogo local deste aplicativo.',
          );
        }

        final app = snapshot.data;
        if (app == null) {
          return const _UnavailableContextCard(
            message:
                'Este aplicativo não está catalogado. A análise mantém '
                'episódios e métricas, mas o contexto do app fica indisponível.',
          );
        }

        return _CatalogContextCard(app: app);
      },
    );
  }
}

class _CatalogContextCard extends StatelessWidget {
  const _CatalogContextCard({required this.app});

  final CatalogApp app;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = app.contextProfile;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contexto do aplicativo',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [CatalogContextStatusChip(status: profile.status)],
            ),
            const SizedBox(height: 8),
            Text(profile.summary, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Text(
              '${app.displayName} · ${app.sampleGroup.label}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _CatalogDetailRow(label: 'Aplicativo', value: app.displayName),
            _CatalogDetailRow(label: 'Pacote', value: app.packageName),
            _CatalogDetailRow(label: 'Grupo', value: app.sampleGroup.label),
            _CatalogDetailRow(
              label: 'Técnica psicológica',
              value: app.psychologicalTechniqueLabel,
            ),
            _CatalogDetailRow(
              label: 'Intenção institucional',
              value: app.institutionalIntentionLabel,
            ),
            if (profile.hasApprovedContext) ...[
              _CatalogDetailRow(
                label: 'Força contextual',
                value:
                    '${app.retentionStrength.toStringAsFixed(1)} '
                    '(${app.retentionStrengthBand.label})',
              ),
            ] else ...[
              _CatalogDetailRow(
                label: 'Força contextual',
                value: 'Sem tipo aprovado no catálogo',
              ),
            ],
            const SizedBox(height: 8),
            if (profile.approvedAssociations.isNotEmpty) ...[
              Text('Associações aprovadas', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final association in profile.approvedAssociations) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AssociationCard(association: association),
                ),
              ],
            ],
            if (profile.candidateAssociations.isNotEmpty) ...[
              Text('Mecanismos sugeridos', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final association in profile.candidateAssociations) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SuggestionCard(association: association),
                ),
              ],
            ],
            if (!profile.hasApprovedContext && !profile.hasCandidateSuggestions)
              const Text('Nenhuma associação foi cadastrada para este app.'),
          ],
        ),
      ),
    );
  }
}

class _AssociationCard extends StatelessWidget {
  const _AssociationCard({required this.association});

  final CatalogAssociation association;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(association.label, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              '${association.kind.label} · papel ${association.contextualRole.label} · '
              'confiança ${association.confidence.label}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text('IRI: ${association.iri}', style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Text('Evidências', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final evidence in association.evidence) ...[
              _EvidenceTile(evidence: evidence),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.association});

  final CatalogAssociation association;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(association.label, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              '${association.kind.label} · sugestão automática · '
              'confiança ${association.confidence.label}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text('IRI: ${association.iri}', style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Text('Evidências de apoio', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final evidence in association.evidence) ...[
              _EvidenceTile(evidence: evidence),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile({required this.evidence});

  final CatalogEvidence evidence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${evidence.type.label} · ${evidence.dateLabel}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text('Referência: ${evidence.reference}'),
          const SizedBox(height: 4),
          Text('Versão observada: ${evidence.observedVersion}'),
          const SizedBox(height: 4),
          Text('Escopo: ${evidence.scope}'),
          const SizedBox(height: 4),
          Text(evidence.supportedStatement),
        ],
      ),
    );
  }
}

class _CatalogDetailRow extends StatelessWidget {
  const _CatalogDetailRow({required this.label, required this.value});

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
            width: 136,
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

class _UnavailableContextCard extends StatelessWidget {
  const _UnavailableContextCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contexto do aplicativo',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const CatalogContextStatusChip(
              status: CatalogContextStatus.insufficient,
            ),
            const SizedBox(height: 8),
            Text('Contexto indisponível', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message),
          ],
        ),
      ),
    );
  }
}
