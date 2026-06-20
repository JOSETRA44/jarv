import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/entities/gui_action.dart';
import '../../../domain/entities/session_state.dart';
import '../../providers/config_provider.dart';
import '../../providers/poltergeist_provider.dart';
import 'sniper_view_page.dart';
import 'widgets/action_button.dart';
import 'widgets/category_filter_bar.dart';
import 'widgets/poltergeist_empty_state.dart';
import 'widgets/tts_input_bar.dart';

class PoltergeistPage extends ConsumerStatefulWidget {
  const PoltergeistPage({super.key});

  @override
  ConsumerState<PoltergeistPage> createState() => _PoltergeistPageState();
}

class _PoltergeistPageState extends ConsumerState<PoltergeistPage>
    with AutomaticKeepAliveClientMixin {
  ActionCategory? _selectedCategory;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoConnect());
  }

  Future<void> _autoConnect() async {
    final config = ref.read(configProvider).config;
    if (config == null) return;
    await ref.read(poltergeistProvider.notifier).connectWithConfig(config);
  }

  void _onActionTap(GuiAction action) {
    // Screenshot opens the interactive sniper view (it triggers the capture).
    if (action.id == 'sys_screenshot') {
      _openSniper();
      return;
    }
    if (action.requiresText) {
      // TTS / type_text reveal the input bar via the category filter.
      setState(() => _selectedCategory = action.category);
      return;
    }
    ref.read(poltergeistProvider.notifier).executeAction(action.id);
  }

  void _openSniper() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SniperViewPage()),
    );
  }

  void _onSpeak(String text, {String? preset, String? voice, double? rate}) {
    ref.read(poltergeistProvider.notifier).executeAction(
      'tts_speak',
      params: {
        'text': text,
        if (preset != null) 'preset': preset,
        if (voice != null) 'voice': voice,
        if (rate != null) 'rate': rate,
      },
    );
  }

  void _onTypeText(String text) {
    ref
        .read(poltergeistProvider.notifier)
        .executeAction('type_text', params: {'text': text});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(poltergeistProvider);

    // Error snackbar
    ref.listen(poltergeistProvider.select((s) => s.errorMessage), (prev, next) {
      if (next != null && next != prev) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next, style: AppTextStyles.bodySmall),
            backgroundColor: AppColors.statusError,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });

    // Only visible (non-hidden) actions appear in the grid.
    final visible = state.catalog.where((a) => !a.hidden).toList();
    final filteredCatalog = _selectedCategory == null
        ? visible
        : visible.where((a) => a.category == _selectedCategory).toList();

    final showTtsBar = _selectedCategory == ActionCategory.tts;
    final showTypeBar = _selectedCategory == ActionCategory.keyboard;

    return Scaffold(
      appBar: _buildAppBar(context, state),
      body: Column(
        children: [
          const SizedBox(height: 8),
          CategoryFilterBar(
            selected: _selectedCategory,
            onChanged: (cat) => setState(() => _selectedCategory = cat),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _buildBody(context, state, filteredCatalog),
          ),
          if (showTtsBar)
            TtsInputBar(
              isExecuting: state.isExecuting,
              voices: state.voices,
              presets: state.presets,
              onSpeak: _onSpeak,
            ),
          if (showTypeBar && !showTtsBar)
            TtsInputBar(
              isExecuting: state.isExecuting,
              voices: const [],
              presets: const [],
              showVoiceControls: false,
              buttonLabel: 'Escribir',
              hint: 'Texto para escribir en el PC...',
              onSpeak: (text, {preset, voice, rate}) => _onTypeText(text),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, PoltergeistState state) {
    final Color statusColor;
    switch (state.connectionStatus) {
      case SessionStatus.connected:
        statusColor = AppColors.statusConnected;
      case SessionStatus.connecting:
        statusColor = AppColors.statusConnecting;
      case SessionStatus.error:
        statusColor = AppColors.statusError;
      case SessionStatus.disconnected:
        statusColor = AppColors.statusDisconnected;
    }

    return AppBar(
      title: Row(
        children: [
          Text('Control', style: AppTextStyles.titleMedium),
          const SizedBox(width: 8),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
          ),
        ],
      ),
      actions: [
        if (state.connectionStatus == SessionStatus.disconnected ||
            state.connectionStatus == SessionStatus.error)
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reconectar',
            onPressed: _autoConnect,
          ),
        if (state.connectionStatus == SessionStatus.connected)
          IconButton(
            icon: const Icon(Icons.link_off_rounded),
            tooltip: 'Desconectar',
            onPressed: () => ref.read(poltergeistProvider.notifier).disconnect(),
          ),
      ],
    );
  }

  Widget _buildBody(
      BuildContext context, PoltergeistState state, List<GuiAction> catalog) {
    if (state.connectionStatus == SessionStatus.disconnected ||
        state.connectionStatus == SessionStatus.error) {
      return const PoltergeistEmptyState(isConnecting: false);
    }

    if (state.connectionStatus == SessionStatus.connecting || catalog.isEmpty) {
      return const PoltergeistEmptyState(isConnecting: true);
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemCount: catalog.length,
      itemBuilder: (context, i) {
        final action = catalog[i];
        final isLast = action.id == state.lastActionId;
        return ActionButton(
          action: action,
          isExecuting: state.isExecuting,
          isLastAction: isLast,
          lastSuccess: isLast ? state.lastSuccess : null,
          onTap: () => _onActionTap(action),
        );
      },
    );
  }
}
