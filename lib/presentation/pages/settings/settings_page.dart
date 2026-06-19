import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/config_provider.dart';
import '../../providers/terminal_provider.dart';
import '../../providers/theme_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/connection_config.dart';
import '../../../domain/entities/session_state.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configState = ref.watch(configProvider);
    final terminalState = ref.watch(terminalProvider);
    final themeMode = ref.watch(themeProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          'Ajustes',
          style: AppTextStyles.titleLarge.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Connection section
          _SectionHeader(title: 'Conexión'),
          _SettingsCard(
            children: [
              _InfoRow(
                label: 'URL Backend',
                value: configState.config?.baseUrl ?? 'No configurado',
                mono: true,
              ),
              const _Divider(),
              _InfoRow(
                label: 'Estado',
                value: terminalState.sessionState.status.displayLabel,
                valueColor: _statusColor(terminalState.sessionState.status),
              ),
              if (terminalState.currentCwd.isNotEmpty) ...[
                const _Divider(),
                _InfoRow(
                  label: 'Directorio',
                  value: terminalState.currentCwd,
                  mono: true,
                ),
              ],
            ],
          ),

          // Edit connection button
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.go('/setup'),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Editar conexión'),
          ),

          const SizedBox(height: 24),

          // Transport section
          _SectionHeader(title: 'Transporte'),
          _SettingsCard(
            children: TransportType.values.map((t) {
              final isSelected = configState.config?.transportType == t;
              final isAvailable = t.isAvailable;
              return _TransportOption(
                type: t,
                isSelected: isSelected,
                isAvailable: isAvailable,
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Appearance section
          _SectionHeader(title: 'Apariencia'),
          _SettingsCard(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tema',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _ThemeChip(
                          label: 'Oscuro',
                          icon: Icons.dark_mode_rounded,
                          isSelected: themeMode == ThemeMode.dark,
                          onTap: () => ref
                              .read(themeProvider.notifier)
                              .setTheme(ThemeMode.dark),
                        ),
                        const SizedBox(width: 8),
                        _ThemeChip(
                          label: 'Claro',
                          icon: Icons.light_mode_rounded,
                          isSelected: themeMode == ThemeMode.light,
                          onTap: () => ref
                              .read(themeProvider.notifier)
                              .setTheme(ThemeMode.light),
                        ),
                        const SizedBox(width: 8),
                        _ThemeChip(
                          label: 'Sistema',
                          icon: Icons.auto_awesome_rounded,
                          isSelected: themeMode == ThemeMode.system,
                          onTap: () => ref
                              .read(themeProvider.notifier)
                              .setTheme(ThemeMode.system),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Session section
          _SectionHeader(title: 'Sesión'),
          _SettingsCard(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: Icon(
                  Icons.power_settings_new_rounded,
                  color: colorScheme.error,
                  size: 20,
                ),
                title: Text(
                  'Desconectar',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colorScheme.error,
                  ),
                ),
                subtitle: terminalState.sessionState.status.isConnected
                    ? Text(
                        'Conexión activa',
                        style: AppTextStyles.bodySmall,
                      )
                    : null,
                onTap: terminalState.sessionState.status.isConnected
                    ? () => _disconnect(context, ref)
                    : null,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Info section
          _SectionHeader(title: 'Información'),
          _SettingsCard(
            children: [
              _InfoRow(
                label: 'Versión',
                value: AppConstants.appVersion,
              ),
              const _Divider(),
              _InfoRow(
                label: 'Backend',
                value: configState.config?.httpUrl ?? '—',
                mono: true,
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
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

  Future<void> _disconnect(BuildContext context, WidgetRef ref) async {
    await ref.read(terminalProvider.notifier).disconnect();
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.labelSmall.copyWith(
          color: colorScheme.primary,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark2 = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark2 ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark2 ? AppColors.darkOutline : AppColors.lightOutline,
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.mono = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: (mono ? AppTextStyles.monoSmall : AppTextStyles.bodyMedium)
                  .copyWith(
                color: valueColor ?? colorScheme.onSurface,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
    );
  }
}

class _TransportOption extends StatelessWidget {
  final TransportType type;
  final bool isSelected;
  final bool isAvailable;

  const _TransportOption({
    required this.type,
    required this.isSelected,
    required this.isAvailable,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    IconData icon;
    switch (type) {
      case TransportType.direct:
        icon = Icons.wifi_rounded;
        break;
      case TransportType.telegram:
        icon = Icons.send_rounded;
        break;
      case TransportType.cloudflare:
        icon = Icons.cloud_queue_rounded;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isAvailable
                ? (isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.5))
                : colorScheme.onSurface.withOpacity(0.2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              type.displayName,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isAvailable
                    ? colorScheme.onSurface
                    : colorScheme.onSurface.withOpacity(0.3),
              ),
            ),
          ),
          if (!isAvailable)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withOpacity(0.06),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Próximamente',
                style: AppTextStyles.labelSmall.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.3),
                  fontSize: 10,
                ),
              ),
            )
          else if (isSelected)
            Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: colorScheme.primary,
            ),
        ],
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary.withOpacity(0.4)
                : colorScheme.outline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurface.withOpacity(0.5),
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
