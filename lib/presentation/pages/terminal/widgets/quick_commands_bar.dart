import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_text_styles.dart';

class QuickCommandsBar extends StatelessWidget {
  final void Function(String command) onCommandSelected;
  final bool isEnabled;

  const QuickCommandsBar({
    super.key,
    required this.onCommandSelected,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: AppConstants.quickCommands.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final cmd = AppConstants.quickCommands[index];
          final isInteractive = cmd.startsWith('!');
          return InkWell(
            onTap: isEnabled ? () => onCommandSelected(cmd) : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isInteractive
                    ? colorScheme.secondary.withOpacity(0.1)
                    : colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isInteractive
                      ? colorScheme.secondary.withOpacity(0.25)
                      : colorScheme.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Text(
                cmd,
                style: AppTextStyles.monoTiny.copyWith(
                  color: isInteractive
                      ? colorScheme.secondary
                      : colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
