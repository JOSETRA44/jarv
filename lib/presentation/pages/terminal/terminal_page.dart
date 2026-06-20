import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/terminal_provider.dart';
import '../../providers/config_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/entities/session_state.dart';
import 'widgets/connection_status_bar.dart';
import 'widgets/session_tab_bar.dart';
import 'widgets/terminal_session_view.dart';
import 'widgets/helper_bar.dart';

class TerminalPage extends ConsumerStatefulWidget {
  const TerminalPage({super.key});

  @override
  ConsumerState<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends ConsumerState<TerminalPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoConnect());
  }

  void _autoConnect() {
    final config = ref.read(configProvider).config;
    final ts = ref.read(terminalProvider);
    if (config != null &&
        !ts.connectionStatus.isConnected &&
        !ts.connectionStatus.isConnecting) {
      ref.read(terminalProvider.notifier).connectWithConfig(config);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = ref.watch(terminalProvider);
    final configState = ref.watch(configProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Auto-connect when config arrives
    ref.listen(configProvider.select((s) => s.config), (prev, next) {
      if (next != null && !ts.connectionStatus.isConnected) {
        ref.read(terminalProvider.notifier).connectWithConfig(next);
      }
    });

    final isConnected = ts.connectionStatus == SessionStatus.connected;
    final hasSession = ts.activeSessionId.isNotEmpty;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const ConnectionStatusBar(),
            // Session tabs — always visible when connected
            if (isConnected) const SessionTabBar(),
            // Main content area
            Expanded(
              child: (!isConnected || !hasSession)
                  ? _EmptyState(
                      status: ts.connectionStatus,
                      hasConfig: configState.hasConfig,
                      onSetup: () => context.go('/setup'),
                    )
                  : TerminalSessionView(sessionId: ts.activeSessionId),
            ),
            // Helper bar with special keys (hidden when not connected)
            const HelperBar(),
          ],
        ),
      ),
    );
  }
}

// ── Empty / connection state placeholder ──────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final SessionStatus status;
  final bool hasConfig;
  final VoidCallback onSetup;

  const _EmptyState({
    required this.status,
    required this.hasConfig,
    required this.onSetup,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final (icon, iconColor, title, subtitle) = switch (status) {
      SessionStatus.connecting => (
          Icons.wifi_tethering_rounded,
          AppColors.statusConnecting,
          'Conectando...',
          'Estableciendo conexión con JARVIS',
        ),
      SessionStatus.connected => (
          Icons.terminal_rounded,
          cs.primary,
          'Listo',
          'Iniciando sesión terminal...',
        ),
      SessionStatus.error => (
          Icons.error_outline_rounded,
          AppColors.statusError,
          'Error de conexión',
          hasConfig ? 'Reintentando automáticamente...' : 'Configura la conexión en Ajustes',
        ),
      SessionStatus.disconnected => (
          Icons.cloud_off_rounded,
          AppColors.statusDisconnected,
          hasConfig ? 'Desconectado' : 'Sin configuración',
          hasConfig ? 'Reconectando automáticamente...' : 'Ve a Ajustes para configurar la conexión',
        ),
    };

    final showSpinner = status == SessionStatus.connecting ||
        (status == SessionStatus.disconnected && hasConfig);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: iconColor),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTextStyles.titleLarge.copyWith(
                color: cs.onSurface.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: AppTextStyles.bodyMedium.copyWith(
                color: cs.onSurface.withOpacity(0.4),
              ),
              textAlign: TextAlign.center,
            ),
            if (!hasConfig) ...[
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: onSetup,
                child: const Text('Configurar conexión'),
              ),
            ],
            if (showSpinner) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: iconColor.withOpacity(0.6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
