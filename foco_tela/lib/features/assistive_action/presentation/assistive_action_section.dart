import 'package:flutter/material.dart';

import '../domain/assistive_settings.dart';
import 'assistive_action_view_model.dart';

class AssistiveActionSection extends StatefulWidget {
  const AssistiveActionSection({
    super.key,
    required this.packageName,
    required this.repository,
  });

  final String packageName;
  final AssistiveSettingsRepository repository;

  @override
  State<AssistiveActionSection> createState() => _AssistiveActionSectionState();
}

class _AssistiveActionSectionState extends State<AssistiveActionSection> {
  late final AssistiveActionViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = AssistiveActionViewModel(
      repository: widget.repository,
      packageName: widget.packageName,
    );
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _confirmAndOpen() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revisar configurações deste aplicativo?'),
        content: const Text(
          'O Foco Tela apenas abrirá a configuração nativa. Nenhum limite, '
          'bloqueio, notificação ou permissão será alterado automaticamente.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('assistive-action-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('assistive-action-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _viewModel.openSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final state = _viewModel.state;
        return Container(
          key: const ValueKey('self-regulation-alert'),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SelfRegulationAlert', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(
                'Os sinais observados e o contexto catalogado convergem. '
                'Se fizer sentido para você, revise as opções oferecidas pelo '
                'Android para este aplicativo.',
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  key: const ValueKey('assistive-action-open-settings'),
                  onPressed: state is AssistiveActionOpening
                      ? null
                      : _confirmAndOpen,
                  icon: state is AssistiveActionOpening
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.settings_outlined),
                  label: const Text('Revisar configurações deste aplicativo'),
                ),
              ),
              if (state case AssistiveActionOpened(:final destination)) ...[
                const SizedBox(height: 8),
                Text(switch (destination) {
                  AssistiveSettingsDestination.appUsageSettings =>
                    'Configurações de uso abertas. A análise permanece inalterada.',
                  AssistiveSettingsDestination.applicationDetails =>
                    'Detalhes do aplicativo abertos como alternativa. A análise permanece inalterada.',
                }, style: theme.textTheme.bodySmall),
              ],
              if (state case AssistiveActionOpenError(:final message)) ...[
                const SizedBox(height: 8),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
