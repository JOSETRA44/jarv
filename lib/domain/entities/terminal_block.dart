import 'package:uuid/uuid.dart';

enum TerminalBlockType { motd, command, system }

class TerminalBlock {
  final String id;
  final TerminalBlockType type;
  final String cwd;
  final String? command;
  final List<String> outputLines;
  final int? exitCode;
  final Duration? duration;
  final DateTime startedAt;
  final bool isComplete;
  final String sessionId;

  const TerminalBlock({
    required this.id,
    required this.type,
    required this.cwd,
    this.command,
    this.outputLines = const [],
    this.exitCode,
    this.duration,
    required this.startedAt,
    this.isComplete = false,
    required this.sessionId,
  });

  TerminalBlock copyWith({
    String? id,
    TerminalBlockType? type,
    String? cwd,
    String? command,
    List<String>? outputLines,
    int? exitCode,
    Duration? duration,
    DateTime? startedAt,
    bool? isComplete,
    String? sessionId,
  }) {
    return TerminalBlock(
      id: id ?? this.id,
      type: type ?? this.type,
      cwd: cwd ?? this.cwd,
      command: command ?? this.command,
      outputLines: outputLines ?? this.outputLines,
      exitCode: exitCode ?? this.exitCode,
      duration: duration ?? this.duration,
      startedAt: startedAt ?? this.startedAt,
      isComplete: isComplete ?? this.isComplete,
      sessionId: sessionId ?? this.sessionId,
    );
  }

  factory TerminalBlock.command({
    required String command,
    required String cwd,
    required String sessionId,
  }) {
    return TerminalBlock(
      id: const Uuid().v4(),
      type: TerminalBlockType.command,
      cwd: cwd,
      command: command,
      outputLines: const [],
      startedAt: DateTime.now(),
      isComplete: false,
      sessionId: sessionId,
    );
  }

  factory TerminalBlock.motd({
    required String cwd,
    required String connectionId,
    required String sessionId,
  }) {
    return TerminalBlock(
      id: const Uuid().v4(),
      type: TerminalBlockType.motd,
      cwd: cwd,
      outputLines: [
        'JARVIS Terminal v1.0',
        'Session  $connectionId',
        'CWD      $cwd',
        'Type a command to start.',
      ],
      startedAt: DateTime.now(),
      isComplete: true,
      sessionId: sessionId,
    );
  }

  factory TerminalBlock.system({
    required String message,
    required String cwd,
    required String sessionId,
    bool isError = false,
  }) {
    return TerminalBlock(
      id: const Uuid().v4(),
      type: TerminalBlockType.system,
      cwd: cwd,
      outputLines: [message],
      exitCode: isError ? 1 : 0,
      startedAt: DateTime.now(),
      isComplete: true,
      sessionId: sessionId,
    );
  }

  bool get isRunning => !isComplete && type == TerminalBlockType.command;
  bool get succeeded => exitCode == 0;
}
