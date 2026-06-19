import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/terminal_provider.dart';
import '../../providers/config_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/entities/session_state.dart';
import 'widgets/connection_status_bar.dart';
import 'widgets/message_bubble.dart';
import 'widgets/command_input.dart';
import 'widgets/quick_commands_bar.dart';

class TerminalPage extends ConsumerStatefulWidget {
  const TerminalPage({super.key});

  @override
  ConsumerState<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends ConsumerState<TerminalPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Auto-connect if we have a config and not already connected
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoConnect());
  }

  void _autoConnect() {
    final config = ref.read(configProvider).config;
    final terminalState = ref.read(terminalProvider);

    if (config != null &&
        !terminalState.sessionState.status.isConnected &&
        !terminalState.sessionState.status.isConnecting) {
      ref.read(terminalProvider.notifier).connectWithConfig(config);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final terminalState = ref.watch(terminalProvider);
    final configState = ref.watch(configProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Auto-scroll when new messages arrive
    ref.listen(terminalProvider.select((s) => s.messages.length), (prev, next) {
      if (next > (prev ?? 0)) _scrollToBottom();
    });

    // Auto-connect if config changes
    ref.listen(configProvider.select((s) => s.config), (prev, next) {
      if (next != null && !terminalState.sessionState.status.isConnected) {
        ref.read(terminalProvider.notifier).connectWithConfig(next);
      }
    });

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Status bar
            const ConnectionStatusBar(),

            // Messages list
            Expanded(
              child: terminalState.messages.isEmpty
                  ? _EmptyTerminalState(
                      status: terminalState.sessionState.status,
                      onSetup: () => context.go('/setup'),
                      hasConfig: configState.hasConfig,
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: terminalState.messages.length,
                      itemBuilder: (context, index) {
                        final message = terminalState.messages[index];
                        return MessageBubble(message: message);
                      },
                    ),
            ),

            // Quick commands bar
            if (terminalState.sessionState.status.isConnected)
              QuickCommandsBar(
                isEnabled: !terminalState.isSending,
                onCommandSelected: (cmd) {
                  ref.read(terminalProvider.notifier).sendCommand(cmd);
                },
              ),

            // Command input
            const CommandInput(),
          ],
        ),
      ),
    );
  }
}

class _EmptyTerminalState extends StatelessWidget {
  final SessionStatus status;
  final VoidCallback onSetup;
  final bool hasConfig;

  const _EmptyTerminalState({
    required this.status,
    required this.onSetup,
    required this.hasConfig,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    String title;
    String subtitle;
    IconData icon;
    Color iconColor;

    switch (status) {
      case SessionStatus.connecting:
        title = 'Conectando...';
        subtitle = 'Estableciendo conexión con JARVIS';
        icon = Icons.wifi_tethering_rounded;
        iconColor = AppColors.statusConnecting;
        break;
      case SessionStatus.connected:
        title = 'Listo';
        subtitle = 'Escribe un comando para empezar';
        icon = Icons.terminal_rounded;
        iconColor = colorScheme.primary;
        break;
      case SessionStatus.error:
        title = 'Error de conexión';
        subtitle = hasConfig
            ? 'Reintentando automáticamente...'
            : 'Configura la conexión en Ajustes';
        icon = Icons.error_outline_rounded;
        iconColor = AppColors.statusError;
        break;
      case SessionStatus.disconnected:
        title = hasConfig ? 'Desconectado' : 'Sin configuración';
        subtitle = hasConfig
            ? 'Reconectando automáticamente...'
            : 'Ve a Ajustes para configurar la conexión';
        icon = Icons.cloud_off_rounded;
        iconColor = AppColors.statusDisconnected;
        break;
    }

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
                color: colorScheme.onSurface.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: AppTextStyles.bodyMedium.copyWith(
                color: colorScheme.onSurface.withOpacity(0.4),
              ),
              textAlign: TextAlign.center,
            ),
            if (status == SessionStatus.connecting ||
                status == SessionStatus.disconnected) ...[
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
