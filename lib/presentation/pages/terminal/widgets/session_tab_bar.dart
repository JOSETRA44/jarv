import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/session_state.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../providers/terminal_provider.dart';

class SessionTabBar extends ConsumerWidget {
  const SessionTabBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(terminalProvider);
    final sessions = state.sessions;
    if (sessions.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final borderColor = isDark ? AppColors.darkOutline : AppColors.lightOutline;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          // Tabs list
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: sessions.length,
              itemBuilder: (context, i) {
                final tab = sessions[i];
                final isActive = tab.id == state.activeSessionId;
                final isRunning = state.blocks.any(
                  (b) => b.sessionId == tab.id && b.isRunning,
                );

                return _Tab(
                  label: tab.label,
                  index: i + 1,
                  isActive: isActive,
                  isRunning: isRunning,
                  isDark: isDark,
                  cs: cs,
                  onTap: () => ref
                      .read(terminalProvider.notifier)
                      .setActiveSession(tab.id),
                  onClose: sessions.length > 1
                      ? () => ref
                          .read(terminalProvider.notifier)
                          .closeSession(tab.id)
                      : null,
                );
              },
            ),
          ),

          // New session button
          if (state.connectionStatus.isConnected)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Tooltip(
                message: 'Nueva sesión',
                child: InkWell(
                  onTap: () => ref.read(terminalProvider.notifier).newSession(),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.add_rounded,
                      size: 16,
                      color: cs.onSurface.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final int index;
  final bool isActive;
  final bool isRunning;
  final bool isDark;
  final ColorScheme cs;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  const _Tab({
    required this.label,
    required this.index,
    required this.isActive,
    required this.isRunning,
    required this.isDark,
    required this.cs,
    required this.onTap,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor =
        isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final textColor = isActive
        ? activeColor
        : cs.onSurface.withOpacity(0.5);
    final bgColor = isActive
        ? (isDark
            ? AppColors.darkBackground
            : AppColors.lightBackground)
        : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: bgColor,
          border: isActive
              ? Border(bottom: BorderSide(color: activeColor, width: 2))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Running spinner
            if (isRunning)
              Padding(
                padding: const EdgeInsets.only(right: 5),
                child: SizedBox(
                  width: 8,
                  height: 8,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppColors.statusConnecting,
                  ),
                ),
              ),
            Text(
              '$index: $label',
              style: AppTextStyles.monoTiny.copyWith(
                color: textColor,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (onClose != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onClose,
                child: Icon(
                  Icons.close_rounded,
                  size: 12,
                  color: cs.onSurface.withOpacity(0.3),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
