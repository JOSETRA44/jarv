import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/session_state.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../providers/terminal_provider.dart';

class PromptBar extends ConsumerStatefulWidget {
  const PromptBar({super.key});

  @override
  ConsumerState<PromptBar> createState() => _PromptBarState();
}

class _PromptBarState extends ConsumerState<PromptBar> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _history = <String>[];
  int _historyIdx = -1;
  bool _quickExpanded = false;

  @override
  void initState() {
    super.initState();
    // Intercept arrow keys on the TextField's own focus node so we can:
    //  - Navigate history when shell is idle (consumed, TextField doesn't see them)
    //  - Pass them through to the TextField when a process is running
    //    (so the user can edit multi-line input inside the REPL)
    _focus.onKeyEvent = (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      final isWaiting = ref.read(terminalProvider).isWaitingForPrompt;
      // In process mode: pass all keys through — the running process owns the input
      if (isWaiting) return KeyEventResult.ignored;
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _historyUp();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _historyDown();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text;
    final notifier = ref.read(terminalProvider.notifier);
    final isWaiting = ref.read(terminalProvider).isWaitingForPrompt;

    if (isWaiting) {
      // Process mode: always send to PTY, even empty text.
      // Empty Enter = \r alone, which navigates menus, confirms prompts, etc.
      notifier.sendRawInput('$text\r');
      _ctrl.clear();
      _focus.requestFocus();
      return;
    }

    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      _ctrl.clear();
      return;
    }
    notifier.sendCommand(trimmed);
    _history.insert(0, trimmed);
    if (_history.length > 100) _history.removeLast();
    _historyIdx = -1;
    _ctrl.clear();
    _focus.requestFocus();
  }

  void _historyUp() {
    if (_history.isEmpty) return;
    final next = (_historyIdx + 1).clamp(0, _history.length - 1);
    setState(() {
      _historyIdx = next;
      _ctrl.text = _history[next];
      _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
    });
  }

  void _historyDown() {
    if (_historyIdx <= 0) {
      setState(() {
        _historyIdx = -1;
        _ctrl.clear();
      });
      return;
    }
    final next = _historyIdx - 1;
    setState(() {
      _historyIdx = next;
      _ctrl.text = _history[next];
      _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(terminalProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final isConnected = state.connectionStatus.isConnected;
    final isWaiting = state.isWaitingForPrompt;

    final bgColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkOutline : AppColors.lightOutline;
    final cwdColor = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    // Amber used for the "process input" mode indicator
    const processColor = AppColors.statusConnecting;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Quick commands — suppressed in process mode (would send cmds to the REPL)
        if (_quickExpanded && isConnected && !isWaiting)
          _QuickCommands(
            onSelect: (cmd) {
              _ctrl.text = cmd;
              _focus.requestFocus();
              _ctrl.selection = TextSelection.collapsed(offset: cmd.length);
              setState(() => _quickExpanded = false);
            },
          ),

        Divider(height: 1, color: borderColor),

        Container(
          color: bgColor,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Prefix: amber "input ›" in process mode, CWD prompt otherwise
              if (isWaiting && isConnected)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    'input ›',
                    style: AppTextStyles.cwd.copyWith(color: processColor),
                  ),
                )
              else if (state.currentCwd.isNotEmpty && isConnected)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    '${_shortPath(state.currentCwd)} \$',
                    style: AppTextStyles.cwd.copyWith(color: cwdColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              // Input field — ALWAYS enabled while connected.
              // A real terminal never blocks keyboard input regardless of process state.
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  enabled: isConnected,
                  autofocus: false,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: isWaiting
                        ? 'entrada para el proceso...'
                        : 'comando...',
                    hintStyle: AppTextStyles.monoMedium.copyWith(
                      color: isWaiting
                          ? processColor.withOpacity(0.45)
                          : (isDark
                              ? AppColors.darkOnSurface.withOpacity(0.3)
                              : AppColors.lightOnSurface.withOpacity(0.3)),
                    ),
                  ),
                  style: AppTextStyles.monoMedium.copyWith(
                    color: isDark
                        ? AppColors.darkOnSurface
                        : AppColors.lightOnSurface,
                  ),
                  onSubmitted: (_) => _submit(),
                  textInputAction: TextInputAction.send,
                ),
              ),

              const SizedBox(width: 8),

              // Process mode: ESC + Ctrl+C to interrupt, Enter to send
              if (isWaiting) ...[
                // ESC — cancel/pause (e.g. gemini uses "esc to cancel")
                _TextBtn(
                  label: 'ESC',
                  color: processColor,
                  tooltip: 'Enviar ESC al proceso',
                  onTap: () =>
                      ref.read(terminalProvider.notifier).sendSignal('\x1b'),
                ),
                const SizedBox(width: 4),
                // Ctrl+C — interrupt / SIGINT
                _IconBtn(
                  icon: Icons.stop_rounded,
                  color: AppColors.statusError,
                  tooltip: 'Ctrl+C  (interrumpir proceso)',
                  onTap: () =>
                      ref.read(terminalProvider.notifier).sendSignal('\x03'),
                ),
                const SizedBox(width: 4),
                _IconBtn(
                  icon: Icons.keyboard_return_rounded,
                  color: processColor,
                  tooltip: 'Enviar al proceso',
                  onTap: isConnected ? _submit : null,
                ),
              ] else ...[
                // Shell mode: quick commands toggle + send
                _IconBtn(
                  icon: _quickExpanded
                      ? Icons.expand_more_rounded
                      : Icons.expand_less_rounded,
                  color: cs.onSurface.withOpacity(0.4),
                  tooltip: 'Comandos rápidos',
                  onTap: () =>
                      setState(() => _quickExpanded = !_quickExpanded),
                ),
                const SizedBox(width: 4),
                _IconBtn(
                  icon: Icons.send_rounded,
                  color: isConnected
                      ? cs.primary
                      : cs.onSurface.withOpacity(0.2),
                  tooltip: 'Enviar',
                  onTap: isConnected ? _submit : null,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Quick commands strip ──────────────────────────────────────────────────────

class _QuickCommands extends StatelessWidget {
  final void Function(String) onSelect;

  const _QuickCommands({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final borderColor = isDark ? AppColors.darkOutline : AppColors.lightOutline;

    return Container(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: AppConstants.quickCommands.map((cmd) {
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                onTap: () => onSelect(cmd),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    cmd,
                    style: AppTextStyles.monoTiny.copyWith(
                      color: cs.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Text button helper (for short labels like "ESC") ─────────────────────────

class _TextBtn extends StatelessWidget {
  final String label;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  const _TextBtn({
    required this.label,
    required this.color,
    required this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.5), width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              fontFamily: 'JetBrains Mono',
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Icon button helper ────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  const _IconBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

String _shortPath(String cwd) {
  final parts =
      cwd.replaceAll(r'\', '/').split('/').where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '~';
  if (parts.length <= 2) return parts.join('/');
  return '…/${parts.last}';
}
