import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../providers/terminal_provider.dart';
import '../../../../domain/entities/session_state.dart';

class HelperBar extends ConsumerWidget {
  const HelperBar({super.key});

  static const _keys = [
    ('ESC', '\x1b'),
    ('Tab', '\t'),
    ('↑', '\x1b[A'),
    ('↓', '\x1b[B'),
    ('←', '\x1b[D'),
    ('→', '\x1b[C'),
    ('^C', '\x03'),
    ('^D', '\x04'),
    ('^Z', '\x1a'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(
      terminalProvider.select((s) => s.connectionStatus == SessionStatus.connected),
    );
    if (!connected) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkOutline : AppColors.lightOutline;

    return SafeArea(
      top: false,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: bg,
          border: Border(top: BorderSide(color: border, width: 1)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: _keys.map((entry) {
              final (label, seq) = entry;
              return _HelperButton(
                label: label,
                onTap: () => ref
                    .read(terminalProvider.notifier)
                    .sendRawInput(seq),
                isDark: isDark,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _HelperButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  const _HelperButton({
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isDark
        ? AppColors.darkOnSurface.withOpacity(0.7)
        : AppColors.lightOnSurface.withOpacity(0.7);
    final splash = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    return SizedBox(
      width: 48,
      height: 44,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: splash.withOpacity(0.15),
          highlightColor: splash.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.monoSmall.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
