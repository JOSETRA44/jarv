import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../domain/entities/session_state.dart';
import '../../../providers/terminal_provider.dart';

class ConnectionStatusBar extends ConsumerStatefulWidget {
  const ConnectionStatusBar({super.key});

  @override
  ConsumerState<ConnectionStatusBar> createState() =>
      _ConnectionStatusBarState();
}

class _ConnectionStatusBarState extends ConsumerState<ConnectionStatusBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _statusColor(SessionStatus status) {
    switch (status) {
      case SessionStatus.connected:
        return AppColors.statusConnected;
      case SessionStatus.connecting:
        return AppColors.statusConnecting;
      case SessionStatus.error:
        return AppColors.statusError;
      case SessionStatus.disconnected:
        return AppColors.statusDisconnected;
    }
  }

  @override
  Widget build(BuildContext context) {
    final terminalState = ref.watch(terminalProvider);
    final status = terminalState.sessionState.status;
    final cwd = terminalState.currentCwd;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dotColor = _statusColor(status);
    final isAnimating = status == SessionStatus.connecting;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Pulsing status dot
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, child) {
              return Opacity(
                opacity: isAnimating ? _pulseAnim.value : 1.0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: dotColor.withOpacity(0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          // JARVIS label
          Text(
            'JARVIS',
            style: AppTextStyles.monoBold.copyWith(
              color: colorScheme.primary,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
          if (cwd.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '|',
                style: AppTextStyles.monoTiny.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.2),
                ),
              ),
            ),
            Expanded(
              child: Text(
                cwd,
                style: AppTextStyles.cwd.copyWith(
                  color: colorScheme.secondary.withOpacity(0.85),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ] else
            Expanded(
              child: Text(
                status.displayLabel,
                style: AppTextStyles.bodySmall.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ),
          // Error icon
          if (status == SessionStatus.error)
            Icon(
              Icons.warning_amber_rounded,
              size: 14,
              color: AppColors.statusError,
            ),
        ],
      ),
    );
  }
}
