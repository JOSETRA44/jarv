import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../domain/entities/terminal_block.dart';

class TerminalBlockWidget extends StatelessWidget {
  final TerminalBlock block;

  const TerminalBlockWidget({super.key, required this.block});

  @override
  Widget build(BuildContext context) {
    return switch (block.type) {
      TerminalBlockType.motd => _MotdContent(block: block),
      TerminalBlockType.command => _CommandBlock(block: block),
      TerminalBlockType.system => _SystemBlock(block: block),
    };
  }
}

// ── Command block (Warp-style) ────────────────────────────────────────────────

class _CommandBlock extends StatelessWidget {
  final TerminalBlock block;
  const _CommandBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final isRunning = block.isRunning;
    final success = (block.exitCode ?? 0) == 0;

    final accentColor = isRunning
        ? AppColors.statusConnecting
        : success
            ? AppColors.statusConnected
            : AppColors.statusError;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: accentColor, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: cwd + command + badges
          _BlockHeader(block: block, accentColor: accentColor, isDark: isDark, cs: cs),

          // Output lines
          if (block.outputLines.isNotEmpty)
            _OutputLines(lines: block.outputLines, isDark: isDark),

          // Running indicator
          if (isRunning) _RunningIndicator(accentColor: accentColor),
        ],
      ),
    );
  }
}

class _BlockHeader extends StatelessWidget {
  final TerminalBlock block;
  final Color accentColor;
  final bool isDark;
  final ColorScheme cs;

  const _BlockHeader({
    required this.block,
    required this.accentColor,
    required this.isDark,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final cwd = _shortPath(block.cwd);
    final isRunning = block.isRunning;
    final success = (block.exitCode ?? 0) == 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // CWD
          Text(
            '$cwd \$',
            style: AppTextStyles.cwd.copyWith(
              color: accentColor.withOpacity(0.85),
            ),
          ),
          const SizedBox(width: 8),
          // Command
          Expanded(
            child: SelectableText(
              block.command ?? '',
              style: AppTextStyles.monoMedium.copyWith(
                color: isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Duration badge
          if (!isRunning && block.duration != null)
            _Badge(
              label: _formatDuration(block.duration!),
              color: cs.onSurface.withOpacity(0.35),
            ),
          // Exit code badge
          if (!isRunning && block.exitCode != null) ...[
            const SizedBox(width: 4),
            _Badge(
              label: block.exitCode == 0 ? 'ok' : 'exit ${block.exitCode}',
              color: success ? AppColors.statusConnected : AppColors.statusError,
              filled: true,
            ),
          ],
          // Copy button
          if (!isRunning && block.outputLines.isNotEmpty) ...[
            const SizedBox(width: 4),
            _CopyButton(text: block.outputLines.join('\n')),
          ],
        ],
      ),
    );
  }
}

class _OutputLines extends StatelessWidget {
  final List<String> lines;
  final bool isDark;

  const _OutputLines({required this.lines, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withOpacity(0.25)
            : Colors.black.withOpacity(0.04),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
      ),
      child: SelectableText(
        lines.join('\n'),
        style: AppTextStyles.monoSmall.copyWith(
          color: isDark
              ? AppColors.darkOnSurface.withOpacity(0.88)
              : AppColors.lightOnSurface.withOpacity(0.88),
          height: 1.55,
        ),
      ),
    );
  }
}

class _RunningIndicator extends StatefulWidget {
  final Color accentColor;
  const _RunningIndicator({required this.accentColor});

  @override
  State<_RunningIndicator> createState() => _RunningIndicatorState();
}

class _RunningIndicatorState extends State<_RunningIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: FadeTransition(
        opacity: _ctrl.drive(CurveTween(curve: Curves.easeInOut)),
        child: Row(
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: widget.accentColor,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'ejecutando...',
              style: AppTextStyles.monoTiny.copyWith(
                color: widget.accentColor.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── System block ─────────────────────────────────────────────────────────────

class _SystemBlock extends StatelessWidget {
  final TerminalBlock block;
  const _SystemBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isError = (block.exitCode ?? 0) != 0;
    final color = isError ? AppColors.statusError : AppColors.statusConnecting;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              block.outputLines.join(' '),
              style: AppTextStyles.monoTiny.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ── MOTD content ──────────────────────────────────────────────────────────────

class _MotdContent extends StatelessWidget {
  final TerminalBlock block;
  const _MotdContent({required this.block});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkPrimaryContainer.withOpacity(0.4)
            : AppColors.lightPrimaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? AppColors.darkPrimary.withOpacity(0.2)
              : AppColors.lightPrimary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: block.outputLines.map((line) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              line,
              style: AppTextStyles.monoTiny.copyWith(
                color: isDark
                    ? AppColors.darkPrimary
                    : AppColors.lightPrimary,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;

  const _Badge({required this.label, required this.color, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? color.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: AppTextStyles.monoTiny.copyWith(color: color),
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  final String text;
  const _CopyButton({required this.text});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: widget.text));
        if (!mounted) return;
        setState(() => _copied = true);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _copied = false);
      },
      child: Icon(
        _copied ? Icons.check_rounded : Icons.copy_rounded,
        size: 14,
        color: cs.onSurface.withOpacity(0.35),
      ),
    );
  }
}

// ── Utilities ─────────────────────────────────────────────────────────────────

String _shortPath(String cwd) {
  final parts =
      cwd.replaceAll(r'\', '/').split('/').where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '~';
  if (parts.length == 1) return parts.first;
  return '…/${parts.last}';
}

String _formatDuration(Duration d) {
  if (d.inMinutes >= 1) return '${d.inMinutes}m${d.inSeconds % 60}s';
  if (d.inSeconds >= 1) return '${d.inMilliseconds / 1000}s'.replaceAll(RegExp(r'\.?0+s$'), 's');
  return '${d.inMilliseconds}ms';
}
