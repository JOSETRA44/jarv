import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class PoltergeistEmptyState extends StatelessWidget {
  final bool isConnecting;

  const PoltergeistEmptyState({super.key, this.isConnecting = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted =
        isDark ? AppColors.darkMuted : AppColors.lightMuted;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isConnecting
                  ? Icons.sync_rounded
                  : Icons.spatial_audio_off_rounded,
              size: 64,
              color: muted,
            ),
            const SizedBox(height: 16),
            Text(
              isConnecting ? 'Conectando...' : 'Controla tu escritorio',
              style: AppTextStyles.titleMedium.copyWith(color: muted),
            ),
            const SizedBox(height: 8),
            Text(
              isConnecting
                  ? 'Estableciendo canal seguro con JARVIS'
                  : 'Conecta en Ajustes para activar el panel de control',
              style: AppTextStyles.bodySmall.copyWith(color: muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
