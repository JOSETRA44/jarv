import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/config_provider.dart';
import '../../providers/terminal_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/notification_settings_provider.dart';
import '../../../infrastructure/notifications/local_notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/device_id_service.dart';
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
                label: 'URL activa',
                value: configState.config?.httpUrl ?? 'No configurado',
                mono: true,
              ),
              if (configState.config?.transportType == TransportType.cloudflare) ...[
                const _Divider(),
                _InfoRow(
                  label: 'Cloudflare URL',
                  value: configState.config!.cloudflareUrl,
                  mono: true,
                ),
              ],
              const _Divider(),
              _InfoRow(
                label: 'Estado',
                value: terminalState.connectionStatus.displayLabel,
                valueColor: _statusColor(terminalState.connectionStatus),
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
            label: const Text('Editar conexión LAN'),
          ),

          const SizedBox(height: 24),

          // Transport section
          _SectionHeader(title: 'Transporte'),
          _SettingsCard(
            children: TransportType.values.map((t) {
              final isSelected = configState.config?.transportType == t;
              final isAvailable = t.isAvailable;
              final subtitle = t == TransportType.cloudflare
                  ? (configState.config?.cloudflareUrl ??
                      AppConstants.cloudflareBaseUrl)
                  : t == TransportType.direct
                      ? (configState.config?.baseUrl ?? 'LAN local')
                      : null;
              return _TransportOption(
                type: t,
                isSelected: isSelected,
                isAvailable: isAvailable,
                subtitle: subtitle,
                onTap: isAvailable && !isSelected && configState.config != null
                    ? () async {
                        final updated = configState.config!
                            .copyWith(transportType: t);
                        await ref.read(configProvider.notifier).save(updated);
                        if (context.mounted) {
                          await ref
                              .read(terminalProvider.notifier)
                              .disconnect();
                          ref
                              .read(terminalProvider.notifier)
                              .connectWithConfig(updated);
                        }
                      }
                    : null,
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

          // Notifications section
          _SectionHeader(title: 'Notificaciones'),
          _SettingsCard(
            children: [const _NotificationsToggle()],
          ),

          const SizedBox(height: 24),

          // Security section
          _SectionHeader(title: 'Seguridad'),
          _SettingsCard(
            children: [const _DeviceIdRow()],
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
                subtitle: terminalState.connectionStatus.isConnected
                    ? Text(
                        'Conexión activa',
                        style: AppTextStyles.bodySmall,
                      )
                    : null,
                onTap: terminalState.connectionStatus.isConnected
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
  final String? subtitle;
  final VoidCallback? onTap;

  const _TransportOption({
    required this.type,
    required this.isSelected,
    required this.isAvailable,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final icon = switch (type) {
      TransportType.direct     => Icons.wifi_rounded,
      TransportType.telegram   => Icons.send_rounded,
      TransportType.cloudflare => Icons.cloud_done_rounded,
    };

    final nameColor = isAvailable
        ? colorScheme.onSurface
        : colorScheme.onSurface.withOpacity(0.3);
    final iconColor = isAvailable
        ? (isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.5))
        : colorScheme.onSurface.withOpacity(0.2);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.displayName,
                    style: AppTextStyles.bodyMedium.copyWith(color: nameColor),
                  ),
                  if (subtitle != null && isAvailable)
                    Text(
                      subtitle!,
                      style: AppTextStyles.monoTiny.copyWith(
                        color: isSelected
                            ? colorScheme.primary.withOpacity(0.7)
                            : colorScheme.onSurface.withOpacity(0.35),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                ],
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
              Icon(Icons.check_circle_rounded, size: 18, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

class _NotificationsToggle extends ConsumerWidget {
  const _NotificationsToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(notificationsEnabledProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      secondary: Icon(
        Icons.notifications_active_rounded,
        color: colorScheme.primary,
        size: 20,
      ),
      title: Text(
        'Alertas del sistema',
        style: AppTextStyles.bodyMedium.copyWith(color: colorScheme.onSurface),
      ),
      subtitle: Text(
        'Avisa de desconexión, comandos largos y eventos cuando la app está en segundo plano',
        style: AppTextStyles.bodySmall,
      ),
      value: enabled,
      onChanged: (value) async {
        if (value) {
          final granted =
              await LocalNotificationService.instance.requestPermission();
          if (!granted) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Permiso de notificaciones denegado',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              );
            }
            return; // keep toggle off
          }
        }
        await ref.read(notificationsEnabledProvider.notifier).setEnabled(value);
      },
    );
  }
}

class _DeviceIdRow extends StatefulWidget {
  const _DeviceIdRow();

  @override
  State<_DeviceIdRow> createState() => _DeviceIdRowState();
}

class _DeviceIdRowState extends State<_DeviceIdRow> {
  String _id = '...';

  @override
  void initState() {
    super.initState();
    DeviceIdService.get().then((id) {
      if (mounted) setState(() => _id = id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            'Device ID',
            style: AppTextStyles.bodyMedium.copyWith(
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _id,
              style: AppTextStyles.monoSmall.copyWith(
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _id));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Device ID copiado'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Icon(
              Icons.copy_rounded,
              size: 16,
              color: colorScheme.onSurface.withOpacity(0.4),
            ),
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
