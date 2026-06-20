enum ActionCategory { apps, media, system, tts, keyboard, mouse }

class GuiAction {
  final String id;
  final String label;
  final ActionCategory category;
  final String icon;
  final bool requiresText;
  final bool hidden;

  const GuiAction({
    required this.id,
    required this.label,
    required this.category,
    required this.icon,
    this.requiresText = false,
    this.hidden = false,
  });

  factory GuiAction.fromJson(Map<String, dynamic> json) => GuiAction(
        id: json['id'] as String,
        label: json['label'] as String,
        category: ActionCategory.values.firstWhere(
          (c) => c.name == json['category'],
          orElse: () => ActionCategory.system,
        ),
        icon: json['icon'] as String? ?? 'touch_app',
        requiresText:
            (json['params'] as List?)?.any((p) => p['name'] == 'text') ?? false,
        hidden: json['hidden'] as bool? ?? false,
      );
}

/// A TTS voice installed on the host, for selection in the UI.
class VoiceProfile {
  final String id;
  final String label;
  final String culture;
  final String gender;

  const VoiceProfile({
    required this.id,
    required this.label,
    required this.culture,
    required this.gender,
  });

  factory VoiceProfile.fromJson(Map<String, dynamic> json) => VoiceProfile(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        culture: json['culture'] as String? ?? '',
        gender: json['gender'] as String? ?? '',
      );
}
