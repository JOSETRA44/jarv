enum MessageType {
  command,
  output,
  system,
  interactive,
  error,
}

class TerminalMessage {
  final String id;
  final MessageType type;
  final String content;
  final DateTime timestamp;
  final int? exitCode;
  final String? cwd;
  final int? durationMs;
  final String? processName;

  const TerminalMessage({
    required this.id,
    required this.type,
    required this.content,
    required this.timestamp,
    this.exitCode,
    this.cwd,
    this.durationMs,
    this.processName,
  });

  TerminalMessage copyWith({
    String? id,
    MessageType? type,
    String? content,
    DateTime? timestamp,
    int? exitCode,
    String? cwd,
    int? durationMs,
    String? processName,
  }) {
    return TerminalMessage(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      exitCode: exitCode ?? this.exitCode,
      cwd: cwd ?? this.cwd,
      durationMs: durationMs ?? this.durationMs,
      processName: processName ?? this.processName,
    );
  }

  @override
  String toString() =>
      'TerminalMessage(id: $id, type: $type, content: ${content.length > 50 ? content.substring(0, 50) : content})';
}
