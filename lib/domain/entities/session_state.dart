enum SessionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

extension SessionStatusExtension on SessionStatus {
  String get displayLabel {
    switch (this) {
      case SessionStatus.disconnected:
        return 'Desconectado';
      case SessionStatus.connecting:
        return 'Conectando...';
      case SessionStatus.connected:
        return 'Conectado';
      case SessionStatus.error:
        return 'Error';
    }
  }

  bool get isConnected => this == SessionStatus.connected;
  bool get isConnecting => this == SessionStatus.connecting;
  bool get isError => this == SessionStatus.error;
  bool get isDisconnected => this == SessionStatus.disconnected;
}

class SessionState {
  final SessionStatus status;
  final String? errorMessage;

  const SessionState({
    required this.status,
    this.errorMessage,
  });

  const SessionState.disconnected()
      : status = SessionStatus.disconnected,
        errorMessage = null;

  const SessionState.connecting()
      : status = SessionStatus.connecting,
        errorMessage = null;

  const SessionState.connected()
      : status = SessionStatus.connected,
        errorMessage = null;

  SessionState.error(String message)
      : status = SessionStatus.error,
        errorMessage = message;

  SessionState copyWith({
    SessionStatus? status,
    String? errorMessage,
  }) {
    return SessionState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
