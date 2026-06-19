import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../domain/entities/terminal_message.dart';

class MessageBubble extends StatelessWidget {
  final TerminalMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    switch (message.type) {
      case MessageType.command:
        return _CommandBubble(message: message);
      case MessageType.output:
        return _OutputBubble(message: message);
      case MessageType.interactive:
        return _InteractiveBubble(message: message);
      case MessageType.error:
        return _SystemBubble(message: message, isError: true);
      case MessageType.system:
        return _SystemBubble(message: message);
    }
  }
}

class _CommandBubble extends StatelessWidget {
  final TerminalMessage message;

  const _CommandBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primary = colorScheme.primary;
    final timeStr =
        DateFormat('HH:mm:ss').format(message.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.85,
          ),
          child: GestureDetector(
            onLongPress: () => _copyToClipboard(context, message.content),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
                border: Border.all(
                  color: primary.withOpacity(0.25),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '> ${message.content}',
                    style: AppTextStyles.monoMedium.copyWith(
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeStr,
                    style: AppTextStyles.monoTiny.copyWith(
                      color: primary.withOpacity(0.45),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutputBubble extends StatelessWidget {
  final TerminalMessage message;

  const _OutputBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = colorScheme.secondary;
    final surface = isDark ? AppColors.darkCard : AppColors.lightCard;
    final timeStr = DateFormat('HH:mm:ss').format(message.timestamp);
    final hasExitCode = message.exitCode != null;
    final exitOk = (message.exitCode ?? 0) == 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.95,
          ),
          child: GestureDetector(
            onLongPress: () => _copyToClipboard(context, message.content),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
                border: Border.all(
                  color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header row
                  if (hasExitCode) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          exitOk
                              ? Icons.check_circle_outline_rounded
                              : Icons.error_outline_rounded,
                          size: 12,
                          color: exitOk ? secondary : colorScheme.error,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'exit ${message.exitCode}',
                          style: AppTextStyles.monoTiny.copyWith(
                            color: exitOk
                                ? secondary
                                : colorScheme.error,
                          ),
                        ),
                        if (message.durationMs != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${message.durationMs}ms',
                            style: AppTextStyles.monoTiny.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.35),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],

                  // Output content
                  SelectableText(
                    message.content.isEmpty ? '(sin salida)' : message.content,
                    style: AppTextStyles.monoMedium.copyWith(
                      color: message.content.isEmpty
                          ? colorScheme.onSurface.withOpacity(0.35)
                          : colorScheme.onSurface.withOpacity(0.9),
                      height: 1.45,
                    ),
                  ),

                  // Footer: time + cwd
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: AppTextStyles.monoTiny.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.3),
                        ),
                      ),
                      if (message.cwd != null && message.cwd!.isNotEmpty) ...[
                        Text(
                          '  ·  ',
                          style: AppTextStyles.monoTiny.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.2),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            message.cwd!,
                            style: AppTextStyles.monoTiny.copyWith(
                              color: secondary.withOpacity(0.5),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InteractiveBubble extends StatelessWidget {
  final TerminalMessage message;

  const _InteractiveBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkCard : AppColors.lightCard;
    final accent = colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withOpacity(0.4), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '⬤  ${message.processName ?? 'interactive'}',
                    style: AppTextStyles.monoTiny.copyWith(color: accent),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Modo interactivo',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
              ],
            ),
            if (message.content.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  message.content,
                  style: AppTextStyles.monoSmall.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.85),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SystemBubble extends StatelessWidget {
  final TerminalMessage message;
  final bool isError;

  const _SystemBubble({required this.message, this.isError = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isError
        ? colorScheme.error.withOpacity(0.75)
        : colorScheme.onSurface.withOpacity(0.35);
    final bgColor = isError
        ? colorScheme.error.withOpacity(0.06)
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            message.content,
            style: AppTextStyles.labelSmall.copyWith(color: color),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

void _copyToClipboard(BuildContext context, String text) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Copiado al portapapeles'),
      duration: Duration(seconds: 2),
    ),
  );
}
