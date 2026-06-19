import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../domain/entities/session_state.dart';
import '../../../providers/terminal_provider.dart';

class CommandInput extends ConsumerStatefulWidget {
  const CommandInput({super.key});

  @override
  ConsumerState<CommandInput> createState() => _CommandInputState();
}

class _CommandInputState extends ConsumerState<CommandInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<String> _history = [];

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _history.insert(0, text);
    _controller.clear();

    ref.read(terminalProvider.notifier).sendCommand(text);
  }

  @override
  Widget build(BuildContext context) {
    final terminalState = ref.watch(terminalProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isConnected = terminalState.sessionState.status.isConnected;
    final isSending = terminalState.isSending;
    final isInteractive = terminalState.isInteractive;
    final canSend = isConnected && !isSending;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Interactive controls
          if (isInteractive) _InteractiveControlBar(isEnabled: isConnected),

          Row(
            children: [
              // Prompt indicator
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  isInteractive ? '↩' : '\$',
                  style: AppTextStyles.monoBold.copyWith(
                    color: isInteractive
                        ? colorScheme.secondary
                        : colorScheme.primary,
                    fontSize: 14,
                  ),
                ),
              ),

              // Input field
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: canSend,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: AppTextStyles.monoMedium.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: isInteractive
                        ? 'Escribir en proceso...'
                        : (isConnected
                            ? 'Escribe un comando...'
                            : 'Sin conexión...'),
                    hintStyle: AppTextStyles.monoSmall.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.3),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    filled: false,
                  ),
                  onSubmitted: (_) => _submit(),
                  textInputAction: TextInputAction.send,
                ),
              ),

              const SizedBox(width: 8),

              // Send button
              SizedBox(
                width: 40,
                height: 40,
                child: isSending
                    ? Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primary,
                          ),
                        ),
                      )
                    : IconButton(
                        onPressed: canSend ? _submit : null,
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.send_rounded,
                          size: 20,
                          color: canSend
                              ? colorScheme.primary
                              : colorScheme.onSurface.withOpacity(0.25),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InteractiveControlBar extends ConsumerWidget {
  final bool isEnabled;

  const _InteractiveControlBar({required this.isEnabled});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final notifier = ref.read(terminalProvider.notifier);
    final processName =
        ref.watch(terminalProvider).interactiveProcessName ?? '';

    final signals = [
      ('⌃C', 'ctrlc', 'Interrumpir'),
      ('⌃D', 'ctrld', 'EOF'),
      ('↵', 'enter', 'Enter'),
      ('Esc', 'esc', 'Escape'),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colorScheme.secondary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              processName.isNotEmpty ? processName : 'interactive',
              style: AppTextStyles.monoTiny.copyWith(
                color: colorScheme.secondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ...signals.map(
            (s) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: InkWell(
                onTap: isEnabled ? () => notifier.sendSignal(s.$2) : null,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colorScheme.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: colorScheme.error.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    s.$1,
                    style: AppTextStyles.monoTiny.copyWith(
                      color: colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
