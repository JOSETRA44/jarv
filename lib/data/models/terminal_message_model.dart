import '../../domain/entities/terminal_message.dart';

class TerminalMessageModel extends TerminalMessage {
  const TerminalMessageModel({
    required super.id,
    required super.type,
    required super.content,
    required super.timestamp,
    super.exitCode,
    super.cwd,
    super.durationMs,
    super.processName,
  });

  factory TerminalMessageModel.fromEntity(TerminalMessage entity) {
    return TerminalMessageModel(
      id: entity.id,
      type: entity.type,
      content: entity.content,
      timestamp: entity.timestamp,
      exitCode: entity.exitCode,
      cwd: entity.cwd,
      durationMs: entity.durationMs,
      processName: entity.processName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'exitCode': exitCode,
      'cwd': cwd,
      'durationMs': durationMs,
      'processName': processName,
    };
  }

  factory TerminalMessageModel.fromJson(Map<String, dynamic> json) {
    return TerminalMessageModel(
      id: json['id'] as String,
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.system,
      ),
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      exitCode: json['exitCode'] as int?,
      cwd: json['cwd'] as String?,
      durationMs: json['durationMs'] as int?,
      processName: json['processName'] as String?,
    );
  }
}
