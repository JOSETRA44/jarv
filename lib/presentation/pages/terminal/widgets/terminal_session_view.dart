import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import '../../../providers/terminal_provider.dart';

class TerminalSessionView extends ConsumerWidget {
  final String sessionId;

  const TerminalSessionView({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(terminalProvider.notifier);
    final terminal = notifier.getTerminal(sessionId);

    if (terminal == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    // Wire keyboard output from xterm → backend PTY.
    // onOutput fires when the user types; xterm encodes keystrokes into
    // the appropriate VT sequences (arrows → \x1b[A, Ctrl+C → \x03, etc.).
    terminal.onOutput = (data) => notifier.sendRawInput(data, sessionId: sessionId);

    return TerminalView(
      terminal,
      readOnly: false,
      autofocus: true,
    );
  }
}
