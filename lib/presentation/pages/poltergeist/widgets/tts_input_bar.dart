import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../domain/entities/gui_action.dart';

typedef SpeakCallback = void Function(
  String text, {
  String? preset,
  String? voice,
  double? rate,
});

class TtsInputBar extends StatefulWidget {
  final SpeakCallback onSpeak;
  final bool isExecuting;
  final List<VoiceProfile> voices;
  final List<String> presets;
  final bool showVoiceControls;
  final String buttonLabel;
  final String hint;

  const TtsInputBar({
    super.key,
    required this.onSpeak,
    required this.isExecuting,
    this.voices = const [],
    this.presets = const [],
    this.showVoiceControls = true,
    this.buttonLabel = 'Hablar',
    this.hint = 'Escribe texto para voz...',
  });

  @override
  State<TtsInputBar> createState() => _TtsInputBarState();
}

class _TtsInputBarState extends State<TtsInputBar> {
  final _ctrl = TextEditingController();
  String? _preset;
  String? _voiceId; // null → use the preset's voice
  double _rate = 1.0;

  @override
  void initState() {
    super.initState();
    _preset = _defaultPreset();
  }

  @override
  void didUpdateWidget(TtsInputBar old) {
    super.didUpdateWidget(old);
    if (_preset == null || !widget.presets.contains(_preset)) {
      _preset = _defaultPreset();
    }
  }

  String? _defaultPreset() {
    if (widget.presets.isEmpty) return null;
    if (widget.presets.contains('jarvis')) return 'jarvis';
    return widget.presets.first;
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty || widget.isExecuting) return;
    widget.onSpeak(
      text,
      preset: widget.showVoiceControls ? _preset : null,
      voice: widget.showVoiceControls ? _voiceId : null,
      rate: widget.showVoiceControls ? _rate : null,
    );
    _ctrl.clear();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final card = isDark ? AppColors.darkCard : AppColors.lightCard;
    final outline = isDark ? AppColors.darkOutline : AppColors.lightOutline;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: card,
        border: Border(top: BorderSide(color: outline)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showVoiceControls) ...[
            Row(
              children: [
                if (widget.presets.isNotEmpty)
                  Expanded(
                    child: _dropdown<String>(
                      value: _preset,
                      hint: 'Preset',
                      items: widget.presets
                          .map((p) => DropdownMenuItem(
                                value: p,
                                child: Text(_presetLabel(p),
                                    style: AppTextStyles.bodySmall),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _preset = v),
                      outline: outline,
                      muted: muted,
                    ),
                  ),
                if (widget.presets.isNotEmpty && widget.voices.isNotEmpty)
                  const SizedBox(width: 8),
                if (widget.voices.isNotEmpty)
                  Expanded(
                    child: _dropdown<String?>(
                      value: _voiceId,
                      hint: 'Voz',
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Voz del preset',
                              style: AppTextStyles.bodySmall),
                        ),
                        ...widget.voices.map((v) => DropdownMenuItem<String?>(
                              value: v.id,
                              child: Text(v.label,
                                  style: AppTextStyles.bodySmall,
                                  overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (v) => setState(() => _voiceId = v),
                      outline: outline,
                      muted: muted,
                    ),
                  ),
              ],
            ),
            Row(
              children: [
                Icon(Icons.speed_rounded, size: 16, color: muted),
                Expanded(
                  child: Slider(
                    value: _rate,
                    min: 0.5,
                    max: 1.5,
                    divisions: 10,
                    label: '${_rate.toStringAsFixed(1)}x',
                    activeColor: primary,
                    onChanged: (v) => setState(() => _rate = v),
                  ),
                ),
                Text('${_rate.toStringAsFixed(1)}x',
                    style: AppTextStyles.labelSmall.copyWith(color: muted)),
              ],
            ),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  style: AppTextStyles.bodyMedium,
                  maxLength: 200,
                  maxLines: 1,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: AppTextStyles.bodyMedium.copyWith(color: muted),
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: primary, width: 1.5),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: widget.isExecuting ? null : _submit,
                icon: widget.isExecuting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.record_voice_over_rounded, size: 18),
                label: Text(
                  widget.buttonLabel,
                  style: AppTextStyles.labelSmall.copyWith(
                      color: Colors.black, fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _presetLabel(String id) {
    switch (id) {
      case 'jarvis':
        return 'JARVIS (grave)';
      case 'default':
        return 'Normal';
      default:
        return id;
    }
  }

  Widget _dropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required Color outline,
    required Color muted,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          hint: Text(hint,
              style: AppTextStyles.bodySmall.copyWith(color: muted)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
