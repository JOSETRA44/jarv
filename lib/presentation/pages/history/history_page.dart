import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/terminal_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/entities/terminal_message.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final terminalState = ref.watch(terminalProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter only command + output pairs
    final messages = terminalState.messages;
    final commands = messages
        .where((m) => m.type == MessageType.command)
        .toList()
        .reversed
        .toList();

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          'Historial',
          style: AppTextStyles.titleLarge.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
        actions: [
          if (commands.isNotEmpty)
            IconButton(
              onPressed: () => _showClearDialog(context, ref),
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Limpiar historial',
            ),
        ],
      ),
      body: commands.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 48,
                    color: colorScheme.onSurface.withOpacity(0.15),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sin historial',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Los comandos ejecutados aparecerán aquí',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.2),
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: commands.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final cmd = commands[index];
                // Find the corresponding output
                final cmdIndex = messages.indexOf(cmd);
                TerminalMessage? output;
                if (cmdIndex + 1 < messages.length &&
                    messages[cmdIndex + 1].type == MessageType.output) {
                  output = messages[cmdIndex + 1];
                }
                return _HistoryItem(command: cmd, output: output);
              },
            ),
    );
  }

  void _showClearDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpiar historial'),
        content: const Text(
            '¿Estás seguro de que quieres borrar todos los mensajes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              ref.read(terminalProvider.notifier).clearMessages();
              Navigator.pop(ctx);
            },
            child: Text(
              'Limpiar',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final TerminalMessage command;
  final TerminalMessage? output;

  const _HistoryItem({required this.command, this.output});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkCard : AppColors.lightCard;
    final timeStr = DateFormat('HH:mm:ss · dd MMM').format(command.timestamp);
    final exitOk = output?.exitCode == null || output?.exitCode == 0;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Command header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Text(
                  '>',
                  style: AppTextStyles.monoBold.copyWith(
                    color: colorScheme.primary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    command.content,
                    style: AppTextStyles.monoMedium.copyWith(
                      color: colorScheme.primary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _copyCommand(context, command.content),
                  child: Icon(
                    Icons.copy_rounded,
                    size: 14,
                    color: colorScheme.onSurface.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Divider(
            height: 1,
            color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
          ),

          // Output preview
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (output != null && output!.content.isNotEmpty) ...[
                  Text(
                    output!.content,
                    style: AppTextStyles.monoSmall.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.65),
                      height: 1.4,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Text(
                      timeStr,
                      style: AppTextStyles.monoTiny.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.3),
                      ),
                    ),
                    if (output?.exitCode != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: (exitOk
                                  ? colorScheme.secondary
                                  : colorScheme.error)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'exit ${output!.exitCode}',
                          style: AppTextStyles.monoTiny.copyWith(
                            color: exitOk
                                ? colorScheme.secondary
                                : colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    if (output?.durationMs != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '${output!.durationMs}ms',
                        style: AppTextStyles.monoTiny.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.25),
                        ),
                      ),
                    ],
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _copyOutput(
                          context, output?.content ?? ''),
                      child: Icon(
                        Icons.copy_all_rounded,
                        size: 14,
                        color: colorScheme.onSurface.withOpacity(0.25),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _copyCommand(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Comando copiado'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _copyOutput(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Salida copiada'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}
