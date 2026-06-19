import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/terminal_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/entities/terminal_block.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final terminalState = ref.watch(terminalProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final commands = terminalState.blocks
        .where((b) => b.type == TerminalBlockType.command && b.isComplete)
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
              itemBuilder: (context, index) =>
                  _HistoryItem(block: commands[index]),
            ),
    );
  }

  void _showClearDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpiar historial'),
        content: const Text(
            '¿Estás seguro de que quieres borrar todos los bloques?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              ref.read(terminalProvider.notifier).clearBlocks();
              Navigator.pop(ctx);
            },
            child: Text(
              'Limpiar',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final TerminalBlock block;

  const _HistoryItem({required this.block});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkCard : AppColors.lightCard;
    final timeStr =
        DateFormat('HH:mm:ss · dd MMM').format(block.startedAt);
    final exitCode = block.exitCode ?? 0;
    final exitOk = exitCode == 0;
    final output = block.outputLines.join('\n');

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
                    block.command ?? '',
                    style: AppTextStyles.monoMedium.copyWith(
                      color: colorScheme.primary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _copy(context, block.command ?? ''),
                  child: Icon(
                    Icons.copy_rounded,
                    size: 14,
                    color: colorScheme.onSurface.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ),

          Divider(
            height: 1,
            color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (output.isNotEmpty) ...[
                  Text(
                    output,
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
                        'exit $exitCode',
                        style: AppTextStyles.monoTiny.copyWith(
                          color: exitOk
                              ? colorScheme.secondary
                              : colorScheme.error,
                        ),
                      ),
                    ),
                    if (block.duration != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '${block.duration!.inMilliseconds}ms',
                        style: AppTextStyles.monoTiny.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.25),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (output.isNotEmpty)
                      GestureDetector(
                        onTap: () => _copy(context, output),
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

  void _copy(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copiado'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}
