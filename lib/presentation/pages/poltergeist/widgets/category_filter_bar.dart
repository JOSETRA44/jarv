import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../domain/entities/gui_action.dart';

const _kLabels = {
  null: 'Todo',
  ActionCategory.apps: 'Apps',
  ActionCategory.media: 'Media',
  ActionCategory.system: 'Sistema',
  ActionCategory.keyboard: 'Teclado',
  ActionCategory.tts: 'TTS',
};

class CategoryFilterBar extends StatelessWidget {
  final ActionCategory? selected;
  final ValueChanged<ActionCategory?> onChanged;

  const CategoryFilterBar({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final card = isDark ? AppColors.darkCard : AppColors.lightCard;
    final outline = isDark ? AppColors.darkOutline : AppColors.lightOutline;

    // Only categories with a label appear (mouse actions are hidden).
    final categories = _kLabels.keys.toList();

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = categories[i];
          final isSelected = cat == selected;
          return GestureDetector(
            onTap: () => onChanged(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? primary.withValues(alpha: 0.15) : card,
                border: Border.all(
                  color: isSelected ? primary : outline,
                  width: isSelected ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _kLabels[cat]!,
                style: AppTextStyles.labelSmall.copyWith(
                  color: isSelected ? primary : muted,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
