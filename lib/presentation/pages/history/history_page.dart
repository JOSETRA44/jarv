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

    final logs = terminalState.blocks
        .where((b) =>
            b.type == TerminalBlockType.motd ||
            b.type == TerminalBlockType.system)
        .toList()
        .reversed
        .toList();

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          'Logs',
          style: AppTextStyles.titleLarge.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
        actions: [
          if (logs.isNotEmpty)
            IconButton(
              onPressed: () => _showClearDialog(context, ref),
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Limpiar logs',
            ),
        ],
      ),
      body: logs.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 48,
                    color: colorScheme.onSurface.withOpacity(0.15),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sin eventos del sistema',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Los eventos de conexión y errores aparecerán aquí',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.2),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: logs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) =>
                  _LogItem(block: logs[index]),
            ),
    );
  }

  void _showClearDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpiar logs'),
        content: const Text('¿Borrar todos los eventos del sistema?'),
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

class _LogItem extends StatelessWidget {
  final TerminalBlock block;

  const _LogItem({required this.block});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkCard : AppColors.lightCard;
    final timeStr = DateFormat('HH:mm:ss · dd MMM').format(block.startedAt);

    final isError = block.type == TerminalBlockType.system &&
        (block.exitCode ?? 0) != 0;

    final accentColor = block.type == TerminalBlockType.motd
        ? (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
        : isError
            ? AppColors.statusError
            : AppColors.statusConnecting;

    final icon = block.type == TerminalBlockType.motd
        ? Icons.terminal_rounded
        : isError
            ? Icons.error_outline_rounded
            : Icons.info_outline_rounded;

    final content = block.outputLines.join('\n');

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accentColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Icon(icon, size: 14, color: accentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    block.type == TerminalBlockType.motd ? 'JARVIS conectado' : 'Sistema',
                    style: AppTextStyles.monoSmall.copyWith(
                      color: accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  timeStr,
                  style: AppTextStyles.monoTiny.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.3),
                  ),
                ),
                if (content.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _copy(context, content),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 14,
                      color: colorScheme.onSurface.withOpacity(0.3),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Text(
                content,
                style: AppTextStyles.monoSmall.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.65),
                  height: 1.4,
                ),
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
