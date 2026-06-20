import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../domain/entities/gui_action.dart';

// Maps the string icon names from the server catalog to Material icons.
const _iconMap = <String, IconData>{
  'language': Icons.language_rounded,
  'article': Icons.article_rounded,
  'folder_open': Icons.folder_open_rounded,
  'play_circle': Icons.play_circle_rounded,
  'music_note': Icons.music_note_rounded,
  'code': Icons.code_rounded,
  'terminal': Icons.terminal_rounded,
  'volume_up': Icons.volume_up_rounded,
  'volume_down': Icons.volume_down_rounded,
  'volume_off': Icons.volume_off_rounded,
  'play_arrow': Icons.play_arrow_rounded,
  'skip_next': Icons.skip_next_rounded,
  'skip_previous': Icons.skip_previous_rounded,
  'screenshot_monitor': Icons.screenshot_monitor_rounded,
  'lock': Icons.lock_rounded,
  'desktop_windows': Icons.desktop_windows_rounded,
  'bedtime': Icons.bedtime_rounded,
  'record_voice_over': Icons.record_voice_over_rounded,
  'view_compact_alt': Icons.view_compact_alt_rounded,
  'close': Icons.close_rounded,
  'undo': Icons.undo_rounded,
  'keyboard': Icons.keyboard_rounded,
  'keyboard_return': Icons.keyboard_return_rounded,
  'mouse': Icons.mouse_rounded,
  'touch_app': Icons.touch_app_rounded,
};

enum _FlashState { none, success, error }

class ActionButton extends StatefulWidget {
  final GuiAction action;
  final bool isExecuting;
  final bool isLastAction;
  final bool? lastSuccess;
  final VoidCallback onTap;

  const ActionButton({
    super.key,
    required this.action,
    required this.isExecuting,
    required this.isLastAction,
    required this.lastSuccess,
    required this.onTap,
  });

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scale;
  _FlashState _flash = _FlashState.none;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 120),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = _scaleCtrl;
  }

  @override
  void didUpdateWidget(ActionButton old) {
    super.didUpdateWidget(old);
    if (widget.isLastAction &&
        !old.isLastAction &&
        widget.lastSuccess != null) {
      _triggerFlash(widget.lastSuccess!);
    }
    if (old.isLastAction &&
        !widget.isLastAction &&
        old.lastSuccess != null) {
      // Another action became last — reset
      if (mounted) setState(() => _flash = _FlashState.none);
    }
  }

  void _triggerFlash(bool success) {
    setState(
        () => _flash = success ? _FlashState.success : _FlashState.error);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _flash = _FlashState.none);
    });
  }

  void _onTapDown(TapDownDetails _) => _scaleCtrl.reverse();
  void _onTapUp(TapUpDetails _) => _scaleCtrl.forward();
  void _onTapCancel() => _scaleCtrl.forward();

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final card = isDark ? AppColors.darkCard : AppColors.lightCard;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final outline = isDark ? AppColors.darkOutline : AppColors.lightOutline;

    Color borderColor;
    switch (_flash) {
      case _FlashState.success:
        borderColor = AppColors.statusConnected;
      case _FlashState.error:
        borderColor = AppColors.statusError;
      case _FlashState.none:
        borderColor = outline;
    }

    final isRunning = widget.isExecuting && widget.isLastAction;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: card,
            border: Border.all(color: borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  opacity: isRunning ? 0.5 : 1.0,
                  child: Icon(
                    _iconMap[widget.action.icon] ?? Icons.touch_app_rounded,
                    size: 28,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.action.label,
                  style: AppTextStyles.labelSmall.copyWith(color: muted),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
