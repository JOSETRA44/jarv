class SessionTab {
  final String id;
  final String cwd;
  final bool isActive;

  const SessionTab({
    required this.id,
    required this.cwd,
    required this.isActive,
  });

  /// Short display label: last path segment.
  String get label {
    final parts = cwd.replaceAll(r'\', '/').split('/').where((s) => s.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.last : cwd;
  }

  SessionTab copyWith({String? id, String? cwd, bool? isActive}) {
    return SessionTab(
      id: id ?? this.id,
      cwd: cwd ?? this.cwd,
      isActive: isActive ?? this.isActive,
    );
  }
}
